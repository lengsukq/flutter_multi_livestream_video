import 'package:flutter/widgets.dart';
import 'package:flutter_multi_livestream_video_core/flutter_multi_livestream_video_core.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import 'livekit_media_track.dart';

/// Renders a core video track backed by a LiveKit [lk.VideoTrack].
class LiveKitTrackRenderer extends MediaTrackRenderer {
  const LiveKitTrackRenderer();

  @override
  Widget buildView(BuildContext context, MediaVideoTrack track) {
    if (track is! LiveKitMediaVideoTrack) {
      throw ArgumentError.value(
        track,
        'track',
        'LiveKitTrackRenderer requires a LiveKitMediaVideoTrack.',
      );
    }
    return lk.VideoTrackRenderer(
      track.liveKitTrack,
      fit: lk.VideoViewFit.cover,
    );
  }
}
