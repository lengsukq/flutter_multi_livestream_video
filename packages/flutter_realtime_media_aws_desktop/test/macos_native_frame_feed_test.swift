// Native/WebKit integration regression: no camera, credentials, or network required.
import AppKit
import CoreVideo
import WebKit

@objc(FlutterRealtimeProcessedVideoFrameSink)
protocol ProbeSink: NSObjectProtocol {
  @objc(onProcessedVideoFrame:) func onProcessedVideoFrame(_ frame: NSObject)
}
@objc(FlutterRealtimeProcessedVideoFrameHub)
final class ProbeHub: NSObject {
  static var sink: NSObject?
  @objc(containsSourceId:) static func contains(_ id: String) -> Bool { id == "probe-source" }
  @objc(registerWithSourceId:sink:) static func register(_ id: String, sink: NSObject) {
    self.sink = sink
  }
  @objc(unregisterWithSourceId:sink:) static func unregister(_ id: String, sink: NSObject) {
    self.sink = nil
  }
}
@objcMembers final class ProbeFrame: NSObject {
  @objc let pixelBuffer: CVPixelBuffer
  let timestampNs: Int64
  init(_ buffer: CVPixelBuffer, timestamp: Int64) {
    pixelBuffer = buffer
    timestampNs = timestamp
  }
}
final class Probe: NSObject, WKNavigationDelegate {
  let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 100, height: 100), styleMask: [], backing: .buffered,
    defer: false)
  let handler = AwsProcessedFrameSchemeHandler()
  let feed: AwsProcessedFrameFeed
  let view: WKWebView
  var timer: DispatchSourceTimer?
  var sent = 0
  let runtimePath: String
  init(runtimePath: String) throws {
    self.runtimePath = runtimePath
    feed = try AwsProcessedFrameFeed(sourceId: "probe-source")
    let config = WKWebViewConfiguration()
    config.mediaTypesRequiringUserActionForPlayback = []
    config.setURLSchemeHandler(handler, forURLScheme: "realtime-video")
    view = WKWebView(frame: NSRect(x: 0, y: 0, width: 100, height: 100), configuration: config)
    super.init()
    handler.add(feed)
    feed.onError = {
      print("Native failure: \($0)")
      exit(1)
    }
    feed.onFrameAvailable = { [weak self] timestamp in
      self?.view.evaluateJavaScript(
        "AwsDesktopRuntime.notifyProcessedFrame('probe-source', '\(timestamp)')")
    }
  }
  func start() {
    window.contentView = view
    view.navigationDelegate = self
    view.loadHTMLString("<html><body></body></html>", baseURL: nil)
    DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
      print("Feed probe timed out")
      exit(1)
    }
  }
  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    do {
      let runtime = try String(contentsOfFile: runtimePath, encoding: .utf8)
      view.evaluateJavaScript(runtime) { [weak self] _, error in
        guard let self else { return }
        if let error {
          print(error)
          exit(1)
        }
        Task { @MainActor in
          do {
            let supported = try await self.view.callAsyncJavaScript(
              "return await AwsDesktopRuntime.canConsumeProcessedVideo()", arguments: [:], in: nil,
              contentWorld: .page)
            guard supported as? Bool == true else {
              print("Actual native image/canvas probe failed")
              exit(1)
            }
            _ = try await self.view.callAsyncJavaScript(
              """
              globalThis.MediaProviderBridge={command:async()=>{}};
              await AwsDesktopRuntime.attachProcessedVideo('chime','probe','probe-source',1);
              const video=document.createElement('video');video.muted=true;video.autoplay=true;
              video.srcObject=new MediaStream([RealtimeVideoEffectsBridge.getTrack('probe-source')]);
              document.body.appendChild(video);globalThis.probeVideo=video;globalThis.received=0;
              function frame(){globalThis.received++;video.requestVideoFrameCallback(frame);}
              video.requestVideoFrameCallback(frame);await video.play();return true;
              """, arguments: [:], in: nil, contentWorld: .page)
            self.capture()
          } catch {
            print(error)
            exit(1)
          }
        }
      }
    } catch {
      print(error)
      exit(1)
    }
  }
  func capture() {
    let timer = DispatchSource.makeTimerSource(queue: .main)
    self.timer = timer
    timer.schedule(deadline: .now(), repeating: 1.0 / 30)
    timer.setEventHandler { [weak self] in
      guard let self else { return }
      if self.sent == 60 {
        self.timer?.cancel()
        self.finish()
        return
      }
      var buffer: CVPixelBuffer?
      let result = CVPixelBufferCreate(
        kCFAllocatorDefault, 640, 360, kCVPixelFormatType_32BGRA,
        [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &buffer)
      guard result == kCVReturnSuccess, let buffer else { exit(1) }
      CVPixelBufferLockBaseAddress(buffer, [])
      let address = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
      for y in 0..<360 {
        for x in 0..<640 {
          let i = y * CVPixelBufferGetBytesPerRow(buffer) + x * 4
          address[i] = UInt8(self.sent * 4)
          address[i + 1] = UInt8(y * 255 / 360)
          address[i + 2] = UInt8(x * 255 / 640)
          address[i + 3] = 255
        }
      }
      CVPixelBufferUnlockBaseAddress(buffer, [])
      self.sent += 1
      self.feed.onProcessedVideoFrame(ProbeFrame(buffer, timestamp: Int64(self.sent) * 33_333_333))
    }
    timer.resume()
  }
  func finish() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [self] in
      view.evaluateJavaScript(
        """
        (() => {
          const canvas=document.createElement('canvas');canvas.width=640;canvas.height=360;
          const context=canvas.getContext('2d');context.drawImage(probeVideo,0,0);
          const corners=[[8,8],[631,8],[8,351],[631,351]].map(([x,y]) =>
            Array.from(context.getImageData(x,y,1,1).data));
          return {received,width:probeVideo.videoWidth,height:probeVideo.videoHeight,corners};
        })()
        """
      ) { value, error in
        if let error {
          print(error)
          exit(1)
        }
        guard let result = value as? [String: Any],
          let received = result["received"] as? Int, received > 0,
          result["width"] as? Int == 640, result["height"] as? Int == 360,
          let corners = result["corners"] as? [[Int]], corners.count == 4,
          corners[0][0] < 40, corners[0][1] < 40,
          corners[1][0] > 210, corners[1][1] < 40,
          corners[2][0] < 40, corners[2][1] > 210,
          corners[3][0] > 210, corners[3][1] > 210
        else {
          print("Native/WebKit frame content or geometry failed: \(value ?? "no result")")
          exit(1)
        }
        print(
          "PASS: sent \(self.sent) native frames, received \(received), upright full 640x360 frame."
        )
        self.feed.dispose()
        exit(0)
      }
    }
  }
}
@main struct NativeFrameFeedTest {
  static func main() throws {
    guard CommandLine.arguments.count == 2 else {
      fatalError("Provide aws_desktop_runtime.js path")
    }
    let app = NSApplication.shared
    let probe = try Probe(runtimePath: CommandLine.arguments[1])
    probe.start()
    app.run()
    withExtendedLifetime(probe) {}
  }
}
