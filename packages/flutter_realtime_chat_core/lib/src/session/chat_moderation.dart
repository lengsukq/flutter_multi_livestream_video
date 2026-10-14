import '../model/chat_management_capability.dart';
import '../model/chat_role.dart';

class ChatMember {
  const ChatMember({
    required this.userId,
    this.displayName = '',
    this.role = ChatRole.participant,
    this.muted = false,
    this.banned = false,
    this.avatarUrl,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final ChatRole role;
  final bool muted;
  final bool banned;
}

/// Optional control-plane-aware message deletion. A composite implementation
/// may need to coordinate client and backend deletion exactly once.
abstract interface class ChatMessageDeleteAction {
  Future<void> deleteMessage(String messageId);
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

/// Optional capability source for control-plane moderation.
///
/// Chat provider client capabilities and backend moderation capabilities are
/// intentionally separate: a provider SDK may not expose member removal while
/// the trusted backend can still enforce it through the provider REST API.
abstract interface class ChatModerationCapabilitySource {
  ChatManagementCapabilities get moderationCapabilities;
}

/// Optional control-plane hook used after a provider client already enforced
/// a member removal.
///
/// This keeps a backend logical member directory and future token issuance in
/// sync without invoking the provider's disconnect/kick API a second time.
abstract interface class ChatModerationStateSync {
  Future<void> syncRemovedMember(String userId);
}
