import AVFoundation
import Cocoa
import CoreImage
import CoreVideo
import FlutterMacOS
import Vision
#if canImport(RealtimeNativeFrameSinks)
import RealtimeNativeFrameSinks
#endif

@objc(FlutterRealtimeProcessedVideoFrame) @objcMembers public final class FlutterRealtimeProcessedVideoFrame: NSObject {
  public let sourceId: String
  public let pixelBuffer: CVPixelBuffer
  public let timestamp: CMTime
  public var width: Int { CVPixelBufferGetWidth(pixelBuffer) }
  public var height: Int { CVPixelBufferGetHeight(pixelBuffer) }
  public var rowStride: Int { CVPixelBufferGetBytesPerRow(pixelBuffer) }
  public let rotationDegrees: Int = 0
  public let mirrored: Bool = false
  public let pixelFormat: String = "bgra8888"
  public var timestampNs: Int64 { Int64(CMTimeGetSeconds(timestamp) * 1_000_000_000) }
  public init(sourceId: String, pixelBuffer: CVPixelBuffer, timestamp: CMTime) {
    self.sourceId = sourceId; self.pixelBuffer = pixelBuffer; self.timestamp = timestamp
    super.init()
  }
}

@objc(FlutterRealtimeProcessedVideoFrameSink) public protocol FlutterRealtimeProcessedVideoFrameSink: AnyObject {
  func onProcessedVideoFrame(_ frame: FlutterRealtimeProcessedVideoFrame)
}

private final class WeakFrameSink {
  weak var value: FlutterRealtimeProcessedVideoFrameSink?

  init(_ value: FlutterRealtimeProcessedVideoFrameSink) {
    self.value = value
  }
}

/// Native-only frame fan-out used by provider sinks.
///
/// CVPixelBuffer frames never cross MethodChannel. A provider plugin subscribes
/// with the same sourceId that Dart received from the effects bridge.
@objc(FlutterRealtimeProcessedVideoFrameHub) public final class FlutterRealtimeProcessedVideoFrameHub: NSObject {
  private static let lock = NSLock()
  private static var sinks: [String: [ObjectIdentifier: WeakFrameSink]] = [:]
  private static var activeSources: Set<String> = []

  @objc(containsSourceId:) public static func contains(sourceId: String) -> Bool {
    lock.lock(); defer { lock.unlock() }
    return activeSources.contains(sourceId)
  }

  static func activate(_ sourceId: String) {
    lock.lock(); defer { lock.unlock() }; activeSources.insert(sourceId)
  }

  @objc(registerWithSourceId:sink:) public static func register(
    sourceId: String,
    sink: FlutterRealtimeProcessedVideoFrameSink
  ) {
    lock.lock()
    defer { lock.unlock() }
    guard activeSources.contains(sourceId) else { return }
    var current = sinks[sourceId] ?? [:]
    current[ObjectIdentifier(sink)] = WeakFrameSink(sink)
    sinks[sourceId] = current
  }

  @objc(unregisterWithSourceId:sink:) public static func unregister(
    sourceId: String,
    sink: FlutterRealtimeProcessedVideoFrameSink
  ) {
    lock.lock()
    defer { lock.unlock() }
    guard var current = sinks[sourceId] else { return }
    current.removeValue(forKey: ObjectIdentifier(sink))
    if current.isEmpty {
      sinks.removeValue(forKey: sourceId)
    } else {
      sinks[sourceId] = current
    }
  }

  static func clear(_ sourceId: String) {
    lock.lock(); defer { lock.unlock() }
    sinks.removeValue(forKey: sourceId)
    activeSources.remove(sourceId)
  }

  static func publish(_ frame: FlutterRealtimeProcessedVideoFrame) {
    lock.lock()
    let current = sinks[frame.sourceId] ?? [:]
    lock.unlock()
    var stale: [ObjectIdentifier] = []
    for (identifier, weakSink) in current {
      guard let sink = weakSink.value else {
        stale.append(identifier)
        continue
      }
      sink.onProcessedVideoFrame(frame)
    }
    if !stale.isEmpty {
      lock.lock()
      if var stored = sinks[frame.sourceId] {
        stale.forEach { stored.removeValue(forKey: $0) }
        sinks[frame.sourceId] = stored
      }
      lock.unlock()
    }
  }
}

