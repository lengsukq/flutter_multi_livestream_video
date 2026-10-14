import 'package:flutter_realtime_foundation/flutter_realtime_foundation.dart';

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.userId,
    required this.message,
    required this.timestamp,
    this.displayName = '',
    this.topic = 'chat',
    this.type = 'message',
    this.providerId,
    String? avatarUrl,
    Map<String, String> attributes = const {},
  }) : attributes = Map.unmodifiable({
         ...attributes,
         if (avatarUrl != null) 'avatarUrl': avatarUrl,
       });

  final String id;
  final String userId;
  final String displayName;
  String? get avatarUrl => RealtimeAvatarUrl.tryParse(attributes['avatarUrl']);
  final String message;
  final DateTime timestamp;
  final String topic;
  final String type;
  final String? providerId;
  final Map<String, String> attributes;
}
