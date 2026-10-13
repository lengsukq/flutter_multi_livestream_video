import 'package:flutter/widgets.dart';

import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

Widget buildProcessedVideoView(
  ProcessedVideoTrack track, {
  BoxFit fit = BoxFit.contain,
}) {
  final textureId = track.source.previewTextureId;
  if (textureId == null) return const SizedBox.shrink();
  return Texture(textureId: textureId);
}
