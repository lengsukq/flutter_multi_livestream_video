#ifndef PLUGINS_FLUTTER_WEBRTC_PLUGIN_CPP_H_
#define PLUGINS_FLUTTER_WEBRTC_PLUGIN_CPP_H_

#include <flutter_plugin_registrar.h>
#include <cstddef>
#include <cstdint>

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FLUTTER_PLUGIN_EXPORT __declspec(dllimport)
#endif

namespace flutter_webrtc_plugin {
class FlutterWebRTC;
}  // namespace flutter_webrtc_plugin

#if defined(__cplusplus)
extern "C" {
#endif

FLUTTER_PLUGIN_EXPORT void FlutterWebRTCPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);

FLUTTER_PLUGIN_EXPORT flutter_webrtc_plugin::FlutterWebRTC* FlutterWebRTCPluginSharedInstance();

FLUTTER_PLUGIN_EXPORT bool FlutterWebRTCPluginCreateProcessedVideoStream(
    char* stream_id, size_t stream_capacity,
    char* track_id, size_t track_capacity);
FLUTTER_PLUGIN_EXPORT bool FlutterWebRTCPluginPushProcessedVideoFrame(
    const char* track_id, const uint8_t* y, const uint8_t* u, const uint8_t* v,
    int width, int height);
FLUTTER_PLUGIN_EXPORT void FlutterWebRTCPluginDisposeProcessedVideoStream(
    const char* track_id);

#if defined(__cplusplus)
}  // extern "C"
#endif

#endif  // PLUGINS_FLUTTER_WEBRTC_PLUGIN_CPP_H_
