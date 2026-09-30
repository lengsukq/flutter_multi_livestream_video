import AppKit
import CoreVideo
import Foundation
import WebKit

@objc(FlutterRealtimeProcessedVideoFrameSink)
protocol TestProcessedVideoFrameSink: NSObjectProtocol {
  @objc(onProcessedVideoFrame:)
  func onProcessedVideoFrame(_ frame: NSObject)
}

@objc(FlutterRealtimeProcessedVideoFrameHub)
final class TestProcessedVideoFrameHub: NSObject {
  private static var activeSourceIds: Set<String> = []
  private static var sinks: [String: [ObjectIdentifier: NSObject]] = [:]

  @objc(containsSourceId:)
  static func containsSourceId(_ sourceId: NSString) -> Bool {
    activeSourceIds.contains(sourceId as String)
  }

  @objc(registerWithSourceId:sink:)
  static func register(sourceId: NSString, sink: NSObject) {
    sinks[sourceId as String, default: [:]][ObjectIdentifier(sink)] = sink
  }

  @objc(unregisterWithSourceId:sink:)
  static func unregister(sourceId: NSString, sink: NSObject) {
    sinks[sourceId as String]?.removeValue(forKey: ObjectIdentifier(sink))
  }

  static func activate(_ sourceId: String) {
    activeSourceIds.insert(sourceId)
  }

  static func publish(_ frame: NSObject, sourceId: String) {
    let current = sinks[sourceId].map { Array($0.values) } ?? []
    for sink in current {
      _ = sink.perform(NSSelectorFromString("onProcessedVideoFrame:"), with: frame)
    }
  }

  static func sinkCount(for sourceId: String) -> Int {
    sinks[sourceId]?.count ?? 0
  }
}

@objc(FlutterRealtimeProcessedVideoFrame)
@objcMembers
final class TestProcessedVideoFrame: NSObject {
  dynamic var pixelBuffer: CVPixelBuffer
  dynamic var timestampNs: NSNumber

  init(pixelBuffer: CVPixelBuffer, timestampNs: Int64) {
    self.pixelBuffer = pixelBuffer
    self.timestampNs = NSNumber(value: timestampNs)
    super.init()
  }

  override func value(forKey key: String) -> Any? {
    switch key {
    case "pixelBuffer": return pixelBuffer
    case "timestampNs": return timestampNs
    default: return super.value(forKey: key)
    }
  }
}

