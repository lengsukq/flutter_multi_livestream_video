import 'package:flutter/widgets.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'processed_video_track.dart';
import 'video_effects_track_renderer_native.dart'
    if (dart.library.js_interop) 'video_effects_track_renderer_web.dart'
    as platform;

class VideoEffectsTrackRenderer extends MediaTrackRenderer {
  const VideoEffectsTrackRenderer();

  @override
  Widget buildView(BuildContext context, MediaVideoTrack track) {
    if (track is! ProcessedVideoTrack) {
      return const SizedBox.shrink();
    }
    return platform.buildProcessedVideoView(track);
  }
}
