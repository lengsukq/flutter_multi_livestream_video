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
Java_com_oneplusdream_flutter_1realtime_1video_1effects_AgoraFramePusher_push(JNIEnv* env, jobject, jlong media, jobject buffer, jint width, jint height, jlong timestampNs, jint rotationDegrees, jint trackId) {
  auto* ptr = reinterpret_cast<IMediaEngine*>(media);
  void* data = env->GetDirectBufferAddress(buffer);
  if (!ptr || !data || width <= 0 || height <= 0 ||
      env->GetDirectBufferCapacity(buffer) < static_cast<jlong>(width) * height * 4 ||
      (rotationDegrees != 0 && rotationDegrees != 90 &&
       rotationDegrees != 180 && rotationDegrees != 270)) return -1;
  agora::media::base::ExternalVideoFrame frame;
  frame.format = agora::media::base::VIDEO_PIXEL_RGBA;
  // Agora's ExternalVideoFrame stride is measured in pixels, not bytes.
  // Preserve the whole sensor grid and let Agora apply its rotation metadata.
  frame.buffer = data; frame.stride = width; frame.height = height;
  frame.rotation = rotationDegrees;
  frame.timestamp = timestampNs / 1000000;
  return ptr->pushVideoFrame(&frame, trackId);
}
extern "C" JNIEXPORT void JNICALL
Java_com_oneplusdream_flutter_1realtime_1video_1effects_AgoraFramePusher_release(JNIEnv*, jobject, jlong media) {
  if (media) reinterpret_cast<IMediaEngine*>(media)->release();
}
