class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.userId,
    required this.message,
    required this.timestamp,
    this.displayName = '',
    this.attributes = const {},
  });

  final String id;
  final String userId;
  final String displayName;
  final String message;
  final DateTime timestamp;
  final Map<String, String> attributes;
}
