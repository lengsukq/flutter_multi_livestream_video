#pragma once
#include <flutter_plugin_registrar.h>
#ifdef FLUTTER_PLUGIN_IMPL
#define REALTIME_TRTC_EXPORT __declspec(dllexport)
#else
#define REALTIME_TRTC_EXPORT __declspec(dllimport)
#endif
#ifdef __cplusplus
extern "C" {
#endif
REALTIME_TRTC_EXPORT void FlutterRealtimeMediaTrtcPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);
#ifdef __cplusplus
}
#endif
