import 'package:flutter/widgets.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'processed_video_track_renderer_native.dart'
    if (dart.library.js_interop) 'processed_video_track_renderer_web.dart'
    as platform;

class ProcessedVideoTrackRenderer extends MediaTrackRenderer {
  const ProcessedVideoTrackRenderer();

  @override
  Widget buildView(BuildContext context, MediaVideoTrack track) =>
      buildViewWithFit(context, track);

  @override
  Widget buildViewWithFit(
    BuildContext context,
    MediaVideoTrack track, {
    BoxFit fit = BoxFit.contain,
  }) {
    if (track is! ProcessedVideoTrack) {
      return const SizedBox.shrink();
    }
    return platform.buildProcessedVideoView(track, fit: fit);
  }
}
