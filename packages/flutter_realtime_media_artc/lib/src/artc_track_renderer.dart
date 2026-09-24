import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'artc_media_track.dart';

/// Renders an ARTC local or remote camera track through a native platform view.
class ArtcTrackRenderer extends MediaTrackRenderer {
  const ArtcTrackRenderer();

  static const String viewType =
      'com.oneplusdream.flutter_realtime_media_artc/video';

  @override
  Widget buildView(BuildContext context, MediaVideoTrack track) {
    if (track is! ArtcMediaVideoTrack) {
      throw ArgumentError.value(
        track,
        'track',
        'ArtcTrackRenderer requires an ArtcMediaVideoTrack.',
      );
    }
    final creationParams = <String, Object?>{
      'userId': track.userId,
      'isLocal': track.isLocal,
      'generation': track.generation,
    };
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidView(
        viewType: viewType,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
      ),
      TargetPlatform.iOS => UiKitView(
        viewType: viewType,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
      ),
      _ => const SizedBox.expand(),
    };
  }
}
