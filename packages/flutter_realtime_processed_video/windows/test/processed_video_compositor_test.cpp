#include "../include/processed_video_compositor.h"

#include <cassert>
#include <memory>
#include <vector>

using namespace realtime_processed_video;

int main() {
  auto camera_bytes = std::make_shared<const std::vector<std::uint8_t>>(
      std::initializer_list<std::uint8_t>{
          10, 20, 30, 255, 20, 30, 40, 255,
          30, 40, 50, 255, 40, 50, 60, 255});
  const Frame camera{"source", camera_bytes, 2, 2, 8, 100, false};
  const PersonMask person{{1.0f, 0.0f, 1.0f, 0.0f}, 2, 2};
  Frame output;
  BackgroundSettings replace;
  replace.mode = BackgroundMode::replace_image;
  replace.replacement_width = 1;
  replace.replacement_height = 1;
  replace.replacement_bgra = {100, 110, 120, 255};
  assert(Compose(camera, person, replace, &output));
  assert(output.effect_applied);
  assert(output.pixels->at(0) == 10);
  assert(output.pixels->at(4) == 100);
  assert(output.timestamp_ns == 100);
  const auto rgba = PreviewRgba(output);
  assert(rgba != nullptr);
  assert(rgba->at(0) == 30); // camera BGR 10/20/30 -> RGBA 30/20/10
  assert(rgba->at(1) == 20);
  assert(rgba->at(2) == 10);
  assert(rgba->at(4) == 120); // replacement BGR 100/110/120
  assert(rgba->at(5) == 110);
  assert(rgba->at(6) == 100);
  FrameHub hub;
  assert(hub.Activate("source", true));
  assert(!hub.Publish(camera));
  assert(hub.Publish(output));
  auto invalid = replace;
  invalid.replacement_bgra.clear();
  assert(!Compose(camera, person, invalid, &output));
  assert(!Compose(camera, PersonMask{}, replace, &output));
  BackgroundSettings blur;
  blur.mode = BackgroundMode::blur;
  assert(Compose(camera, person, blur, &output));
  assert(output.effect_applied);
  BackgroundSettings none;
  assert(Compose(camera, PersonMask{}, none, &output));
  assert(!output.effect_applied);
  assert(output.pixels->at(0) == camera.pixels->at(0));
}
