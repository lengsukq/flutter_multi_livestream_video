/// Realtime data message received from or sent by a participant.
class MediaMessage {
  const MediaMessage({
    required this.participantId,
    required this.message,
    required this.topic,
    required this.timestampMs,
    this.displayName = '',
    this.providerId = '',
    this.metadata = const {},
  });

  /// Sender participant identifier.
  final String participantId;

  /// Sender display name when the provider exposes it.
  final String displayName;

  /// Provider that produced the message, when known.
  final String providerId;

  /// Message text.
  final String message;

  /// Logical channel, `chat` by default.
  final String topic;

  /// Milliseconds since epoch.
  final int timestampMs;

  /// Optional provider-neutral metadata preserved by adapters.
  final Map<String, String> metadata;

  @override
  String toString() => 'MediaMessage($topic, from: $participantId, "$message")';
}
