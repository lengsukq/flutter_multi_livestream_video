import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

/// Video track rendered by Tencent TRTC.
class TrtcMediaVideoTrack extends MediaVideoTrack {
  const TrtcMediaVideoTrack({
    required this.userId,
    required this.local,
    required this.startRendering,
    required this.stopRendering,
    this.screenShare = false,
    this.generation = 0,
  });

  /// Provider user id whose camera stream this track represents.
  final String userId;

  final bool local;
  final bool screenShare;

  /// Starts the provider stream in the platform view id supplied by TRTC.
  final void Function(int viewId) startRendering;

  /// Stops the local view binding or remote subscription when its tile closes.
  final void Function() stopRendering;

  /// Changes when the underlying TRTC room is re-entered after renewal.
  final int generation;

  @override
  String get id =>
      'trtc:$userId:${screenShare ? 'screen' : 'camera'}:$generation';

  @override
  String get participantId => userId;

  @override
  bool get isLocal => local;

  @override
  bool get isScreenShare => screenShare;

  @override
  int get width => 0;

  @override
  int get height => 0;
}
