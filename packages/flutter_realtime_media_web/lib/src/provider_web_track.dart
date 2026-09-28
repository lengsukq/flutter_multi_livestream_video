import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

class ProviderWebVideoTrack extends MediaVideoTrack {
  const ProviderWebVideoTrack({
    required this.providerId,
    required this.sessionId,
    required this.id,
    required this.participantId,
    required this.isLocal,
    required this.isScreenShare,
    this.width = 0,
    this.height = 0,
  });

  final String providerId;
  final String sessionId;

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
