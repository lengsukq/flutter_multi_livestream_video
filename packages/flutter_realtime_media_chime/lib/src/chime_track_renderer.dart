import 'package:flutter/widgets.dart';
import 'package:flutter_aws_chime/flutter_aws_chime.dart' as chime;
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'chime_media_track.dart';

/// Renders a Chime tile through the existing native PlatformView implementation.
class ChimeTrackRenderer extends MediaTrackRenderer {
  const ChimeTrackRenderer();

  @override
  Widget buildView(BuildContext context, MediaVideoTrack track) {
    if (track is! ChimeMediaVideoTrack) {
      throw ArgumentError.value(
        track,
        'track',
        'ChimeTrackRenderer requires a ChimeMediaVideoTrack.',
      );
    }
    return chime.MeetingVideoTileView(tile: track.tile);
  }
}
