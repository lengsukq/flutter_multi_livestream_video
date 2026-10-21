#include "include/flutter_realtime_media_agora/flutter_realtime_media_agora_plugin_c_api.h"
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <IAgoraRtcEngine.h>
#include <IAgoraMediaEngine.h>
#include <windows.h>
#include <cstdint>
#include <memory>
#include <string>
#include <unordered_map>
#include "processed_video_frame_client.h"

namespace {
using Value = flutter::EncodableValue;
using Map = flutter::EncodableMap;

std::string StringArg(const Map& args, const char* key) {
  auto it = args.find(Value(key));
  if (it == args.end()) return {};
  if (auto* value = std::get_if<std::string>(&it->second)) return *value;
  return {};
}
std::int64_t NumberArg(const Map& args, const char* key) {
  auto it = args.find(Value(key));
  if (it == args.end()) return 0;
  if (auto* value = std::get_if<std::int64_t>(&it->second)) return *value;
  if (auto* value = std::get_if<std::int32_t>(&it->second)) return *value;
  return 0;
}

struct Binding final {
  std::string source_id;
  realtime_processed_video::FrameClient bridge;
  agora::media::IMediaEngine* media = nullptr;
  std::uint32_t track_id = 0;
  void* subscription = nullptr;

  static void OnFrame(void* context, const uint8_t* bgra,
                      uint32_t width, uint32_t height, uint32_t stride,
                      uint64_t timestamp_ns) {
    auto* self = static_cast<Binding*>(context);
    if (!self || !self->media || !bgra || width == 0 ||
        stride < width * 4 || stride % 4 != 0) return;
    agora::media::base::ExternalVideoFrame frame;
    frame.format = agora::media::base::VIDEO_PIXEL_BGRA;
    frame.buffer = const_cast<std::uint8_t*>(bgra);
    frame.stride = static_cast<int>(stride / 4);
    frame.height = static_cast<int>(height);
    frame.cropRight = frame.stride - static_cast<int>(width);
    frame.timestamp = static_cast<long long>(timestamp_ns / 1000000);
    const int status = self->media->pushVideoFrame(&frame, self->track_id);
    if (status != 0)
      self->bridge.Report(self->source_id, "agora.processed_frame.rejected");
  }

  bool Start(const std::string& source, std::int64_t engine_handle,
             std::uint32_t track) {
    source_id = source;
    track_id = track;
    if (!bridge.Resolve() || !engine_handle || !track_id) return false;
    auto* engine = reinterpret_cast<agora::rtc::IRtcEngine*>(
        static_cast<std::uintptr_t>(engine_handle));
    if (!engine ||
        engine->queryInterface(agora::rtc::AGORA_IID_MEDIA_ENGINE,
                               reinterpret_cast<void**>(&media)) != 0 ||
        !media) return false;
    subscription = bridge.Subscribe(source_id, this, &OnFrame);
    return subscription != nullptr;
  }
  void Stop() {
    if (subscription) {
      bridge.Unsubscribe(subscription);
      subscription = nullptr;
    }
    if (media) {
      media->release();
      media = nullptr;
    }
  }
  ~Binding() { Stop(); }
};

class AgoraPlugin final : public flutter::Plugin {
 public:
  explicit AgoraPlugin(flutter::PluginRegistrarWindows* registrar) {
    channel_ = std::make_unique<flutter::MethodChannel<Value>>(
        registrar->messenger(), "flutter_realtime_media_agora/processed_video",
        &flutter::StandardMethodCodec::GetInstance());
    channel_->SetMethodCallHandler([this](const auto& call, auto result) {
      const auto* args = std::get_if<Map>(call.arguments());
      if (!args) {
        result->Error("invalid_argument", "Missing binding arguments");
        return;
      }
      const auto binding = StringArg(*args, "bindingId");
      const auto source = StringArg(*args, "sourceId");
      if (binding.empty() || source.empty()) {
        result->Error("invalid_argument", "Missing sourceId or bindingId");
        return;
      }
      if (call.method_name() == "detachProvider") {
        sinks_.erase(binding);
        result->Success();
        return;
      }
      if (call.method_name() != "attachProvider") {
        result->NotImplemented();
        return;
      }
      sinks_.erase(binding);
      auto sink = std::make_unique<Binding>();
      if (!sink->Start(source, NumberArg(*args, "engineHandle"),
                       static_cast<std::uint32_t>(NumberArg(*args, "trackId")))) {
        result->Error("processed_binding_failed",
                      "Agora Windows external video binding failed");
        return;
      }
      sinks_[binding] = std::move(sink);
      result->Success();
    });
  }
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
    registrar->AddPlugin(std::make_unique<AgoraPlugin>(registrar));
  }
 private:
  std::unique_ptr<flutter::MethodChannel<Value>> channel_;
  std::unordered_map<std::string, std::unique_ptr<Binding>> sinks_;
};
} // namespace

void FlutterRealtimeMediaAgoraPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  AgoraPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
