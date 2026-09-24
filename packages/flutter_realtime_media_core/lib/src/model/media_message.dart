/// Realtime data message received from or sent by a participant.
class MediaMessage {
  const MediaMessage({
    required this.participantId,
    required this.message,
    required this.topic,
    required this.timestampMs,
    this.displayName = '',
  });

  /// Sender participant identifier.
  final String participantId;

  /// Sender display name when the provider exposes it.
  final String displayName;

  /// Message text.
  final String message;

  /// Logical channel, `chat` by default.
  final String topic;

  /// Milliseconds since epoch.
  final int timestampMs;

  @override
  String toString() => 'MediaMessage($topic, from: $participantId, "$message")';
}
