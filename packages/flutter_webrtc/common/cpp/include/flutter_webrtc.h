#ifndef PLUGINS_FLUTTER_WEBRTC_HXX
#define PLUGINS_FLUTTER_WEBRTC_HXX

#include "flutter_common.h"

#include "flutter_data_channel.h"
#include "flutter_data_packet_cryptor.h"
#include "flutter_frame_cryptor.h"
#include "flutter_media_stream.h"
#include "flutter_peerconnection.h"
#include "flutter_screen_capture.h"
#include "flutter_video_renderer.h"

#include "libwebrtc.h"
#include "rtc_logging.h"
#include <map>
#include <mutex>

namespace flutter_webrtc_plugin {

using namespace libwebrtc;

class FlutterWebRTCPlugin : public flutter::Plugin {
 public:
  virtual BinaryMessenger* messenger() = 0;

  virtual TextureRegistrar* textures() = 0;

  virtual TaskRunner* task_runner() = 0;
};

class FlutterWebRTC : public FlutterWebRTCBase,
                      public FlutterVideoRendererManager,
                      public FlutterMediaStream,
                      public FlutterPeerConnection,
                      public FlutterScreenCapture,
                      public FlutterDataChannel,
                      public FlutterFrameCryptor,
                      public FlutterDataPacketCryptor {
 public:
  FlutterWebRTC(FlutterWebRTCPlugin* plugin);
  virtual ~FlutterWebRTC();

  void HandleMethodCall(const MethodCallProxy& method_call,
                        std::unique_ptr<MethodResultProxy> result);

#if defined(_WIN32)
  bool CreateProcessedVideoStream(std::string* stream_id,
                                  std::string* track_id);
  bool PushProcessedVideoFrame(const std::string& track_id,
                               const std::uint8_t* y,
                               const std::uint8_t* u,
                               const std::uint8_t* v,
                               int width, int height);
  void DisposeProcessedVideoStream(const std::string& track_id);
#endif

 private:
  void initLoggerCallback(RTCLoggingSeverity severity);
  RTCLoggingSeverity str2LogSeverity(std::string str);
#if defined(_WIN32)
  std::mutex processed_mutex_;
  std::map<std::string, scoped_refptr<RTCVideoSource>> processed_sources_;
  std::map<std::string, std::string> processed_stream_ids_;
#endif
};

}  // namespace flutter_webrtc_plugin

#endif  // PLUGINS_FLUTTER_WEBRTC_HXX
