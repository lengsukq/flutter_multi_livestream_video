#pragma once
#include <algorithm>
#include <cstdint>
#include <vector>

namespace realtime_processed_video {

inline std::uint8_t ClampYuv(int value) {
  return static_cast<std::uint8_t>(std::clamp(value, 0, 255));
}

// Windows TRTC only accepts contiguous I420, unlike macOS which accepts BGRA.
// Uses BT.601 limited-range conversion; rejects odd dimensions/invalid strides.
inline bool BgraToI420(const std::uint8_t* bgra, std::uint32_t width,
                      std::uint32_t height, std::uint32_t stride,
                      std::vector<std::uint8_t>* output) {
  if (!output || !bgra || width == 0 || height == 0 ||
      width > 4096 || height > 4096 ||
      (width & 1) || (height & 1) ||
      static_cast<std::uint64_t>(stride) < static_cast<std::uint64_t>(width) * 4)
    return false;
  const auto plane = static_cast<std::size_t>(width) * height;
  output->resize(plane + plane / 2);
  auto* yuv = output->data();
  auto* u = yuv + plane;
  auto* v = u + plane / 4;
  for (std::uint32_t row = 0; row < height; ++row) {
    for (std::uint32_t col = 0; col < width; ++col) {
      const auto* p = bgra + static_cast<std::size_t>(row) * stride + col * 4;
      const int b = p[0], g = p[1], r = p[2];
      yuv[static_cast<std::size_t>(row) * width + col] =
          ClampYuv(((66 * r + 129 * g + 25 * b + 128) >> 8) + 16);
    }
  }
  for (std::uint32_t row = 0; row < height; row += 2) {
    for (std::uint32_t col = 0; col < width; col += 2) {
      int r = 0, g = 0, b = 0;
      for (std::uint32_t dy = 0; dy < 2; ++dy)
        for (std::uint32_t dx = 0; dx < 2; ++dx) {
          const auto* p = bgra + static_cast<std::size_t>(row + dy) * stride +
                          (col + dx) * 4;
          b += p[0]; g += p[1]; r += p[2];
        }
      r = (r + 2) / 4; g = (g + 2) / 4; b = (b + 2) / 4;
      const auto uv = static_cast<std::size_t>(row / 2) * (width / 2) + col / 2;
      u[uv] = ClampYuv(((-38 * r - 74 * g + 112 * b + 128) >> 8) + 128);
      v[uv] = ClampYuv(((112 * r - 94 * g - 18 * b + 128) >> 8) + 128);
    }
  }
  return true;
}
}  // namespace realtime_processed_video
