#pragma once

#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <mfapi.h>
#include <mferror.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <wrl/client.h>

#include <atomic>
#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <functional>
#include <memory>
#include <string>
#include <thread>
#include <utility>
#include <vector>

#include "processed_video_frame_hub.h"

namespace realtime_video_effects {

using Microsoft::WRL::ComPtr;

struct Camera {
  std::wstring id;
  std::wstring name;
};

inline std::vector<Camera> FindCameras() {
  std::vector<Camera> out;
  const auto init = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  const bool uninit = SUCCEEDED(init);
  if (FAILED(init) && init != RPC_E_CHANGED_MODE) return out;
  if (FAILED(MFStartup(MF_VERSION, MFSTARTUP_LITE))) {
    if (uninit) CoUninitialize();
    return out;
  }
  ComPtr<IMFAttributes> attributes;
  if (SUCCEEDED(MFCreateAttributes(&attributes, 1)) &&
      SUCCEEDED(attributes->SetGUID(
          MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE,
          MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_GUID))) {
    IMFActivate** devices = nullptr;
    UINT32 count = 0;
    if (SUCCEEDED(MFEnumDeviceSources(attributes.Get(), &devices, &count))) {
      for (UINT32 i = 0; i < count; ++i) {
        wchar_t* name = nullptr;
        wchar_t* link = nullptr;
        UINT32 size = 0;
        devices[i]->GetAllocatedString(
            MF_DEVSOURCE_ATTRIBUTE_FRIENDLY_NAME, &name, &size);
        devices[i]->GetAllocatedString(
            MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_SYMBOLIC_LINK,
            &link, &size);
        if (name && link) out.push_back({link, name});
        CoTaskMemFree(name);
        CoTaskMemFree(link);
        devices[i]->Release();
      }
      CoTaskMemFree(devices);
    }
  }
  MFShutdown();
  if (uninit) CoUninitialize();
  return out;
}

// Owns the Media Foundation SourceReader and camera on a single MTA thread.
// RGB32 is treated as little-endian BGRA; IMF2DBuffer preserves signed stride.
class CameraCapture final {
 public:
  using Callback = std::function<void(const realtime_processed_video::Frame&)>;
  using Failure = std::function<void(const std::string&)>;
  CameraCapture() = default;
  ~CameraCapture() { Stop(); }
  CameraCapture(const CameraCapture&) = delete;
  CameraCapture& operator=(const CameraCapture&) = delete;

  void Start(std::string source_id, std::wstring device, Callback frame,
             Failure fail) {
    Stop();
    running_.store(true);
    worker_ = std::thread([this, source_id = std::move(source_id),
                           device = std::move(device),
                           frame = std::move(frame),
                           fail = std::move(fail)]() {
      if (FAILED(CoInitializeEx(nullptr, COINIT_MULTITHREADED))) {
        fail("mf.com.initialize");
        return;
      }
      if (FAILED(MFStartup(MF_VERSION, MFSTARTUP_LITE))) {
        CoUninitialize();
        fail("mf.startup");
        return;
      }
      {
        ComPtr<IMFAttributes> attributes;
        IMFActivate** devices = nullptr;
        UINT32 count = 0;
        bool opened = false;
        if (SUCCEEDED(MFCreateAttributes(&attributes, 1)) &&
            SUCCEEDED(attributes->SetGUID(
                MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE,
                MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_GUID)) &&
            SUCCEEDED(MFEnumDeviceSources(attributes.Get(), &devices, &count))) {
          for (UINT32 i = 0; i < count; ++i) {
            wchar_t* id = nullptr;
            UINT32 count_chars = 0;
            devices[i]->GetAllocatedString(
                MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_SYMBOLIC_LINK,
                &id, &count_chars);
            const bool selected = id && (device.empty() || device == id);
            CoTaskMemFree(id);
            if (selected && !opened) {
              ComPtr<IMFMediaSource> media;
              if (SUCCEEDED(devices[i]->ActivateObject(IID_PPV_ARGS(&media)))) {
                opened = OpenReader(media.Get(), source_id, frame);
              }
            }
            devices[i]->Release();
          }
          CoTaskMemFree(devices);
        }
        if (!opened && running_.load()) fail("mf.camera.unavailable");
      }
      MFShutdown();
      CoUninitialize();
    });
  }

