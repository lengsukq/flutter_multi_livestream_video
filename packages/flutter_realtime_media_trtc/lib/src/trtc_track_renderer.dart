import 'package:flutter/widgets.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:tencent_rtc_sdk/trtc_cloud_video_view.dart';

import 'trtc_media_track.dart';

/// Renders a TRTC local camera preview or a subscribed remote camera stream.
class TrtcTrackRenderer extends MediaTrackRenderer {
  const TrtcTrackRenderer();

  @override
  Widget buildView(BuildContext context, MediaVideoTrack track) {
    if (track is! TrtcMediaVideoTrack) {
      throw ArgumentError.value(
        track,
        'track',
        'TrtcTrackRenderer requires a TrtcMediaVideoTrack.',
      );
    }
    return _TrtcVideoSurface(key: ValueKey(track.id), track: track);
  }
}

class _TrtcVideoSurface extends StatefulWidget {
  const _TrtcVideoSurface({super.key, required this.track});

  final TrtcMediaVideoTrack track;

  @override
  State<_TrtcVideoSurface> createState() => _TrtcVideoSurfaceState();
}

class _TrtcVideoSurfaceState extends State<_TrtcVideoSurface> {
  int? _viewId;

  @override
  void didUpdateWidget(covariant _TrtcVideoSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.id != widget.track.id) _bindView();
  }

  void _bindView() {
    final viewId = _viewId;
    if (viewId == null) return;
    widget.track.startRendering(viewId);
  }

  @override
  void dispose() {
    final viewId = _viewId;
    if (viewId != null) widget.track.stopRendering();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TRTCCloudVideoView(
    onViewCreated: (viewId) {
      _viewId = viewId;
      _bindView();
    },
  );
}
