import AVFoundation
import UIKit
import Flutter

public final class FlutterRealtimeProcessedVideoPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_realtime_processed_video/sources", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(FlutterRealtimeProcessedVideoPlugin(), channel: channel)
  }
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    let id = args["sourceId"] as? String ?? ""
    do {
      switch call.method {
      case "setEnabled": try FlutterRealtimeProcessedVideoFrameHub.setEnabled(id, args["enabled"] as? Bool ?? false); result(nil)
      case "selectCamera": try FlutterRealtimeProcessedVideoFrameHub.selectCamera(id, args["deviceId"] as? String); result(nil)
      case "listCameras": result(AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera], mediaType: .video, position: .unspecified).devices.map { ["id": $0.uniqueID, "label": $0.localizedName, "isFrontFacing": $0.position == .front] })
      default: result(FlutterMethodNotImplemented)
      }
    } catch { result(FlutterError(code: "processed_source_failed", message: "processed.source.\(call.method)", details: nil)) }
  }
}
