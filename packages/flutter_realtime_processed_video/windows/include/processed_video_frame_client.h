#pragma once

#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <string>
#include "processed_video_frame_api.h"

namespace realtime_processed_video {

// Resolves the shared effects plugin in both modular and aggregated SDK apps.
// No vendor-specific module is permitted to fabricate a second frame hub.
class FrameClient {
 public:
  bool Resolve() {
    const wchar_t* dlls[] = {
        L"flutter_realtime_video_effects_plugin.dll",
        L"flutter_realtime_sdk_plugin.dll"};
    for (const wchar_t* dll : dlls) {
      HMODULE handle = GetModuleHandleW(dll);
      if (!handle) continue;
      subscribe_ = reinterpret_cast<RealtimeProcessedSubscribe>(
          GetProcAddress(handle, "RealtimeProcessedVideoSubscribe"));
      unsubscribe_ = reinterpret_cast<RealtimeProcessedUnsubscribe>(
          GetProcAddress(handle, "RealtimeProcessedVideoUnsubscribe"));
      report_ = reinterpret_cast<RealtimeProcessedReportFailure>(
          GetProcAddress(handle, "RealtimeProcessedVideoReportFailure"));
      if (subscribe_ && unsubscribe_ && report_) return true;
    }
    return false;
  }
  void* Subscribe(const std::string& source, void* context,
                  RealtimeProcessedOnFrame callback) const {
    return subscribe_ ? subscribe_(source.c_str(), context, callback) : nullptr;
  }
  void Unsubscribe(void* token) const {
    if (token && unsubscribe_) unsubscribe_(token);
  }
  void Report(const std::string& source, const char* message) const {
    if (report_) report_(source.c_str(), message);
  }

 private:
  RealtimeProcessedSubscribe subscribe_ = nullptr;
  RealtimeProcessedUnsubscribe unsubscribe_ = nullptr;
  RealtimeProcessedReportFailure report_ = nullptr;
};

}  // namespace realtime_processed_video
