#ifndef FLUTTER_REALTIME_SCREEN_ANNOTATION_PLUGIN_C_API_H_
#define FLUTTER_REALTIME_SCREEN_ANNOTATION_PLUGIN_C_API_H_
#include <flutter_plugin_registrar.h>
#ifdef FLUTTER_PLUGIN_IMPL
#define ANNOTATION_EXPORT __declspec(dllexport)
#else
#define ANNOTATION_EXPORT __declspec(dllimport)
#endif
#ifdef __cplusplus
extern "C" {
#endif
ANNOTATION_EXPORT void FlutterRealtimeScreenAnnotationPluginCApiRegisterWithRegistrar(FlutterDesktopPluginRegistrarRef registrar);
#ifdef __cplusplus
}
#endif
#endif
