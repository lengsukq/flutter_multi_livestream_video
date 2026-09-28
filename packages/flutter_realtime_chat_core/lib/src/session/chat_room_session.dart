import '../model/chat_role.dart';
import 'chat_session.dart';

class ChatRoomSession {
  ChatRoomSession({
    required this.roomCode,
    required this.participantId,
    required this.userId,
    required this.role,
    required this.session,
  });

  final String roomCode;
  final String participantId;
  final String userId;
  final ChatRole role;
  final ChatSession session;

  Future<void> dispose() => session.dispose();
}
