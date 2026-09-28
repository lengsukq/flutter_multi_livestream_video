import '../model/chat_role.dart';
import '../model/chat_room_context.dart';

class ChatJoinInfo {
  const ChatJoinInfo({
    required this.providerId,
    required this.roomCode,
    required this.participantId,
    required this.userId,
    required this.displayName,
    required this.role,
    required this.json,
    this.context = ChatRoomContext.attached,
  });

  final String providerId;
  final String roomCode;
  final String participantId;
  final String userId;
  final String displayName;
  final ChatRole role;
  final Map<String, dynamic> json;
  final ChatRoomContext context;
}

typedef ChatCredentialProvider = Future<ChatJoinInfo> Function();
