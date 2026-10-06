import 'package:flutter/widgets.dart';

import 'processed_video_track.dart';

Widget buildProcessedVideoView(
  ProcessedVideoTrack track, {
  BoxFit fit = BoxFit.contain,
}) {
  final textureId = track.source.previewTextureId;
  if (textureId == null) return const SizedBox.shrink();
  return Texture(textureId: textureId);
}
