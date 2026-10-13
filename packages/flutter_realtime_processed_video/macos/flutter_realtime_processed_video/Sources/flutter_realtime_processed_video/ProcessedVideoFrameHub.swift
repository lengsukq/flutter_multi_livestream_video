import Foundation
import CoreVideo
import CoreMedia

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
  private static var controls: [String: ((Bool) throws -> Void, (String?) throws -> Void, (String) -> Void)] = [:]
  public static func registerControl(_ sourceId: String, enable: @escaping (Bool) throws -> Void, camera: @escaping (String?) throws -> Void, failure: @escaping (String) -> Void) {
    lock.lock(); defer { lock.unlock() }; controls[sourceId] = (enable, camera, failure)
  }
  public static func setEnabled(_ sourceId: String, _ enabled: Bool) throws {
    lock.lock(); let control = controls[sourceId]; lock.unlock()
    guard let control else { throw NSError(domain: "processed.source", code: 1) }
    try control.0(enabled)
  }
  public static func selectCamera(_ sourceId: String, _ camera: String?) throws {
    lock.lock(); let control = controls[sourceId]; lock.unlock()
    guard let control else { throw NSError(domain: "processed.source", code: 1) }
    try control.1(camera)
  }
  @objc(reportFailureWithSourceId:message:) public static func reportFailure(_ sourceId: String, _ message: String) {
    lock.lock(); let control = controls[sourceId]; lock.unlock(); control?.2(message)
  }

  @objc(containsSourceId:) public static func contains(sourceId: String) -> Bool {
    lock.lock(); defer { lock.unlock() }
    return activeSources.contains(sourceId)
  }

  public static func activate(_ sourceId: String) {
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

  public static func clear(_ sourceId: String) {
    lock.lock(); defer { lock.unlock() }
    sinks.removeValue(forKey: sourceId)
    activeSources.remove(sourceId)
    controls.removeValue(forKey: sourceId)
  }

  public static func publish(_ frame: FlutterRealtimeProcessedVideoFrame) {
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

