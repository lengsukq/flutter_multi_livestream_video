#include "include/flutter_realtime_media_livekit/flutter_realtime_media_livekit_plugin_c_api.h"
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <cstdint>
#include <memory>
#include <string>
#include <unordered_map>
#include <vector>
#include "processed_video_frame_client.h"
#include "processed_video_i420.h"

namespace {
using Value = flutter::EncodableValue;
using Map = flutter::EncodableMap;
using List = flutter::EncodableList;
using CreateFn = bool (*)(char*, std::size_t, char*, std::size_t);
using PushFn = bool (*)(const char*, const uint8_t*, const uint8_t*,
                       const uint8_t*, int, int);
using DisposeFn = void (*)(const char*);

class TrackBinding final {
 public:
  std::string source_id;
  std::string stream_id;
  std::string track_id;
  realtime_processed_video::FrameClient bridge;
  CreateFn create = nullptr;
  PushFn push = nullptr;
  DisposeFn dispose = nullptr;
  void* subscription = nullptr;

  static void OnFrame(void* context, const uint8_t* bgra,
                      uint32_t width, uint32_t height, uint32_t stride,
                      uint64_t) {
    auto* self = static_cast<TrackBinding*>(context);
    if (!self || !self->push) return;
    std::vector<uint8_t> i420;
    if (!realtime_processed_video::BgraToI420(bgra, width, height, stride,
                                               &i420)) {
      self->bridge.Report(self->source_id, "livekit.invalid_processed_frame");
      return;
    }
    const auto plane = static_cast<size_t>(width) * height;
    const bool ok = self->push(
        self->track_id.c_str(), i420.data(), i420.data() + plane,
        i420.data() + plane + plane / 4,
        static_cast<int>(width), static_cast<int>(height));
    if (!ok)
      self->bridge.Report(self->source_id,
                          "livekit.processed_video.push_failed");
  }

  bool Start(const std::string& source) {
    source_id = source;
    if (!bridge.Resolve()) return false;
    HMODULE webrtc = GetModuleHandleW(L"flutter_webrtc_plugin.dll");
    if (!webrtc) return false;
    create = reinterpret_cast<CreateFn>(GetProcAddress(
        webrtc, "FlutterWebRTCPluginCreateProcessedVideoStream"));
    push = reinterpret_cast<PushFn>(GetProcAddress(
        webrtc, "FlutterWebRTCPluginPushProcessedVideoFrame"));
    dispose = reinterpret_cast<DisposeFn>(GetProcAddress(
        webrtc, "FlutterWebRTCPluginDisposeProcessedVideoStream"));
    if (!create || !push || !dispose) return false;
    char stream[128] = {}, track[128] = {};
    if (!create(stream, sizeof(stream), track, sizeof(track))) return false;
    stream_id = stream;
    track_id = track;
    subscription = bridge.Subscribe(source_id, this, &OnFrame);
    if (!subscription) {
      Stop();
      return false;
    }
    return true;
  }
  void Stop() {
    if (subscription) {
      bridge.Unsubscribe(subscription);
      subscription = nullptr;
    }
    if (dispose && !track_id.empty()) {
      dispose(track_id.c_str());
      track_id.clear();
      stream_id.clear();
    }
  }
  ~TrackBinding() { Stop(); }
};

class LivekitPlugin final : public flutter::Plugin {
 public:
  explicit LivekitPlugin(flutter::PluginRegistrarWindows* registrar) {
    channel_ = std::make_unique<flutter::MethodChannel<Value>>(
        registrar->messenger(), "flutter_realtime_media_livekit/processed_video",
        &flutter::StandardMethodCodec::GetInstance());
    channel_->SetMethodCallHandler([this](const auto& call, auto result) {
      const auto* args = std::get_if<Map>(call.arguments());
      if (!args) {
        result->Error("invalid_argument", "Missing source arguments");
        return;
      }
      const auto found = args->find(Value("sourceId"));
      const auto* id = found == args->end()
          ? nullptr : std::get_if<std::string>(&found->second);
      if (!id || id->empty()) {
        result->Error("invalid_argument", "sourceId required");
        return;
      }
      if (call.method_name() == "dispose") {
        bindings_.erase(*id);
        result->Success();
        return;
      }
      if (call.method_name() != "create") {
        result->NotImplemented();
        return;
      }
      bindings_.erase(*id);
      auto binding = std::make_unique<TrackBinding>();
      if (!binding->Start(*id)) {
        result->Error("processed_binding_failed",
                      "LiveKit Windows custom WebRTC track unavailable");
        return;
      }
      const std::string stream_id = binding->stream_id;
      const std::string track_id = binding->track_id;
      bindings_[*id] = std::move(binding);
      result->Success(Value(Map{
          {Value("streamId"), Value(stream_id)},
          {Value("audioTracks"), Value(List{})},
          {Value("videoTracks"), Value(List{Value(Map{
              {Value("id"), Value(track_id)},
              {Value("label"), Value("processed_video")},
              {Value("kind"), Value("video")},
              {Value("enabled"), Value(true)},
              {Value("settings"), Value(Map{})}
          })})}
      }));
    });
  }
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
    registrar->AddPlugin(std::make_unique<LivekitPlugin>(registrar));
  }
 private:
  std::unique_ptr<flutter::MethodChannel<Value>> channel_;
  std::unordered_map<std::string, std::unique_ptr<TrackBinding>> bindings_;
};
}  // namespace

void FlutterRealtimeMediaLivekitPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  LivekitPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
