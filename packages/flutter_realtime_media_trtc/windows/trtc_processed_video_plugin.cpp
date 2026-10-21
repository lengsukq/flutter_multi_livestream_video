#include "include/flutter_realtime_media_trtc/flutter_realtime_media_trtc_plugin_c_api.h"
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <TRTC/ITRTCCloud.h>
#include <windows.h>
#include <algorithm>
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
using namespace liteav;

std::string GetString(const Map& args, const char* key) {
  const auto it = args.find(Value(key));
  if (it == args.end()) return {};
  auto* value = std::get_if<std::string>(&it->second);
  return value ? *value : "";
}

struct Binding final {
  std::string source_id;
  realtime_processed_video::FrameClient bridge;
  liteav::ITRTCCloud* engine = nullptr; // borrowed singleton; never destroy
  void* subscription = nullptr;
  bool enabled = false;

  static void OnFrame(void* context, const uint8_t* bgra,
                      uint32_t width, uint32_t height, uint32_t stride,
                      uint64_t timestamp_ns) {
    auto* self = static_cast<Binding*>(context);
    if (!self || !self->enabled || !self->engine) return;
    std::vector<std::uint8_t> i420;
    if (!realtime_processed_video::BgraToI420(
            bgra, width, height, stride, &i420)) {
      self->bridge.Report(self->source_id, "trtc.invalid_processed_frame");
      return;
    }
    TRTCVideoFrame frame;
    frame.videoFormat = TRTCVideoPixelFormat_I420;
    frame.bufferType = TRTCVideoBufferType_Buffer;
    frame.data = reinterpret_cast<char*>(i420.data());
    frame.length = static_cast<uint32_t>(i420.size());
    frame.width = width;
    frame.height = height;
    frame.timestamp = timestamp_ns / 1000000;
    frame.rotation = TRTCVideoRotation0;
    self->engine->sendCustomVideoData(TRTCVideoStreamTypeBig, &frame);
  }

  bool Start(const std::string& source) {
    source_id = source;
    if (!bridge.Resolve()) return false;
    // Use the same TRTC singleton that the tencent_rtc_sdk FFI wrapper uses.
    HMODULE library = GetModuleHandleW(L"liteav.dll");
    if (!library) return false;
    auto get_instance = reinterpret_cast<liteav::ITRTCCloud* (*)()>(
        GetProcAddress(library, "getTRTCShareInstance"));
    if (!get_instance) return false;
    engine = get_instance();
    if (!engine) return false;
    engine->stopLocalPreview();
    engine->enableCustomVideoCapture(TRTCVideoStreamTypeBig, true);
    enabled = true;
    subscription = bridge.Subscribe(source_id, this, &OnFrame);
    if (!subscription) {
      Stop();
      return false;
    }
    return true;
  }
  void Stop() {
    enabled = false;
    if (subscription) {
      bridge.Unsubscribe(subscription);
      subscription = nullptr;
    }
    if (engine) {
      engine->enableCustomVideoCapture(TRTCVideoStreamTypeBig, false);
      engine = nullptr;
    }
  }
  ~Binding() { Stop(); }
};

class TrtcPlugin final : public flutter::Plugin {
 public:
  explicit TrtcPlugin(flutter::PluginRegistrarWindows* registrar) {
    channel_ = std::make_unique<flutter::MethodChannel<Value>>(
        registrar->messenger(), "flutter_realtime_media_trtc/processed_video",
        &flutter::StandardMethodCodec::GetInstance());
    channel_->SetMethodCallHandler([this](const auto& call, auto result) {
      const auto* args = std::get_if<Map>(call.arguments());
      if (!args) {
        result->Error("invalid_argument", "Missing provider binding arguments");
        return;
      }
      const auto binding = GetString(*args, "bindingId");
      const auto source = GetString(*args, "sourceId");
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
      if (!sink->Start(source)) {
        result->Error("processed_binding_failed",
                      "TRTC Windows custom video capture unavailable");
        return;
      }
      sinks_[binding] = std::move(sink);
      result->Success();
    });
  }
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
    registrar->AddPlugin(std::make_unique<TrtcPlugin>(registrar));
  }
 private:
  std::unique_ptr<flutter::MethodChannel<Value>> channel_;
  std::unordered_map<std::string, std::unique_ptr<Binding>> sinks_;
};
} // namespace

void FlutterRealtimeMediaTrtcPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  TrtcPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
