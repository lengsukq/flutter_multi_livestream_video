#include "../include/processed_video_i420.h"
#include <cassert>
#include <vector>

int main() {
  using realtime_processed_video::BgraToI420;
  // Two black and two white pixels, 2x2.
  const std::uint8_t frame[16] = {
      0, 0, 0, 255, 255, 255, 255, 255,
      0, 0, 0, 255, 255, 255, 255, 255};
  std::vector<std::uint8_t> result;
  assert(BgraToI420(frame, 2, 2, 8, &result));
  assert(result.size() == 6);
  assert(result[0] == 16 && result[1] == 235);
  assert(result[2] == 16 && result[3] == 235);
  assert(result[4] == 128 && result[5] == 128);
  assert(!BgraToI420(frame, 3, 2, 8, &result));
  assert(!BgraToI420(frame, 2, 2, 4, &result));
  assert(!BgraToI420(nullptr, 2, 2, 8, &result));
}
