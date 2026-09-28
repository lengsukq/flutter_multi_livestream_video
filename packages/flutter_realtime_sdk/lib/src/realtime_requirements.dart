import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

/// Stable, provider-neutral room features a backend may require from a client.
enum RealtimeCapability {
  publishAudio,
  publishVideo,
  subscribeVideo,
  screenShare,
  chat,
  listParticipants,
  removeParticipants,
  closeRoom;

  static RealtimeCapability? tryParse(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    return switch (normalized) {
      'publish-audio' => publishAudio,
      'publish-video' => publishVideo,
      'subscribe-video' => subscribeVideo,
      'screen-share' => screenShare,
      'chat' => chat,
      'list-participants' => listParticipants,
      'remove-participants' => removeParticipants,
      'close-room' => closeRoom,
      _ => null,
    };
  }
}

class RealtimeCapabilityRequirements {
  const RealtimeCapabilityRequirements(this.values);

  final Set<RealtimeCapability> values;

  factory RealtimeCapabilityRequirements.fromBackend(
    Map<String, dynamic> json,
  ) {
    final raw = json['requiredCapabilities'];
    if (raw == null) return const RealtimeCapabilityRequirements({});
    if (raw is! List) {
      throw const MediaBackendError(
        code: MediaBackendErrorCode.invalidResponse,
        message: 'Backend requiredCapabilities must be an array.',
      );
    }
    final values = <RealtimeCapability>{};
    for (final item in raw) {
      final capability = RealtimeCapability.tryParse(item);
      if (capability == null) {
        throw MediaBackendError(
          code: MediaBackendErrorCode.unsupportedFeature,
          message: 'Backend requires an unknown realtime capability: $item.',
          details: item,
        );
      }
      values.add(capability);
    }
    return RealtimeCapabilityRequirements(Set.unmodifiable(values));
  }
}
