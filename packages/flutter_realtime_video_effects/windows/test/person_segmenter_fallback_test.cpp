#include "../pphumanseg_inference.h"

#include <cassert>
#include <cstdint>
#include <memory>
#include <vector>

// Portable safety regression: without the required ONNX Runtime the
// segmenter must reject inference and never invent a foreground mask.
int main() {
  realtime_video_effects::PersonSegmenter segmenter;
  assert(!segmenter.Ready());
  assert(!segmenter.Open(L"nonexistent-model.onnx"));
  auto pixels = std::make_shared<const std::vector<std::uint8_t>>(
      4 * 4 * 4, 255);
  realtime_processed_video::Frame camera{
      "camera", pixels, 4, 4, 16, 10, false};
  realtime_processed_video::PersonMask mask;
  assert(!segmenter.Infer(camera, &mask));
  assert(!mask.Valid());
}
