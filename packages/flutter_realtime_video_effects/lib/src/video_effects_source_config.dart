import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

class VideoEffectsSourceConfig {
  const VideoEffectsSourceConfig({
    this.width = 1280,
    this.height = 720,
    this.frameRate = 24,
    this.cameraDeviceId,
    this.effect = const MediaBackgroundEffect.none(),
  });

  final int width;
  final int height;
  final int frameRate;
  final String? cameraDeviceId;
  final MediaBackgroundEffect effect;

  void validate() {
    if (width < 1 ||
        height < 1 ||
        width > 4096 ||
        height > 4096 ||
        frameRate < 1 ||
        frameRate > 60) {
      throw const MediaError(
        code: MediaErrorCode.invalidArgument,
        message: 'Video dimensions must be 1–4096 and frame rate 1–60.',
      );
    }
  }

  Map<String, Object?> toJson() => {
    'width': width,
    'height': height,
    'frameRate': frameRate,
    'cameraDeviceId': cameraDeviceId,
    'effect': effect.toJson(),
  };
}
