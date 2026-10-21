#pragma once

#include <flutter_plugin_registrar.h>

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_VIDEO_EFFECTS_EXPORT __declspec(dllexport)
#else
#define FLUTTER_VIDEO_EFFECTS_EXPORT __declspec(dllimport)
#endif

#ifdef __cplusplus
extern "C" {
#endif
FLUTTER_VIDEO_EFFECTS_EXPORT void
FlutterRealtimeVideoEffectsPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);
#ifdef __cplusplus
}
#endif
