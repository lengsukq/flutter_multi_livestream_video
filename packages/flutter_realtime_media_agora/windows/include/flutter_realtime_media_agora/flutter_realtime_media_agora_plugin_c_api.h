#pragma once
#include <flutter_plugin_registrar.h>
#ifdef FLUTTER_PLUGIN_IMPL
#define REALTIME_AGORA_EXPORT __declspec(dllexport)
#else
#define REALTIME_AGORA_EXPORT __declspec(dllimport)
#endif
#ifdef __cplusplus
extern "C" {
#endif
REALTIME_AGORA_EXPORT void FlutterRealtimeMediaAgoraPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);
#ifdef __cplusplus
}
#endif
