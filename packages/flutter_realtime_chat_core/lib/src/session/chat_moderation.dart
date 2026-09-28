import '../model/chat_role.dart';

class ChatMember {
  const ChatMember({
    required this.userId,
    this.displayName = '',
    this.role = ChatRole.participant,
    this.muted = false,
    this.banned = false,
  });

  final String userId;
  final String displayName;
  final ChatRole role;
  final bool muted;
  final bool banned;
}

/// Provider-neutral chat governance. Attached and standalone chat share this
/// contract; the execution mechanism is described by ChatCapabilities.
abstract interface class ChatModeration {
  Future<List<ChatMember>> listMembers();
  Future<void> removeMember(String userId);
  Future<void> muteMember(String userId, {required bool muted});
  Future<void> banMember(String userId, {required bool banned});
  Future<void> recallMessage(String messageId);
  Future<void> changeMemberRole(String userId, ChatRole role);
  Future<void> closeRoom();
}
