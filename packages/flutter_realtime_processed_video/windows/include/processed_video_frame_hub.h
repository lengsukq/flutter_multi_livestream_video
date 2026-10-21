#pragma once

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <memory>
#include <mutex>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

namespace realtime_processed_video {

// Frames are BGRA, top-down, with a shared immutable backing buffer.
// No frame bytes pass through Dart channels. Consumers may retain pixels
// asynchronously by retaining the shared_ptr.
struct Frame {
  std::string source_id;
  std::shared_ptr<const std::vector<std::uint8_t>> pixels;
  std::uint32_t width = 0;
  std::uint32_t height = 0;
  std::uint32_t stride = 0;
  std::uint64_t timestamp_ns = 0;
  bool effect_applied = false;

  bool IsValid() const {
    return !source_id.empty() && pixels && width && height &&
           static_cast<std::uint64_t>(stride) >=
               static_cast<std::uint64_t>(width) * 4 &&
           pixels->size() >=
               static_cast<std::uint64_t>(stride) * height;
  }
};

class FrameSink {
 public:
  virtual ~FrameSink() = default;
  virtual void OnFrame(const Frame& frame) = 0;
};

// A source may publish unprocessed camera frames only when no virtual
// background is selected. When the effect is required, a failed segmentation
// step must never cause raw camera pixels to be delivered to a provider.
class FrameHub final {
 public:
  bool Contains(const std::string& source_id) {
    std::lock_guard<std::mutex> guard(lock_);
    return sources_.find(source_id) != sources_.end();
  }
  bool Activate(const std::string& source_id, bool require_effect) {
    if (source_id.empty()) return false;
    std::lock_guard<std::mutex> guard(lock_);
    return sources_.emplace(source_id, Source{require_effect, {}}).second;
  }

  bool SetEffectRequired(const std::string& source_id, bool required) {
    std::lock_guard<std::mutex> guard(lock_);
    auto it = sources_.find(source_id);
    if (it == sources_.end()) return false;
    it->second.require_effect = required;
    return true;
  }

  bool Subscribe(const std::string& source_id,
                 const std::shared_ptr<FrameSink>& sink) {
    if (!sink) return false;
    std::lock_guard<std::mutex> guard(lock_);
    auto it = sources_.find(source_id);
    if (it == sources_.end()) return false;
    auto& listeners = it->second.sinks;
    listeners.erase(
        std::remove_if(listeners.begin(), listeners.end(),
                       [](const std::weak_ptr<FrameSink>& item) {
                         return item.expired();
                       }),
        listeners.end());
    listeners.emplace_back(sink);
    return true;
  }

  void Clear(const std::string& source_id) {
    std::lock_guard<std::mutex> guard(lock_);
    sources_.erase(source_id);
  }

  // Snapshot listeners under the lock; never call third-party SDK code while
  // holding the registry mutex. The caller owns the frame until all
  // synchronous callbacks return.
  bool Publish(const Frame& frame) {
    if (!frame.IsValid()) return false;
    std::vector<std::shared_ptr<FrameSink>> listeners;
    {
      std::lock_guard<std::mutex> guard(lock_);
      const auto it = sources_.find(frame.source_id);
      if (it == sources_.end() ||
          (it->second.require_effect && !frame.effect_applied)) {
        return false;
      }
      for (const auto& weak : it->second.sinks) {
        if (auto sink = weak.lock()) listeners.emplace_back(std::move(sink));
      }
    }
    for (const auto& sink : listeners) sink->OnFrame(frame);
    return true;
  }

 private:
  struct Source {
    bool require_effect;
    std::vector<std::weak_ptr<FrameSink>> sinks;
  };
  std::mutex lock_;
  std::unordered_map<std::string, Source> sources_;
};

}  // namespace realtime_processed_video
