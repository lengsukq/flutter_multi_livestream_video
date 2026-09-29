//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import agora_rtc_engine
import connectivity_plus
import device_info_plus
import flutter_realtime_chat_agora
import flutter_webrtc
import iris_method_channel
import livekit_client
import shared_preferences_foundation
import tencent_cloud_chat_sdk
import tencent_rtc_sdk

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  AgoraRtcNgPlugin.register(with: registry.registrar(forPlugin: "AgoraRtcNgPlugin"))
  ConnectivityPlusPlugin.register(with: registry.registrar(forPlugin: "ConnectivityPlusPlugin"))
  DeviceInfoPlusMacosPlugin.register(with: registry.registrar(forPlugin: "DeviceInfoPlusMacosPlugin"))
  AgoraChatMacOSPlugin.register(with: registry.registrar(forPlugin: "AgoraChatMacOSPlugin"))
  FlutterWebRTCPlugin.register(with: registry.registrar(forPlugin: "FlutterWebRTCPlugin"))
  IrisMethodChannelPlugin.register(with: registry.registrar(forPlugin: "IrisMethodChannelPlugin"))
  LiveKitPlugin.register(with: registry.registrar(forPlugin: "LiveKitPlugin"))
  SharedPreferencesPlugin.register(with: registry.registrar(forPlugin: "SharedPreferencesPlugin"))
  TencentCloudChatSdkPlugin.register(with: registry.registrar(forPlugin: "TencentCloudChatSdkPlugin"))
  TencentRTCCloud.register(with: registry.registrar(forPlugin: "TencentRTCCloud"))
}
