import 'package:agora_rtc_engine/agora_rtc_engine.dart' as agora;
import 'package:flutter/widgets.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'agora_media_track.dart';

/// Renders an Agora camera track through AgoraVideoView.
class AgoraTrackRenderer extends MediaTrackRenderer {
  const AgoraTrackRenderer();

  @override
  Widget buildView(BuildContext context, MediaVideoTrack track) =>
      buildViewWithFit(context, track);

  @override
  Widget buildViewWithFit(
    BuildContext context,
    MediaVideoTrack track, {
    BoxFit fit = BoxFit.cover,
  }) {
    if (track is! AgoraMediaVideoTrack) {
      throw ArgumentError.value(
        track,
        'track',
        'AgoraTrackRenderer requires an AgoraMediaVideoTrack.',
      );
    }
    final renderMode = fit == BoxFit.contain
        ? agora.RenderModeType.renderModeFit
        : agora.RenderModeType.renderModeHidden;

    if (track.isLocal) {
      return agora.AgoraVideoView(
        controller: agora.VideoViewController(
          rtcEngine: track.engine,
          canvas: agora.VideoCanvas(uid: 0, renderMode: renderMode),
        ),
      );
    }

    return agora.AgoraVideoView(
      controller: agora.VideoViewController.remote(
        rtcEngine: track.engine,
        canvas: agora.VideoCanvas(uid: track.uid, renderMode: renderMode),
        connection: agora.RtcConnection(channelId: track.channelId),
      ),
    );
  }
}
