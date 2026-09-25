enum MediaDataReliability { reliable, unreliable }

/// Provider-neutral realtime data delivery options.
class MediaSendOptions {
  const MediaSendOptions({
    this.topic = 'chat',
    this.targetParticipantIds = const [],
    this.reliability = MediaDataReliability.reliable,
    this.ordered = true,
  });

  final String topic;
  final List<String> targetParticipantIds;
  final MediaDataReliability reliability;
  final bool ordered;
  bool get isBroadcast => targetParticipantIds.isEmpty;
}