private final class MacOSVideoEffectsSource: NSObject,
  AVCaptureVideoDataOutputSampleBufferDelegate,
  FlutterTexture
{
  let sourceId: String
  let requestedWidth: Int
  let requestedHeight: Int
  let frameRate: Int
  let textureRegistry: FlutterTextureRegistry
  var textureId: Int64 = 0

  private let session = AVCaptureSession()
  private let captureQueue = DispatchQueue(
    label: "flutter_realtime_video_effects.capture"
  )
  private let frameLock = NSLock()
  private let ciContext = CIContext(options: [.cacheIntermediates: false])
  private let sequenceHandler = VNSequenceRequestHandler()
  private let segmentationRequest: VNGeneratePersonSegmentationRequest = {
    let request = VNGeneratePersonSegmentationRequest()
    request.qualityLevel = .balanced
    request.outputPixelFormat = kCVPixelFormatType_OneComponent8
    return request
  }()

  private var currentPixelBuffer: CVPixelBuffer?
  private var currentInput: AVCaptureDeviceInput?
  private var videoOutput: AVCaptureVideoDataOutput?
  private var cameraDeviceId: String?
  private var effectType: String
  private var blurStrength: String
  private var replacementImage: CIImage?
  private var enabled = true
  private var processingFailed = false
  private var disposed = false
  var onFailure: ((Error) -> Void)?

  init(
    sourceId: String,
    width: Int,
    height: Int,
    frameRate: Int,
    cameraDeviceId: String?,
    effectType: String,
    blurStrength: String,
    backgroundImageData: Data?,
    textureRegistry: FlutterTextureRegistry
  ) throws {
    self.sourceId = sourceId
    requestedWidth = width
    requestedHeight = height
    self.frameRate = frameRate
    self.cameraDeviceId = cameraDeviceId
    self.effectType = "none"
    self.blurStrength = "medium"
    replacementImage = nil
    self.textureRegistry = textureRegistry
    super.init()
    try setEffect(
      type: effectType,
      strength: blurStrength,
      imageData: backgroundImageData
    )
  }

  func start(completion: @escaping (Error?) -> Void) {
    let beginCapture = { [weak self] in
      guard let self else { return }
      captureQueue.async {
        do {
          guard !self.disposed else { throw VideoEffectsError.sourceDisposed }
          try self.configureCapture()
          self.session.startRunning()
          DispatchQueue.main.async { completion(nil) }
        } catch {
          DispatchQueue.main.async { completion(error) }
        }
      }
    }
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      beginCapture()
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { granted in
        if granted {
          beginCapture()
        } else {
          DispatchQueue.main.async { completion(VideoEffectsError.cameraPermissionDenied) }
        }
      }
    default:
      completion(VideoEffectsError.cameraPermissionDenied)
    }
  }

  func setEffect(
    type: String,
    strength: String,
    imageData: Data? = nil
  ) throws {
    guard type == "none" || type == "blur" || type == "replaceImage" else {
      throw VideoEffectsError.unsupportedEffect(type)
    }
    let wasEnabled = captureQueue.sync { () -> Bool in
      let previous = enabled
      if type != "none" { enabled = false }
      return previous
    }
    let nextImage: CIImage?
    if type == "replaceImage" {
      guard
        let imageData,
        let image = Self.decodeBackgroundImage(imageData)
      else {
        captureQueue.sync { processingFailed = true }
        clearPreviewFrame()
        throw VideoEffectsError.invalidBackgroundImage
      }
      nextImage = image
    } else {
      nextImage = nil
    }
    captureQueue.sync {
      replacementImage = nextImage
      effectType = type
      blurStrength = strength
      processingFailed = false
      enabled = wasEnabled
    }
  }

  func setEnabled(_ enabled: Bool) throws {
    try captureQueue.sync {
      if enabled && processingFailed { throw VideoEffectsError.processingFailed }
      self.enabled = enabled
      if enabled, videoOutput != nil, !session.isRunning { session.startRunning() }
      if !enabled, session.isRunning { session.stopRunning() }
    }
    if !enabled { clearPreviewFrame() }
  }

  func selectCamera(_ deviceId: String?) throws {
    try captureQueue.sync {
      let previousId = cameraDeviceId
      cameraDeviceId = deviceId
      do { try replaceCameraInput() } catch {
        cameraDeviceId = previousId
        throw error
      }
    }
  }

  private func configureCapture() throws {
    session.beginConfiguration()
    defer { session.commitConfiguration() }
    session.sessionPreset = requestedWidth >= 1280 ? .hd1280x720 : .vga640x480
    try addCameraInput()
    let output = AVCaptureVideoDataOutput()
    output.alwaysDiscardsLateVideoFrames = true
    output.videoSettings = [
      kCVPixelBufferPixelFormatTypeKey as String:
        kCVPixelFormatType_32BGRA
    ]
    output.setSampleBufferDelegate(self, queue: captureQueue)
    guard session.canAddOutput(output) else {
      throw VideoEffectsError.captureConfigurationFailed
    }
    session.addOutput(output)
    videoOutput = output
  }

  private func replaceCameraInput() throws {
    session.beginConfiguration()
    defer { session.commitConfiguration() }
    let previous = currentInput
    if let previous { session.removeInput(previous) }
    currentInput = nil
    do { try addCameraInput() } catch {
      if let previous, session.canAddInput(previous) { session.addInput(previous); currentInput = previous }
      throw error
    }
  }

  private func addCameraInput() throws {
    let device = selectedCamera()
    guard let device else { throw VideoEffectsError.cameraUnavailable }
    do {
      try device.lockForConfiguration()
      let duration = CMTime(
        value: 1,
        timescale: CMTimeScale(max(1, frameRate))
      )
      if device.activeFormat.videoSupportedFrameRateRanges.contains(
        where: {
          Double(frameRate) >= $0.minFrameRate &&
            Double(frameRate) <= $0.maxFrameRate
        }
      ) {
        device.activeVideoMinFrameDuration = duration
        device.activeVideoMaxFrameDuration = duration
      }
      device.unlockForConfiguration()
    } catch {
      // Frame-rate tuning is best effort.
    }
    let input = try AVCaptureDeviceInput(device: device)
    guard session.canAddInput(input) else {
      throw VideoEffectsError.captureConfigurationFailed
    }
    session.addInput(input)
    currentInput = input
  }

  private func selectedCamera() -> AVCaptureDevice? {
    let devices = FlutterRealtimeVideoEffectsPlugin.availableCameras()
    if let cameraDeviceId { return devices.first(where: { $0.uniqueID == cameraDeviceId }) }
    return devices.first
  }

  func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard enabled,
          !disposed,
          let inputBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
    else { return }

    let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
    let original = CIImage(cvPixelBuffer: inputBuffer)
    let processed: CIImage

    if effectType == "blur" || effectType == "replaceImage" {
      let background: CIImage
      if effectType == "replaceImage",
         let image = replacementImage
      {
        background = fitBackground(image, to: original.extent)
      } else {
        background = original
        .clampedToExtent()
        .applyingFilter(
          "CIGaussianBlur",
          parameters: [kCIInputRadiusKey: blurRadius()]
        )
        .cropped(to: original.extent)
      }
      do {
        try sequenceHandler.perform([segmentationRequest], on: inputBuffer)
        if let observation =
          segmentationRequest.results?.first as? VNPixelBufferObservation
        {
          let rawMask = CIImage(cvPixelBuffer: observation.pixelBuffer)
          let scaleX = original.extent.width / rawMask.extent.width
          let scaleY = original.extent.height / rawMask.extent.height
          let scaledMask = rawMask.transformed(
            by: CGAffineTransform(scaleX: scaleX, y: scaleY)
          )
          let mask = refineForegroundMask(scaledMask, to: original.extent)
          processed = original.applyingFilter(
            "CIBlendWithMask",
            parameters: [
              kCIInputBackgroundImageKey: background,
              kCIInputMaskImageKey: mask,
            ]
          )
        } else {
          processed = background
        }
      } catch {
        enabled = false
        processingFailed = true
        clearPreviewFrame()
        captureQueue.async { [weak self] in self?.session.stopRunning() }
        onFailure?(error)
        return
      }
    } else {
      processed = original
    }

    guard let outputBuffer = makeOutputPixelBuffer(
      width: CVPixelBufferGetWidth(inputBuffer),
      height: CVPixelBufferGetHeight(inputBuffer)
    ) else {
      enabled = false; processingFailed = true; clearPreviewFrame()
      captureQueue.async { [weak self] in self?.session.stopRunning() }
      onFailure?(VideoEffectsError.outputAllocationFailed)
      return
    }
    ciContext.render(processed, to: outputBuffer)

    frameLock.lock()
    currentPixelBuffer = outputBuffer
    frameLock.unlock()

    if textureId != 0 {
      let id = textureId
      DispatchQueue.main.async { [textureRegistry] in textureRegistry.textureFrameAvailable(id) }
    }
    FlutterRealtimeProcessedVideoFrameHub.publish(
      FlutterRealtimeProcessedVideoFrame(
        sourceId: sourceId,
        pixelBuffer: outputBuffer,
        timestamp: timestamp
      )
    )
  }

  private func blurRadius() -> Double {
    switch blurStrength {
    case "low": return 8
    case "high": return 24
    default: return 16
    }
  }

  private func refineForegroundMask(_ mask: CIImage, to extent: CGRect) -> CIImage {
    // Give uncertain hair/shoulder pixels more foreground weight. A small
    // expansion protects the subject from the background blur; the final
    // subpixel feather prevents a visible hard silhouette.
    let low = 0.06
    let scale = 1.0 / (0.74 - low)
    return mask
      .applyingFilter("CIMorphologyMaximum", parameters: ["inputRadius": 2.0])
      .applyingFilter("CIColorMatrix", parameters: [
        "inputRVector": CIVector(x: scale, y: 0, z: 0, w: 0),
        "inputGVector": CIVector(x: scale, y: 0, z: 0, w: 0),
        "inputBVector": CIVector(x: scale, y: 0, z: 0, w: 0),
        "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
        "inputBiasVector": CIVector(x: -low * scale, y: -low * scale, z: -low * scale, w: 0)
      ])
      .applyingFilter("CIColorClamp", parameters: [
        "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0),
        "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
      ])
      .clampedToExtent()
      .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.8])
      .cropped(to: extent)
  }

  private func fitBackground(
    _ image: CIImage,
    to target: CGRect
  ) -> CIImage {
    let source = image.extent
    guard source.width > 0, source.height > 0 else {
      return CIImage(color: .black).cropped(to: target)
    }
    let scale = max(
      target.width / source.width,
      target.height / source.height
    )
    let scaled = image.transformed(
      by: CGAffineTransform(scaleX: scale, y: scale)
    )
    let translated = scaled.transformed(
      by: CGAffineTransform(
        translationX: target.midX - scaled.extent.midX,
        y: target.midY - scaled.extent.midY
      )
    )
    return translated.cropped(to: target)
  }

  private static func decodeBackgroundImage(_ data: Data) -> CIImage? {
    guard data.count <= 16 * 1024 * 1024, let image = NSImage(data: data) else { return nil }
    var rect = NSRect(origin: .zero, size: image.size)
    guard let cgImage = image.cgImage(
      forProposedRect: &rect,
      context: nil,
      hints: nil
    ), cgImage.width > 0, cgImage.height > 0,
       cgImage.width <= 4096, cgImage.height <= 4096 else { return nil }
    return CIImage(cgImage: cgImage)
  }

  private func makeOutputPixelBuffer(
    width: Int,
    height: Int
  ) -> CVPixelBuffer? {
    var buffer: CVPixelBuffer?
    let attributes: [CFString: Any] = [
      kCVPixelBufferCGImageCompatibilityKey: true,
      kCVPixelBufferCGBitmapContextCompatibilityKey: true,
      kCVPixelBufferMetalCompatibilityKey: true,
      kCVPixelBufferIOSurfacePropertiesKey: [:],
    ]
    let status = CVPixelBufferCreate(
      kCFAllocatorDefault,
      width,
      height,
      kCVPixelFormatType_32BGRA,
      attributes as CFDictionary,
      &buffer
    )
    return status == kCVReturnSuccess ? buffer : nil
  }

  func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    frameLock.lock()
    defer { frameLock.unlock() }
    guard let currentPixelBuffer else { return nil }
    return Unmanaged.passRetained(currentPixelBuffer)
  }

  private func clearPreviewFrame() {
    frameLock.lock(); currentPixelBuffer = nil; frameLock.unlock()
    if textureId != 0 {
      let id = textureId
      DispatchQueue.main.async { [textureRegistry] in textureRegistry.textureFrameAvailable(id) }
    }
  }

  func dispose() {
    guard !disposed else { return }
    captureQueue.sync {
      disposed = true
      replacementImage = nil
      FlutterRealtimeProcessedVideoFrameHub.clear(sourceId)
      videoOutput?.setSampleBufferDelegate(nil, queue: nil)
      if session.isRunning { session.stopRunning() }
      session.inputs.forEach(session.removeInput)
      session.outputs.forEach(session.removeOutput)
    }
    frameLock.lock()
    currentPixelBuffer = nil
    frameLock.unlock()
    if textureId != 0 {
      let id = textureId
      textureId = 0
      DispatchQueue.main.async { [textureRegistry] in
        textureRegistry.unregisterTexture(id)
      }
    }
  }
}

