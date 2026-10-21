#include "../include/processed_video_frame_hub.h"

#include <cassert>
#include <memory>
#include <vector>

using realtime_processed_video::Frame;
using realtime_processed_video::FrameHub;
using realtime_processed_video::FrameSink;

struct Receiver final : FrameSink {
  int received = 0;
  void OnFrame(const Frame&) override { ++received; }
};

int main() {
  FrameHub hub;
  auto receiver = std::make_shared<Receiver>();
  auto bytes = std::make_shared<const std::vector<std::uint8_t>>(
      32, std::uint8_t{0});
  const Frame raw{"camera", bytes, 2, 4, 8, 123, false};
  const Frame protected_frame{"camera", bytes, 2, 4, 8, 124, true};
  assert(hub.Activate("camera", true));
  assert(!hub.Activate("camera", true));
  assert(hub.Subscribe("camera", receiver));
  assert(!hub.Publish(raw)); // Fail closed: camera must stay protected.
  assert(hub.Publish(protected_frame));
  assert(receiver->received == 1);
  assert(hub.SetEffectRequired("camera", false));
  assert(hub.Publish(raw));
  assert(receiver->received == 2);
  hub.Clear("camera");
  assert(!hub.Publish(raw));
  assert(receiver->received == 2);
  assert(!hub.Publish(Frame{}));
}