private func makeGreenPixelBuffer(width: Int, height: Int) throws -> CVPixelBuffer {
  var buffer: CVPixelBuffer?
  let status = CVPixelBufferCreate(
    kCFAllocatorDefault,
    width,
    height,
    kCVPixelFormatType_32BGRA,
    [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary,
    &buffer
  )
  guard status == kCVReturnSuccess, let buffer else {
    throw NSError(domain: "ProcessedFrameIntegration", code: Int(status))
  }
  CVPixelBufferLockBaseAddress(buffer, [])
  defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
  guard let base = CVPixelBufferGetBaseAddress(buffer) else {
    throw NSError(domain: "ProcessedFrameIntegration", code: 2)
  }
  let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
  for y in 0..<height {
    let row = base.advanced(by: y * rowBytes).assumingMemoryBound(to: UInt8.self)
    for x in 0..<width {
      let pixel = row.advanced(by: x * 4)
      pixel[0] = 0
      pixel[1] = 255
      pixel[2] = 0
      pixel[3] = 255
    }
  }
  return buffer
}

private final class IntegrationRunner: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
  private let sourceId = "integration-source"
  private let feed: AwsProcessedFrameFeed
  private let schemeHandler: AwsProcessedFrameSchemeHandler
  private let runtimePath: String
  private var webView: WKWebView!
  private var window: NSWindow!

  init(feed: AwsProcessedFrameFeed, schemeHandler: AwsProcessedFrameSchemeHandler, runtimePath: String) {
    self.feed = feed
    self.schemeHandler = schemeHandler
    self.runtimePath = runtimePath
  }

  func run() throws {
    let configuration = WKWebViewConfiguration()
    configuration.setURLSchemeHandler(schemeHandler, forURLScheme: "realtime-video")
    configuration.mediaTypesRequiringUserActionForPlayback = []
    configuration.userContentController.add(self, name: "awsDesktop")
    webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 240, height: 120), configuration: configuration)
    webView.navigationDelegate = self

    let runtime = try String(contentsOfFile: runtimePath, encoding: .utf8)
    let encoded = Data(runtime.utf8).base64EncodedString()
    window = NSWindow(
      contentRect: NSRect(x: -2, y: -2, width: 240, height: 120),
      styleMask: .borderless,
      backing: .buffered,
      defer: false
    )
    window.alphaValue = 0.01
    window.contentView?.addSubview(webView)
    window.orderFrontRegardless()
    webView.loadHTMLString(
      "<html><body><script src='data:text/javascript;base64,\(encoded)'></script></body></html>",
      baseURL: URL(fileURLWithPath: NSTemporaryDirectory())
    )
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    Task { @MainActor in
      do {
        let result = try await webView.callAsyncJavaScript(
          """
          let inputTrack;
          const commands = [];
          globalThis.MediaProviderBridge = {
            command: async function(providerId, sessionId, name, args) {
              commands.push(name);
              if (name === 'attachProcessedVideoSource') {
                inputTrack = RealtimeVideoEffectsBridge.getTrack(JSON.parse(args).sourceId);
              }
            }
          };
          await AwsDesktopRuntime.attachProcessedVideo('chime', 'integration-session', sourceId, 1);
          const video = document.createElement('video');
          video.muted = true;
          video.playsInline = true;
          document.body.appendChild(video);
          video.srcObject = new MediaStream([inputTrack]);
          await video.play();
          await new Promise(function(resolve) { setTimeout(resolve, 350); });
          const canvas = document.createElement('canvas');
          canvas.width = 8;
          canvas.height = 4;
          const context = canvas.getContext('2d', { alpha: false });
          context.drawImage(video, 0, 0, canvas.width, canvas.height);
          const color = Array.from(context.getImageData(4, 2, 1, 1).data);
          const dimensions = [video.videoWidth, video.videoHeight];
          const readyStateBeforeDetach = inputTrack.readyState;
          await AwsDesktopRuntime.detachProcessedVideo('chime', 'integration-session', sourceId, 2);
          return {
            dimensions: dimensions,
            color: color,
            readyStateBeforeDetach: readyStateBeforeDetach,
            readyStateAfterDetach: inputTrack.readyState,
            commands: commands
          };
          """,
          arguments: ["sourceId": sourceId],
          in: nil,
          contentWorld: .page
        ) as? [String: Any]
        guard
          let dimensions = result?["dimensions"] as? [Int], dimensions == [8, 4],
          let color = result?["color"] as? [Int], color.count == 4,
          color[1] > 180, color[0] < 80, color[2] < 80,
          result?["readyStateBeforeDetach"] as? String == "live",
          result?["readyStateAfterDetach"] as? String == "ended",
          result?["commands"] as? [String] == ["attachProcessedVideoSource", "detachProcessedVideoSource"]
        else {
          fail("WebKit native-frame pipeline assertion failed: \(String(describing: result))")
          return
        }
        feed.dispose()
        guard TestProcessedVideoFrameHub.sinkCount(for: sourceId) == 0 else {
          fail("The native frame hub retained its sink after feed disposal.")
          return
        }
        print("PASS: dynamic Objective-C hub -> CI JPEG -> WK scheme -> canvas captureStream (\(color))")
        exit(0)
      } catch {
        fail("WebKit native-frame pipeline threw: \(error)")
      }
    }
  }

  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    guard
      let body = message.body as? [String: Any],
      body["kind"] as? String == "processedVideoError"
    else { return }
    fail("The WebKit runtime reported a processed-frame error: \(body)")
  }

  private func fail(_ message: String) {
    fputs("FAIL: \(message)\n", stderr)
    exit(1)
  }
}

@main
struct AwsProcessedFrameFeedIntegration {
  static func main() throws {
    guard CommandLine.arguments.count == 2 else {
      throw NSError(domain: "ProcessedFrameIntegration", code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "Pass the AWS desktop runtime JavaScript path."])
    }
    let sourceId = "integration-source"
    TestProcessedVideoFrameHub.activate(sourceId)
    let feed = try AwsProcessedFrameFeed(sourceId: sourceId)
    let schemeHandler = AwsProcessedFrameSchemeHandler()
    schemeHandler.add(feed)

    let buffer = try makeGreenPixelBuffer(width: 8, height: 4)
    let frame = TestProcessedVideoFrame(pixelBuffer: buffer, timestampNs: 123_000_000)
    TestProcessedVideoFrameHub.publish(frame, sourceId: sourceId)
    let deadline = Date().addingTimeInterval(5)
    while feed.snapshot() == nil && Date() < deadline {
      RunLoop.current.run(until: Date().addingTimeInterval(0.02))
    }
    guard let encoded = feed.snapshot()?.data, encoded.starts(with: [0xff, 0xd8]),
          TestProcessedVideoFrameHub.sinkCount(for: sourceId) == 1 else {
      throw NSError(domain: "ProcessedFrameIntegration", code: 4,
                    userInfo: [NSLocalizedDescriptionKey: "Dynamic hub dispatch did not produce a JPEG frame."])
    }

    let app = NSApplication.shared
    app.setActivationPolicy(.prohibited)
    let runner = IntegrationRunner(feed: feed, schemeHandler: schemeHandler, runtimePath: CommandLine.arguments[1])
    try runner.run()
    DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
      fputs("FAIL: Timed out waiting for the WebKit integration pipeline.\n", stderr)
      exit(2)
    }
    app.run()
  }
}
