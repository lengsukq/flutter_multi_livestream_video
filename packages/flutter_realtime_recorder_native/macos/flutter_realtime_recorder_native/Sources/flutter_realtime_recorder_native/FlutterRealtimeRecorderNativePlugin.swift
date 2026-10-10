import AppKit
import AVFoundation
import CoreGraphics
import FlutterMacOS
import ScreenCaptureKit

/// Optional, per-app system-display capture. No vendor credentials or RTC
/// media SDKs are used here; a host must explicitly enable this plugin.
public final class FlutterRealtimeRecorderNativePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var recorder: AnyObject?
  private var busy = false
  private var eventSink: FlutterEventSink?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "flutter_realtime_recorder_native",
      binaryMessenger: registrar.messenger
    )
    let plugin = FlutterRealtimeRecorderNativePlugin()
    registrar.addMethodCallDelegate(plugin, channel: channel)
    let events = FlutterEventChannel(
      name: "flutter_realtime_recorder_native/events",
      binaryMessenger: registrar.messenger
    )
    events.setStreamHandler(plugin)
  }

  public func onListen(
    withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "start":
      guard !busy, recorder == nil else {
        result(FlutterError(code: "invalidState", message: "A recording is in progress.", details: nil))
        return
      }
      guard CGPreflightScreenCaptureAccess() else {
        _ = CGRequestScreenCaptureAccess()
        result(FlutterError(
          code: "screenPermissionDenied",
          message: "macOS screen capture permission is not granted. Open System Settings > Privacy & Security > Screen & System Audio Recording, enable this app and relaunch it before starting a recording.",
          details: nil
        ))
        return
      }
      guard #available(macOS 13.0, *) else {
        result(FlutterError(code: "unsupportedPlatform", message: "System-audio screen recording requires macOS 13 or newer.", details: nil))
        return
      }
      let args = call.arguments as? [String: Any] ?? [:]
      let roomCode = args["roomCode"] as? String ?? "room"
      let withAudio = args["withAudio"] as? Bool ?? true
      busy = true
      Task {
        do {
          let engine = try await MacDisplayRecordingEngine.begin(
            roomCode: roomCode, withAudio: withAudio,
            onUnexpectedStop: { [weak self] error in
              DispatchQueue.main.async {
                self?.eventSink?([
                  "roomCode": roomCode,
                  "reason": "macOS screen capture stopped: \(error.localizedDescription)"
                ])
                if let recorder = self?.recorder as? MacDisplayRecordingEngine {
                  self?.recorder = nil
                  Task { try? await recorder.finish() }
                }
              }
            }
          )
          await MainActor.run {
            self.recorder = engine
            self.busy = false
            result([
              "localFilePath": engine.fileURL.path,
              "fileName": engine.fileURL.lastPathComponent
            ])
          }
        } catch {
          await MainActor.run {
            self.busy = false
            result(FlutterError(
              code: "startFailed",
              message: "Display recording could not start. Grant Screen Recording permission in macOS Settings. \(error.localizedDescription)",
              details: nil
            ))
          }
        }
      }
    case "stop":
      guard #available(macOS 13.0, *),
            let engine = recorder as? MacDisplayRecordingEngine, !busy else {
        result(FlutterError(code: "invalidState", message: "No active recording to stop.", details: nil))
        return
      }
      busy = true
      Task {
        do {
          let info = try await engine.finish()
          await MainActor.run {
            self.recorder = nil
            self.busy = false
            result(info)
          }
        } catch {
          await MainActor.run {
            self.recorder = nil
            self.busy = false
            result(FlutterError(
              code: "stopFailed",
              message: "Display recording could not be finalized: \(error.localizedDescription)",
              details: nil
            ))
          }
        }
      }
    case "export":
      guard recorder == nil, !busy else {
        result(FlutterError(code: "invalidState", message: "Stop recording before exporting.", details: nil))
        return
      }
      let path = (call.arguments as? [String: Any])?["localFilePath"] as? String ?? ""
      guard let sourceURL = validatedRecording(path) else {
        result(FlutterError(code: "invalidArgument", message: "The recording file is missing or outside this app's recording folder.", details: nil))
        return
      }
      let panel = NSSavePanel()
      panel.nameFieldStringValue = sourceURL.lastPathComponent
      panel.canCreateDirectories = true
      panel.allowedFileTypes = ["mp4"]
      panel.begin { response in
        guard response == .OK, let destination = panel.url else {
          result(FlutterError(code: "cancelled", message: "File export was cancelled.", details: nil))
          return
        }
        do {
          let source = sourceURL.resolvingSymlinksInPath()
          if destination.standardizedFileURL != source.standardizedFileURL {
            let granted = destination.startAccessingSecurityScopedResource()
            defer { if granted { destination.stopAccessingSecurityScopedResource() } }
            let staging = destination.deletingLastPathComponent()
              .appendingPathComponent(".realtime-export-\(UUID().uuidString).tmp")
            defer { try? FileManager.default.removeItem(at: staging) }
            try FileManager.default.copyItem(at: source, to: staging)
            if FileManager.default.fileExists(atPath: destination.path) {
              try FileManager.default.replaceItemAt(destination, withItemAt: staging)
            } else {
              try FileManager.default.moveItem(at: staging, to: destination)
            }
          }
          result(destination.path)
        } catch {
          result(FlutterError(code: "exportFailed", message: error.localizedDescription, details: nil))
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func validatedRecording(_ path: String) -> URL? {
    guard !path.isEmpty,
          let documents = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
          ).first else { return nil }
    let folder = documents.appendingPathComponent("RealtimeRecordings", isDirectory: true)
      .resolvingSymlinksInPath()
    let url = URL(fileURLWithPath: path).resolvingSymlinksInPath()
    let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
    let byteCount = (attributes?[.size] as? NSNumber)?.intValue ?? 0
    guard url.deletingLastPathComponent() == folder,
          url.pathExtension.lowercased() == "mp4",
          FileManager.default.fileExists(atPath: url.path),
          byteCount > 0
    else { return nil }
    return url
  }
}

