import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

class ProviderWebJoinInfo extends MediaJoinInfo {
  ProviderWebJoinInfo({
    required super.providerId,
    required super.roomCode,
    required super.participantId,
    required super.role,
    required super.displayName,
    required Map<String, Object?> backendPayload,
  }) : super(payload: backendPayload);
}
