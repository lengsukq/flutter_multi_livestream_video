import '../session/chat_join_info.dart';
import '../model/chat_role.dart';
import '../model/chat_room_context.dart';

/// Resolves short-lived chat credentials without prescribing HTTP or a
/// particular backend language/runtime.
abstract interface class ChatProvisioner {
  Future<ChatJoinInfo> provision({
    required String roomCode,
    required String participantId,
    String? participantCredential,
  });
}

/// Optional control-plane contract for chat rooms that exist independently
/// from any media meeting/live room.
abstract interface class StandaloneChatProvisioner implements ChatProvisioner {
  Future<ChatJoinInfo> create({
    required String userId,
    required String displayName,
    ChatRole role = ChatRole.host,
    String? roomCode,
  });

  Future<ChatJoinInfo> join({
    required String roomCode,
    required String userId,
    required String displayName,
    ChatRole role = ChatRole.participant,
  });

  Future<List<ChatRoomSummary>> listRooms();
}

typedef ChatProvisionCallback =
    Future<ChatJoinInfo> Function({
      required String roomCode,
      required String participantId,
      String? participantCredential,
    });

class CallbackChatProvisioner implements ChatProvisioner {
  const CallbackChatProvisioner(this.callback);
  final ChatProvisionCallback callback;

  @override
  Future<ChatJoinInfo> provision({
    required String roomCode,
    required String participantId,
    String? participantCredential,
  }) => callback(
    roomCode: roomCode,
    participantId: participantId,
    participantCredential: participantCredential,
  );
}
