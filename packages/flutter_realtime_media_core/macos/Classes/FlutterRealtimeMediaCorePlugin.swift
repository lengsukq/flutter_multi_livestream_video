import AVFoundation
import Cocoa
import FlutterMacOS

/// Shared macOS TCC permission bridge; independent of the selected RTC provider.
public final class FlutterRealtimeMediaCorePlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "flutter_realtime_media_core/permissions",
      binaryMessenger: registrar.messenger
    )
    registrar.addMethodCallDelegate(FlutterRealtimeMediaCorePlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "openSettings" {
      guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") else {
        result(false)
        return
      }
      result(NSWorkspace.shared.open(url))
      return
    }

    guard let args = call.arguments as? [String: Any],
          let kind = args["kind"] as? String else {
      result(FlutterError(code: "invalid_arguments", message: "Missing media permission kind", details: nil))
      return
    }

    let mediaType: AVMediaType
    switch kind {
    case "camera": mediaType = .video
    case "microphone": mediaType = .audio
    default:
      result(FlutterError(code: "invalid_arguments", message: "Unknown media permission kind", details: nil))
      return
    }

    switch call.method {
    case "status":
      result(statusName(AVCaptureDevice.authorizationStatus(for: mediaType)))
    case "request":
      if AVCaptureDevice.authorizationStatus(for: mediaType) == .notDetermined {
        AVCaptureDevice.requestAccess(for: mediaType) { _ in
          DispatchQueue.main.async {
            result(self.statusName(AVCaptureDevice.authorizationStatus(for: mediaType)))
          }
        }
      } else {
        result(statusName(AVCaptureDevice.authorizationStatus(for: mediaType)))
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func statusName(_ status: AVAuthorizationStatus) -> String {
    switch status {
    case .authorized: return "granted"
    case .notDetermined: return "unknown"
    case .denied: return "permanentlyDenied"
    case .restricted: return "restricted"
    @unknown default: return "unknown"
    }
  }
}