/// Captures the primary display and its accessible system audio to H264/AAC MP4.
/// macOS does not expose raw remote RTC media via ScreenCaptureKit.
@available(macOS 13.0, *)
private final class MacCaptureStopDelegate: NSObject, SCStreamDelegate {
  var onStop: ((Error) -> Void)?
  func stream(_ stream: SCStream, didStopWithError error: Error) {
    onStop?(error)
  }
}

@available(macOS 13.0, *)
private final class MacDisplayRecordingEngine: NSObject, SCStreamOutput {
  let fileURL: URL
  private let stream: SCStream
  private let stopDelegate: MacCaptureStopDelegate
  private let writer: AVAssetWriter
  private let videoInput: AVAssetWriterInput
  private let audioInput: AVAssetWriterInput?
  private let outputQueue = DispatchQueue(label: "flutter.realtime.recorder.output")
  private let onUnexpectedStop: (Error) -> Void
  private var videoSamples = 0
  private var audioSamples = 0
  private var firstTime: CMTime?
  private let startTime = Date()

  private init(
    stream: SCStream,
    stopDelegate: MacCaptureStopDelegate,
    writer: AVAssetWriter,
    videoInput: AVAssetWriterInput,
    audioInput: AVAssetWriterInput?,
    fileURL: URL,
    onUnexpectedStop: @escaping (Error) -> Void
  ) {
    self.stream = stream
    self.stopDelegate = stopDelegate
    self.writer = writer
    self.videoInput = videoInput
    self.audioInput = audioInput
    self.fileURL = fileURL
    self.onUnexpectedStop = onUnexpectedStop
    super.init()
  }

