class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.userId,
    required this.message,
    required this.timestamp,
    this.displayName = '',
    this.topic = 'chat',
    this.type = 'message',
    this.providerId,
    this.attributes = const {},
  });

  final String id;
  final String userId;
  final String displayName;
  final String message;
  final DateTime timestamp;
  final String topic;
  final String type;
  final String? providerId;
  final Map<String, String> attributes;
}
