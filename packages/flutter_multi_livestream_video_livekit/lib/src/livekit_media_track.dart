import 'package:flutter_multi_livestream_video_core/flutter_multi_livestream_video_core.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

/// Provider-specific track handle carried behind the core track abstraction.
class LiveKitMediaVideoTrack extends MediaVideoTrack {
  const LiveKitMediaVideoTrack({
    required this.liveKitTrack,
    required this.id,
    required this.participantId,
    required this.isLocal,
    required this.isScreenShare,
    this.width = 0,
    this.height = 0,
  });

  final lk.VideoTrack liveKitTrack;

  @override
  final String id;

  @override
  final String participantId;

  @override
  final bool isLocal;

  @override
  final bool isScreenShare;

  @override
  final int width;

  @override
  final int height;
}
