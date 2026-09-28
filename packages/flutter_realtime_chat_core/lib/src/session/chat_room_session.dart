import '../model/chat_role.dart';
import 'chat_session.dart';
import 'chat_moderation.dart';

class ChatRoomSession {
  ChatRoomSession({
    required this.roomCode,
    required this.participantId,
    required this.userId,
    required this.role,
    required this.session,
    this.moderation,
  });

  final String roomCode;
  final String participantId;
  final String userId;
  final ChatRole role;
  final ChatSession session;
  final ChatModeration? moderation;

  Future<void> dispose() => session.dispose();
}
