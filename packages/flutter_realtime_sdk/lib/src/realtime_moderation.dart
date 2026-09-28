import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

class RealtimeMediaModeration {
  const RealtimeMediaModeration(this.room);
  final MediaRoomSession room;

  MediaManagementCapabilities get capabilities =>
      room.session.capabilities.managementCapabilities;
  Future<List<MediaRoomParticipantSummary>> listParticipants() =>
      room.listParticipants();
  Future<void> removeParticipant(String participantId) =>
      room.removeParticipant(participantId);
  Future<void> muteParticipant(String participantId) =>
      room.muteParticipant(participantId);
  Future<void> stopParticipantVideo(String participantId) =>
      room.stopParticipantVideo(participantId);
  Future<void> changeParticipantRole(String participantId, MediaRole role) =>
      room.changeParticipantRole(participantId, role);
  Future<void> closeRoom() => room.closeRoom();
}

class RealtimeChatModeration {
  const RealtimeChatModeration(this.session, [this.controlPlane]);
  final ChatSession session;
  final ChatModeration? controlPlane;

  ChatManagementCapabilities get capabilities =>
      session.capabilities.managementCapabilities;

  Future<void> deleteMessage(String messageId) =>
      session.deleteMessage(messageId);
  Future<void> removeMember(String userId) =>
      session.capabilities.canDisconnectUser
      ? session.disconnectUser(userId)
      : _advanced.removeMember(userId);

  ChatModeration get _advanced {
    final configured = controlPlane;
    if (configured != null) return configured;
    final value = session;
    if (value is ChatModeration) return value as ChatModeration;
    throw ChatError(
      code: ChatErrorCode.unsupportedFeature,
      message:
          'Provider ${session.providerId} does not expose advanced chat moderation.',
      providerId: session.providerId,
    );
  }

  Future<List<ChatMember>> listMembers() => _advanced.listMembers();
  Future<void> muteMember(String userId, {required bool muted}) =>
      _advanced.muteMember(userId, muted: muted);
  Future<void> banMember(String userId, {required bool banned}) =>
      _advanced.banMember(userId, banned: banned);
  Future<void> recallMessage(String messageId) =>
      _advanced.recallMessage(messageId);
  Future<void> changeMemberRole(String userId, ChatRole role) =>
      _advanced.changeMemberRole(userId, role);
  Future<void> closeRoom() => _advanced.closeRoom();
}
