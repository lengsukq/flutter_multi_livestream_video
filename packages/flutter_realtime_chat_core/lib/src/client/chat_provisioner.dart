import '../session/chat_join_info.dart';

/// Resolves short-lived chat credentials without prescribing HTTP or a
/// particular backend language/runtime.
abstract interface class ChatProvisioner {
  Future<ChatJoinInfo> provision({
    required String roomCode,
    required String participantId,
    String? participantCredential,
  });
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
