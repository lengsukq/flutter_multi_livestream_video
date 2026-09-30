import 'dart:typed_data';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

/// A local image offered by the host application in background controls.
class MediaBackgroundImagePreset {
  MediaBackgroundImagePreset({
    required this.id,
    required this.label,
    required Uint8List imageBytes,
  }) : effect = MediaBackgroundEffect.replaceImage(imageBytes: imageBytes);
  final String id;
  final String label;
  final MediaBackgroundEffect effect;
  Uint8List get imageBytes => effect.imageBytes!;
}