  static func begin(
    roomCode: String, withAudio: Bool,
    onUnexpectedStop: @escaping (Error) -> Void
  ) async throws -> MacDisplayRecordingEngine {
    let available = try await SCShareableContent.excludingDesktopWindows(
      false, onScreenWindowsOnly: true
    )
    let primaryDisplayID = (NSScreen.main?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    guard let display = available.displays.first(where: { $0.displayID == primaryDisplayID })
        ?? available.displays.first else {
      throw NSError(domain: "NativeRecording", code: 1, userInfo: [
        NSLocalizedDescriptionKey: "No display is available for recording."
      ])
    }
    let configuration = SCStreamConfiguration()
    configuration.width = display.width
    configuration.height = display.height
    configuration.pixelFormat = kCVPixelFormatType_32BGRA
    configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
    configuration.showsCursor = true
    configuration.capturesAudio = withAudio
    configuration.sampleRate = 48000
    configuration.channelCount = 2
    configuration.excludesCurrentProcessAudio = false
    let filter = SCContentFilter(
      display: display, excludingApplications: [], exceptingWindows: []
    )
    let stopDelegate = MacCaptureStopDelegate()
    let stream = SCStream(filter: filter, configuration: configuration, delegate: stopDelegate)

    let folder = FileManager.default.urls(
      for: .documentDirectory, in: .userDomainMask
    ).first!.appendingPathComponent("RealtimeRecordings", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let safeRoom = String(roomCode.map {
      $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-")
        ? $0 : "_"
    }.prefix(60))
    let url = folder.appendingPathComponent("\(safeRoom)-\(UUID().uuidString).mp4")
    let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
    let video = AVAssetWriterInput(
      mediaType: .video,
      outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: display.width,
        AVVideoHeightKey: display.height,
        AVVideoCompressionPropertiesKey: [
          AVVideoAverageBitRateKey: 5_000_000,
          AVVideoExpectedSourceFrameRateKey: 30
        ]
      ]
    )
    video.expectsMediaDataInRealTime = true
    guard writer.canAdd(video) else {
      throw NSError(domain: "NativeRecording", code: 2, userInfo: [
        NSLocalizedDescriptionKey: "The screen video encoder is unavailable."
      ])
    }
    writer.add(video)

    var audio: AVAssetWriterInput?
    if withAudio {
      let input = AVAssetWriterInput(
        mediaType: .audio,
        outputSettings: [
          AVFormatIDKey: kAudioFormatMPEG4AAC,
          AVSampleRateKey: 48000,
          AVNumberOfChannelsKey: 2,
          AVEncoderBitRateKey: 128000
        ]
      )
      input.expectsMediaDataInRealTime = true
      if writer.canAdd(input) {
        writer.add(input)
        audio = input
      }
    }
    let recorder = MacDisplayRecordingEngine(
      stream: stream, stopDelegate: stopDelegate,
      writer: writer, videoInput: video, audioInput: audio,
      fileURL: url, onUnexpectedStop: onUnexpectedStop
    )
    stopDelegate.onStop = { [weak recorder] error in
      recorder?.onUnexpectedStop(error)
    }
    try stream.addStreamOutput(
      recorder, type: .screen, sampleHandlerQueue: recorder.outputQueue
    )
    if withAudio && audio != nil {
      try stream.addStreamOutput(
        recorder, type: .audio, sampleHandlerQueue: recorder.outputQueue
      )
    }
    guard writer.startWriting() else {
      throw writer.error ?? NSError(domain: "NativeRecording", code: 3)
    }
    do {
      try await stream.startCapture()
      // A successful startCapture alone does not prove that macOS delivered
      // a usable screen frame. Only advertise recording after encoding begins.
      var receivedFrame = false
      for _ in 0..<16 {
        receivedFrame = recorder.outputQueue.sync { recorder.videoSamples > 0 }
        if receivedFrame { break }
        try await Task.sleep(nanoseconds: 500_000_000)
      }
      guard receivedFrame else {
        throw NSError(domain: "NativeRecording", code: 8, userInfo: [
          NSLocalizedDescriptionKey: "ScreenCaptureKit started but no video frames reached AVAssetWriter within 8 seconds. Check the screen recording permission and whether a display is available."
        ])
      }
    } catch {
      try? await stream.stopCapture()
      writer.cancelWriting()
      try? FileManager.default.removeItem(at: url)
      throw error
    }
    return recorder
  }

  func stream(_ stream: SCStream, didOutputSampleBuffer sample: CMSampleBuffer,
              of type: SCStreamOutputType) {
    guard CMSampleBufferIsValid(sample), CMSampleBufferDataIsReady(sample),
          writer.status == .writing else { return }
    let timestamp = CMSampleBufferGetPresentationTimeStamp(sample)
    guard timestamp.isValid else { return }
    if type == .screen {
      guard let attachments = CMSampleBufferGetSampleAttachmentsArray(
        sample, createIfNecessary: false
      ) as? [[SCStreamFrameInfo: Any]],
      let details = attachments.first,
      let rawStatus = details[SCStreamFrameInfo.status] as? Int,
      rawStatus == SCFrameStatus.complete.rawValue
      else { return }
      if firstTime == nil {
        firstTime = timestamp
        writer.startSession(atSourceTime: timestamp)
      }
      if videoInput.isReadyForMoreMediaData && videoInput.append(sample) {
        videoSamples += 1
      }
    } else if type == .audio, firstTime != nil, let audioInput = audioInput,
              audioInput.isReadyForMoreMediaData, audioInput.append(sample) {
      audioSamples += 1
    }
  }

  func finish() async throws -> [String: Any] {
    try? await stream.stopCapture()
    let samples: (Int, Int) = outputQueue.sync {
      let counts = (videoSamples, audioSamples)
      if writer.status == .writing {
        videoInput.markAsFinished()
        audioInput?.markAsFinished()
      }
      return counts
    }
    guard samples.0 > 0 else {
      writer.cancelWriting()
      try? FileManager.default.removeItem(at: fileURL)
      throw NSError(domain: "NativeRecording", code: 4, userInfo: [
        NSLocalizedDescriptionKey: "No encoded video frames were captured."
      ])
    }
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      writer.finishWriting { continuation.resume() }
    }
    guard writer.status == .completed else {
      throw writer.error ?? NSError(domain: "NativeRecording", code: 5, userInfo: [
        NSLocalizedDescriptionKey: "The MP4 encoder failed while finalizing."
      ])
    }
    let recordedAsset = AVURLAsset(url: fileURL)
    guard !recordedAsset.tracks(withMediaType: .video).isEmpty else {
      throw NSError(domain: "NativeRecording", code: 7, userInfo: [
        NSLocalizedDescriptionKey: "The finalized MP4 contains no playable video track."
      ])
    }
    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
    let size = (attributes[.size] as? NSNumber)?.intValue ?? 0
    guard size > 0 else {
      throw NSError(domain: "NativeRecording", code: 6, userInfo: [
        NSLocalizedDescriptionKey: "The MP4 file contains no encoded data."
      ])
    }
    return [
      "localFilePath": fileURL.path,
      "fileName": fileURL.lastPathComponent,
      "fileSizeBytes": size,
      "durationMs": Int(Date().timeIntervalSince(startTime) * 1000),
      "hasVideo": true,
      "hasAudio": samples.1 > 0
    ]
  }
}