  void Stop() {
    running_.store(false);
    if (worker_.joinable()) worker_.join();
  }

 private:
  bool OpenReader(IMFMediaSource* source, const std::string& id,
                  const Callback& callback) {
    ComPtr<IMFAttributes> reader_settings;
    if (FAILED(MFCreateAttributes(&reader_settings, 1))) return false;
    reader_settings->SetUINT32(MF_SOURCE_READER_ENABLE_VIDEO_PROCESSING, TRUE);
    ComPtr<IMFSourceReader> reader;
    if (FAILED(MFCreateSourceReaderFromMediaSource(source, reader_settings.Get(),
                                                  &reader))) return false;
    ComPtr<IMFMediaType> type;
    if (FAILED(MFCreateMediaType(&type)) ||
        FAILED(type->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video)) ||
        FAILED(type->SetGUID(MF_MT_SUBTYPE, MFVideoFormat_RGB32)) ||
        FAILED(reader->SetCurrentMediaType(
            MF_SOURCE_READER_FIRST_VIDEO_STREAM, nullptr, type.Get())))
      return false;
    ComPtr<IMFMediaType> current;
    UINT32 width = 0, height = 0;
    if (FAILED(reader->GetCurrentMediaType(
            MF_SOURCE_READER_FIRST_VIDEO_STREAM, &current)) ||
        FAILED(MFGetAttributeSize(current.Get(), MF_MT_FRAME_SIZE,
                                  &width, &height)) ||
        width == 0 || height == 0 || width > 4096 || height > 4096)
      return false;
    while (running_.load()) {
      DWORD index = 0, flags = 0;
      LONGLONG timestamp = 0;
      ComPtr<IMFSample> sample;
      if (FAILED(reader->ReadSample(
              MF_SOURCE_READER_FIRST_VIDEO_STREAM, 0, &index,
              &flags, &timestamp, &sample))) return false;
      if (flags & (MF_SOURCE_READERF_ENDOFSTREAM | MF_SOURCE_READERF_ERROR))
        return false;
      if (!sample || !running_.load()) continue;
      ComPtr<IMFMediaBuffer> buffer;
      if (FAILED(sample->ConvertToContiguousBuffer(&buffer))) continue;
      ComPtr<IMF2DBuffer> two_d;
      auto bgra = std::make_shared<std::vector<std::uint8_t>>(
          static_cast<std::size_t>(width) * height * 4);
      bool copied = false;
      if (SUCCEEDED(buffer.As(&two_d))) {
        BYTE* bytes = nullptr;
        LONG stride = 0;
        if (SUCCEEDED(two_d->Lock2D(&bytes, &stride))) {
          if (bytes && (stride >= static_cast<LONG>(width * 4) ||
                        stride <= -static_cast<LONG>(width * 4))) {
            for (UINT32 y = 0; y < height; ++y) {
              const BYTE* row = bytes +
                  static_cast<std::ptrdiff_t>(y) * stride;
              memcpy(bgra->data() + static_cast<std::size_t>(y) * width * 4,
                     row, static_cast<std::size_t>(width) * 4);
            }
            copied = true;
          }
          two_d->Unlock2D();
        }
      } else {
        BYTE* bytes = nullptr;
        DWORD max_length = 0, length = 0;
        if (SUCCEEDED(buffer->Lock(&bytes, &max_length, &length))) {
          const auto needed = static_cast<std::size_t>(width) * height * 4;
          if (bytes && length >= needed) {
            memcpy(bgra->data(), bytes, needed);
            copied = true;
          }
          buffer->Unlock();
        }
      }
      if (copied) {
        callback(realtime_processed_video::Frame{
            id, bgra, width, height, width * 4,
            static_cast<std::uint64_t>(std::max<LONGLONG>(timestamp, 0)) *
                100, false});
      }
    }
    return true;
  }

  std::atomic<bool> running_{false};
  std::thread worker_;
};

}  // namespace realtime_video_effects
