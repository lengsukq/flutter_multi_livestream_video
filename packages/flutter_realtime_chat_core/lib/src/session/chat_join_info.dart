import '../model/chat_role.dart';

class ChatJoinInfo {
  const ChatJoinInfo({
    required this.providerId,
    required this.roomCode,
    required this.participantId,
    required this.userId,
    required this.displayName,
    required this.role,
    required this.json,
  });

  final String providerId;
  final String roomCode;
  final String participantId;
  final String userId;
  final String displayName;
  final ChatRole role;
  final Map<String, dynamic> json;
}

typedef ChatCredentialProvider = Future<ChatJoinInfo> Function();
