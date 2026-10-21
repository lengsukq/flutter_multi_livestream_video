#pragma once

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>

#include "processed_video_compositor.h"

#if defined(REALTIME_VIDEO_EFFECTS_ONNX)
#include <onnxruntime_cxx_api.h>
#endif

namespace realtime_video_effects {

// PPHumanSeg (OpenCV Zoo, Apache-2.0), 192x192 NCHW float RGB.
// Inference is not available without both ONNX Runtime and an on-disk model.
// In that case this class returns false; it must never generate a fake mask.
class PersonSegmenter final {
 public:
  static constexpr int kWidth = 192;
  static constexpr int kHeight = 192;

  bool Open(const std::wstring& model) {
#if defined(REALTIME_VIDEO_EFFECTS_ONNX)
    try {
      Ort::SessionOptions options;
      options.SetIntraOpNumThreads(2);
      options.SetGraphOptimizationLevel(GraphOptimizationLevel::ORT_ENABLE_ALL);
      session_ = std::make_unique<Ort::Session>(environment_, model.c_str(),
                                               options);
      Ort::AllocatorWithDefaultOptions allocator;
      const auto input = session_->GetInputNameAllocated(0, allocator);
      const auto output = session_->GetOutputNameAllocated(0, allocator);
      input_name_ = input.get() ? input.get() : "";
      output_name_ = output.get() ? output.get() : "";
      return !input_name_.empty() && !output_name_.empty();
    } catch (const Ort::Exception&) {
      session_.reset();
      return false;
    }
#else
    (void)model;
    return false;
#endif
  }

  bool Ready() const {
#if defined(REALTIME_VIDEO_EFFECTS_ONNX)
    return session_ != nullptr;
#else
    return false;
#endif
  }

  bool Infer(const realtime_processed_video::Frame& frame,
             realtime_processed_video::PersonMask* mask) {
#if defined(REALTIME_VIDEO_EFFECTS_ONNX)
    if (!Ready() || !mask || !frame.IsValid()) return false;
    constexpr std::size_t plane = kWidth * kHeight;
    std::vector<float> input(plane * 3);
    for (int y = 0; y < kHeight; ++y) {
      for (int x = 0; x < kWidth; ++x) {
        const auto px = std::min(frame.width - 1, static_cast<std::uint32_t>(
            (static_cast<std::uint64_t>(x) * frame.width) / kWidth));
        const auto py = std::min(frame.height - 1, static_cast<std::uint32_t>(
            (static_cast<std::uint64_t>(y) * frame.height) / kHeight));
        const auto* bgra = frame.pixels->data() +
            static_cast<std::size_t>(py) * frame.stride + px * 4;
        const auto at = static_cast<std::size_t>(y) * kWidth + x;
        // OpenCV reference input is RGB, normalized with mean/std = 0.5.
        input[at] = (static_cast<float>(bgra[2]) / 255.0f - 0.5f) / 0.5f;
        input[plane + at] = (static_cast<float>(bgra[1]) / 255.0f - 0.5f) / 0.5f;
        input[plane * 2 + at] =
            (static_cast<float>(bgra[0]) / 255.0f - 0.5f) / 0.5f;
      }
    }
    try {
      const std::array<std::int64_t, 4> shape{1, 3, kHeight, kWidth};
      auto memory = Ort::MemoryInfo::CreateCpu(OrtArenaAllocator, OrtMemTypeDefault);
      auto tensor = Ort::Value::CreateTensor<float>(
          memory, input.data(), input.size(), shape.data(), shape.size());
      const char* input_names[]{input_name_.c_str()};
      const char* output_names[]{output_name_.c_str()};
      auto result = session_->Run(Ort::RunOptions{nullptr}, input_names,
                                  &tensor, 1, output_names, 1);
      if (result.size() != 1 || !result.front().IsTensor()) return false;
      const auto dimensions = result.front().GetTensorTypeAndShapeInfo().GetShape();
      // Reject unknown layouts or labels. Model output is [1, 2, 192, 192].
      if (dimensions.size() != 4 || dimensions[0] != 1 ||
          dimensions[1] != 2 || dimensions[2] != kHeight ||
          dimensions[3] != kWidth) return false;
      const float* logits = result.front().GetTensorData<float>();
      realtime_processed_video::PersonMask next;
      next.width = kWidth;
      next.height = kHeight;
      next.alpha.resize(plane);
      for (std::size_t i = 0; i < plane; ++i) {
        const float background = logits[i];
        const float foreground = logits[plane + i];
        if (!std::isfinite(background) || !std::isfinite(foreground))
          return false;
        const float difference = std::clamp(foreground - background, -30.0f, 30.0f);
        next.alpha[i] = 1.0f / (1.0f + std::exp(-difference));
      }
      *mask = std::move(next);
      return true;
    } catch (const Ort::Exception&) {
      return false;
    }
#else
    (void)frame;
    (void)mask;
    return false;
#endif
  }

 private:
#if defined(REALTIME_VIDEO_EFFECTS_ONNX)
  Ort::Env environment_{ORT_LOGGING_LEVEL_WARNING, "flutter_video_effects"};
  std::unique_ptr<Ort::Session> session_;
  std::string input_name_;
  std::string output_name_;
#endif
};

}  // namespace realtime_video_effects
