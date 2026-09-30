#include <jni.h>
#include "IAgoraRtcEngine.h"
#include "IAgoraMediaEngine.h"
using agora::media::IMediaEngine;
extern "C" JNIEXPORT jlong JNICALL
Java_com_oneplusdream_flutter_1realtime_1video_1effects_AgoraFramePusher_create(JNIEnv*, jobject, jlong engine) {
  IMediaEngine* media = nullptr;
  auto* rtc = reinterpret_cast<agora::rtc::IRtcEngine*>(engine);
  if (!rtc || rtc->queryInterface(agora::rtc::AGORA_IID_MEDIA_ENGINE, reinterpret_cast<void**>(&media))) return 0;
  return reinterpret_cast<jlong>(media);
}
extern "C" JNIEXPORT jint JNICALL
Java_com_oneplusdream_flutter_1realtime_1video_1effects_AgoraFramePusher_push(JNIEnv* env, jobject, jlong media, jobject buffer, jint width, jint height, jlong timestampNs, jint trackId) {
  auto* ptr = reinterpret_cast<IMediaEngine*>(media);
  void* data = env->GetDirectBufferAddress(buffer);
  if (!ptr || !data) return -1;
  agora::media::base::ExternalVideoFrame frame;
  frame.format = agora::media::base::VIDEO_PIXEL_RGBA;
  // `stride` is the line spacing of the incoming frame. The frame hub publishes
  // tightly packed RGBA rows, so the spacing is 4 bytes per pixel. `cropRight`
  // and friends are the number of pixels *trimmed* from an edge and stay 0
  // here: the frame is delivered whole and needs no cropping.
  frame.buffer = data; frame.stride = width * 4; frame.height = height;
  frame.timestamp = timestampNs / 1000000;
  return ptr->pushVideoFrame(&frame, trackId);
}
extern "C" JNIEXPORT void JNICALL
Java_com_oneplusdream_flutter_1realtime_1video_1effects_AgoraFramePusher_release(JNIEnv*, jobject, jlong media) {
  if (media) reinterpret_cast<IMediaEngine*>(media)->release();
}