private enum VideoEffectsError: LocalizedError {
  case cameraPermissionDenied
  case cameraUnavailable
  case captureConfigurationFailed
  case invalidBackgroundImage
  case processingFailed
  case sourceDisposed
  case outputAllocationFailed
  case unsupportedEffect(String)

  var errorDescription: String? {
    switch self {
    case .cameraPermissionDenied:
      return "Camera permission was denied."
    case .cameraUnavailable:
      return "No camera is available."
    case .captureConfigurationFailed:
      return "Unable to configure the camera capture session."
    case .invalidBackgroundImage:
      return "The selected background image could not be decoded."
    case .processingFailed:
      return "Background processing failed. Configure the effect again before enabling the camera."
    case .sourceDisposed:
      return "The camera source was disposed before capture could start."
    case .outputAllocationFailed:
      return "The processed video frame could not be allocated."
    case .unsupportedEffect(let effect):
      return "Unsupported background effect: \(effect)"
    }
  }
}

public class FlutterRealtimeVideoEffectsPlugin: NSObject, FlutterPlugin {
  private let textureRegistry: FlutterTextureRegistry
  private var methodChannel: FlutterMethodChannel?
  private var sources: [String: MacOSVideoEffectsSource] = [:]
  private var nativeSinks: [String: SdkNativeProviderSink] = [:]
  private var nativeSinkSources: [String: String] = [:]

