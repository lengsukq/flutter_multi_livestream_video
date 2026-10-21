#include "flutter_webrtc/flutter_web_r_t_c_plugin.h"

#include "flutter_common.h"
#include "flutter_webrtc.h"
#include "task_runner_windows.h"

#include <flutter/plugin_registrar_windows.h>
#include <flutter_messenger.h>
#include <flutter_plugin_registrar.h>
#include <cstring>

const char* kChannelName = "FlutterWebRTC.Method";
static flutter_webrtc_plugin::FlutterWebRTC* g_shared_instance = nullptr;

namespace flutter_webrtc_plugin {

// A webrtc plugin for windows/linux.
class FlutterWebRTCPluginImpl : public FlutterWebRTCPlugin {
 public:
  static void RegisterWithRegistrar(PluginRegistrar* registrar) {
    auto channel = std::make_unique<MethodChannel>(
        registrar->messenger(), kChannelName,
        &flutter::StandardMethodCodec::GetInstance());

    auto* channel_pointer = channel.get();

    // Uses new instead of make_unique due to private constructor.
    std::unique_ptr<FlutterWebRTCPluginImpl> plugin(
        new FlutterWebRTCPluginImpl(registrar, std::move(channel)));
    channel_pointer->SetMethodCallHandler(
        [plugin_pointer = plugin.get()](const auto& call, auto result) {
          plugin_pointer->HandleMethodCall(call, std::move(result));
        });

    registrar->AddPlugin(std::move(plugin));
  }

  virtual ~FlutterWebRTCPluginImpl() {
    g_shared_instance = nullptr;
  }

  BinaryMessenger* messenger() { return messenger_; }

  TextureRegistrar* textures() { return textures_; }

  TaskRunner* task_runner() { return task_runner_.get(); }

 private:
  // Creates a plugin that communicates on the given channel.
  FlutterWebRTCPluginImpl(PluginRegistrar* registrar,
                          std::unique_ptr<MethodChannel> channel)
      : channel_(std::move(channel)),
        messenger_(registrar->messenger()),
        textures_(registrar->texture_registrar()),
        task_runner_(std::make_unique<TaskRunnerWindows>()) {
    webrtc_ = std::make_unique<FlutterWebRTC>(this);
    g_shared_instance = webrtc_.get();
  }

  // Called when a method is called on |channel_|;
  void HandleMethodCall(const MethodCall& method_call,
                        std::unique_ptr<MethodResult> result) {
    // handle method call and forward to webrtc native sdk.
    auto method_call_proxy = MethodCallProxy::Create(method_call);
    webrtc_->HandleMethodCall(*method_call_proxy.get(),
                              MethodResultProxy::Create(std::move(result)));
  }

 private:
  std::unique_ptr<MethodChannel> channel_;
  std::unique_ptr<FlutterWebRTC> webrtc_;
  BinaryMessenger* messenger_;
  TextureRegistrar* textures_;
  std::unique_ptr<TaskRunner> task_runner_;
};

}  // namespace flutter_webrtc_plugin


void FlutterWebRTCPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  // Capture the host messenger before creating the plugin, so that the event
  // channels can check whether the engine is still running before they
  // unregister their stream handlers; see ~EventChannelProxyImpl in
  // common/cpp/src/flutter_common.cc.
  SetEventChannelHostMessenger(
      FlutterDesktopPluginRegistrarGetMessenger(registrar));
  flutter_webrtc_plugin::FlutterWebRTCPluginImpl::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}

flutter_webrtc_plugin::FlutterWebRTC* FlutterWebRTCPluginSharedInstance() {
  return g_shared_instance;
}

bool FlutterWebRTCPluginCreateProcessedVideoStream(
    char* stream_id, size_t stream_capacity,
    char* track_id, size_t track_capacity) {
  if (!g_shared_instance || !stream_id || !track_id ||
      stream_capacity < 128 || track_capacity < 128) return false;
  std::string stream, track;
  if (!g_shared_instance->CreateProcessedVideoStream(&stream, &track))
    return false;
  if (stream.size() >= stream_capacity || track.size() >= track_capacity) {
    g_shared_instance->DisposeProcessedVideoStream(track);
    return false;
  }
  std::memcpy(stream_id, stream.c_str(), stream.size() + 1);
  std::memcpy(track_id, track.c_str(), track.size() + 1);
  return true;
}

bool FlutterWebRTCPluginPushProcessedVideoFrame(
    const char* track_id, const uint8_t* y, const uint8_t* u,
    const uint8_t* v, int width, int height) {
  return g_shared_instance && track_id &&
      g_shared_instance->PushProcessedVideoFrame(track_id, y, u, v,
                                                 width, height);
}

void FlutterWebRTCPluginDisposeProcessedVideoStream(const char* track_id) {
  if (g_shared_instance && track_id)
    g_shared_instance->DisposeProcessedVideoStream(track_id);
}