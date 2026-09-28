import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'ivs_media_track.dart';

class IvsTrackRenderer extends MediaTrackRenderer {
  const IvsTrackRenderer();

  static const String viewType =
      'com.oneplusdream.flutter_realtime_media_ivs/video';

  @override
  Widget buildView(BuildContext context, MediaVideoTrack track) {
    if (track is! IvsMediaVideoTrack) {
      throw ArgumentError.value(
        track,
        'track',
        'IvsTrackRenderer requires an IvsMediaVideoTrack.',
      );
    }
    final params = <String, Object?>{
      'userId': track.userId,
      'isLocal': track.isLocal,
      'generation': track.generation,
    };
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidView(
        viewType: viewType,
        creationParams: params,
        creationParamsCodec: const StandardMessageCodec(),
      ),
      TargetPlatform.iOS => UiKitView(
        viewType: viewType,
        creationParams: params,
        creationParamsCodec: const StandardMessageCodec(),
      ),
      _ => const SizedBox.expand(),
    };
  }
}