  private init(textureRegistry: FlutterTextureRegistry) {
    self.textureRegistry = textureRegistry
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "flutter_realtime_video_effects",
      binaryMessenger: registrar.messenger
    )
    let instance = FlutterRealtimeVideoEffectsPlugin(
      textureRegistry: registrar.textures
    )
    instance.methodChannel = channel
    registrar.addMethodCallDelegate(instance, channel: channel)
    let providers = FlutterMethodChannel(name: "flutter_realtime_native_video/sinks", binaryMessenger: registrar.messenger)
    registrar.addMethodCallDelegate(instance, channel: providers)
  }

  public func handle(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    switch call.method {
    case "attachProvider", "detachProvider":
      let args = call.arguments as? [String: Any] ?? [:]
      let bindingId = args["bindingId"] as? String ?? ""
      guard !bindingId.isEmpty else {
        result(FlutterError(code: "invalid_argument", message: "A provider binding ID is required.", details: nil)); return
      }
      nativeSinks.removeValue(forKey: bindingId)?.dispose()
      nativeSinkSources.removeValue(forKey: bindingId)
      if call.method == "detachProvider" { result(nil); return }
      let sourceId = args["sourceId"] as? String ?? ""
      guard let sink = SdkNativeProviderSink.attach(withSourceId: sourceId,
        provider: args["providerId"] as? String ?? "",
        engineHandle: (args["engineHandle"] as? NSNumber)?.int64Value ?? 0,
        trackId: (args["trackId"] as? NSNumber)?.uint32Value ?? 0) else {
        result(FlutterError(code: "attach_provider_failed", message: "Native provider video input is unavailable.", details: nil)); return
      }
      sink.onFailure = { [weak self] message in
        DispatchQueue.main.async {
          try? self?.sources[sourceId]?.setEnabled(false)
          self?.sources[sourceId]?.onFailure?(NSError(domain: "flutter_realtime_video_effects", code: -1,
            userInfo: [NSLocalizedDescriptionKey: message]))
        }
      }
      nativeSinks[bindingId] = sink
      nativeSinkSources[bindingId] = sourceId
      result(nil)
    case "isSupported":
      result(true)
    case "createSource":
      createSource(call, result: result)
    case "setEffect":
      withSource(call, result: result) { source, args in
        let effect = args["effect"] as? [String: Any] ?? [:]
        try source.setEffect(
          type: effect["type"] as? String ?? "none",
          strength: effect["blurStrength"] as? String ?? "medium",
          imageData: Self.effectImageData(effect["imageBytes"])
        )
      }
    case "setEnabled":
      withSource(call, result: result) { source, args in
        try source.setEnabled(args["enabled"] as? Bool ?? false)
      }
    case "selectCamera":
      withSource(call, result: result) { source, args in
        try source.selectCamera(args["deviceId"] as? String)
      }
    case "listCameras":
      result(
        Self.availableCameras().map { device in
          [
            "id": device.uniqueID,
            "label": device.localizedName,
            "isFrontFacing": false,
          ] as [String: Any]
        }
      )
    case "disposeSource":
      let args = call.arguments as? [String: Any] ?? [:]
      let sourceId = args["sourceId"] as? String ?? ""
      for bindingId in nativeSinkSources.keys.filter({ nativeSinkSources[$0] == sourceId }) {
        nativeSinks.removeValue(forKey: bindingId)?.dispose()
        nativeSinkSources.removeValue(forKey: bindingId)
      }
      sources.removeValue(forKey: sourceId)?.dispose()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func createSource(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    let args = call.arguments as? [String: Any] ?? [:]
    let effect = args["effect"] as? [String: Any] ?? [:]
    let sourceId = UUID().uuidString
    let width = args["width"] as? Int ?? 1280
    let height = args["height"] as? Int ?? 720
    let frameRate = args["frameRate"] as? Int ?? 24
    guard (1...4096).contains(width), (1...4096).contains(height), (1...60).contains(frameRate) else {
      result(FlutterError(code: "invalid_argument", message: "Video size or frame rate is invalid.", details: nil))
      return
    }
    let source: MacOSVideoEffectsSource
    do {
      source = try MacOSVideoEffectsSource(
        sourceId: sourceId,
        width: args["width"] as? Int ?? 1280,
        height: args["height"] as? Int ?? 720,
        frameRate: args["frameRate"] as? Int ?? 24,
        cameraDeviceId: args["cameraDeviceId"] as? String,
        effectType: effect["type"] as? String ?? "none",
        blurStrength: effect["blurStrength"] as? String ?? "medium",
        backgroundImageData: Self.effectImageData(effect["imageBytes"]),
        textureRegistry: textureRegistry
      )
    } catch {
      result(
        FlutterError(
          code: "invalid_effect",
          message: error.localizedDescription,
          details: nil
        )
      )
      return
    }
    source.onFailure = { [weak self] error in
      DispatchQueue.main.async {
        self?.methodChannel?.invokeMethod("sourceError", arguments: ["sourceId": sourceId, "message": error.localizedDescription])
      }
    }
    let textureId = textureRegistry.register(source)
    source.textureId = textureId
    sources[sourceId] = source
    FlutterRealtimeProcessedVideoFrameHub.activate(sourceId)
    source.start { [weak self] error in
      if let error {
        self?.sources.removeValue(forKey: sourceId)
        source.dispose()
        result(
          FlutterError(
            code: "create_source_failed",
            message: error.localizedDescription,
            details: nil
          )
        )
        return
      }
      result([
        "id": sourceId,
        "platform": "macos",
        "kind": "nativeFrameHub",
        "width": args["width"] as? Int ?? 1280,
        "height": args["height"] as? Int ?? 720,
        "frameRate": args["frameRate"] as? Int ?? 24,
        "previewTextureId": textureId,
      ])
    }
  }

  private func withSource(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult,
    operation: (
      MacOSVideoEffectsSource,
      [String: Any]
    ) throws -> Void
  ) {
    let args = call.arguments as? [String: Any] ?? [:]
    let sourceId = args["sourceId"] as? String ?? ""
    guard let source = sources[sourceId] else {
      result(
        FlutterError(
          code: "source_not_found",
          message: "Unknown video source: \(sourceId)",
          details: nil
        )
      )
      return
    }
    do {
      try operation(source, args)
      result(nil)
    } catch {
      result(
        FlutterError(
          code: "source_operation_failed",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  deinit {
    nativeSinks.values.forEach { $0.dispose() }
    sources.values.forEach { $0.dispose() }
  }

  static func availableCameras() -> [AVCaptureDevice] {
    let discovery = AVCaptureDevice.DiscoverySession(
      deviceTypes: [
        .builtInWideAngleCamera,
        .externalUnknown,
      ],
      mediaType: .video,
      position: .unspecified
    )
    return discovery.devices
  }

  private static func effectImageData(_ value: Any?) -> Data? {
    if let typed = value as? FlutterStandardTypedData {
      return typed.data
    }
    if let numbers = value as? [NSNumber] {
      return Data(numbers.map { UInt8(clamping: $0.intValue) })
    }
    if let ints = value as? [Int] {
      return Data(ints.map { UInt8(clamping: $0) })
    }
    return nil
  }
}
