import 'chat_provisioner.dart';
import '../session/chat_join_info.dart';
import '../model/chat_role.dart';

/// Optional profile-aware provisioning, preserving existing custom provisioners.
abstract interface class StandaloneChatProfileProvisioner
    implements StandaloneChatProvisioner {
  Future<ChatJoinInfo> createWithProfile({
    required String userId,
    required String displayName,
    String? avatarUrl,
    ChatRole role = ChatRole.host,
    String? roomCode,
  });
  Future<ChatJoinInfo> joinWithProfile({
    required String roomCode,
    required String userId,
    required String displayName,
    String? avatarUrl,
    ChatRole role = ChatRole.participant,
  });
}
