//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <agora_rtc_engine/agora_rtc_engine_plugin.h>
#include <connectivity_plus/connectivity_plus_windows_plugin.h>
#include <flutter_webrtc/flutter_web_r_t_c_plugin.h>
#include <iris_method_channel/iris_method_channel_plugin_c_api.h>
#include <livekit_client/live_kit_plugin.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  AgoraRtcEnginePluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("AgoraRtcEnginePlugin"));
  ConnectivityPlusWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("ConnectivityPlusWindowsPlugin"));
  FlutterWebRTCPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterWebRTCPlugin"));
  IrisMethodChannelPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("IrisMethodChannelPluginCApi"));
  LiveKitPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("LiveKitPlugin"));
}
