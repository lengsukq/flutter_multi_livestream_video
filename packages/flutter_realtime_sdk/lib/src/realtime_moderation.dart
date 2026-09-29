import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

class RealtimeMediaModeration {
  const RealtimeMediaModeration(this.room);
  final MediaRoomSession room;

  MediaManagementCapabilities get capabilities => room.managementCapabilities;
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

class RealtimeChatModeration
    implements ChatModeration, ChatModerationCapabilitySource {
  const RealtimeChatModeration(this.session, [this.controlPlane]);
  final ChatSession session;
  final ChatModeration? controlPlane;

  ChatManagementCapability _combine(
    ChatManagementCapability client,
    ChatManagementCapability backend,
  ) {
    if (!client.supported) return backend;
    if (!backend.supported) return client;
    if (client.execution == ChatManagementExecution.hybrid ||
        backend.execution == ChatManagementExecution.hybrid ||
        (client.execution == ChatManagementExecution.client &&
            backend.execution == ChatManagementExecution.backend)) {
      return const ChatManagementCapability.hybrid();
    }
    return client;
  }

  ChatManagementCapabilities get capabilities {
    final client = session.capabilities.managementCapabilities;
    final configured = controlPlane;
    final backend = configured is ChatModerationCapabilitySource
        ? (configured as ChatModerationCapabilitySource).moderationCapabilities
        : const ChatManagementCapabilities();
    return ChatManagementCapabilities(
      listMembers: _combine(client.listMembers, backend.listMembers),
      removeMember: _combine(client.removeMember, backend.removeMember),
      muteMember: _combine(client.muteMember, backend.muteMember),
      banMember: _combine(client.banMember, backend.banMember),
      deleteMessage: _combine(client.deleteMessage, backend.deleteMessage),
      recallMessage: _combine(client.recallMessage, backend.recallMessage),
      manageRoles: _combine(client.manageRoles, backend.manageRoles),
      closeRoom: _combine(client.closeRoom, backend.closeRoom),
    );
  }

  @override
  ChatManagementCapabilities get moderationCapabilities => capabilities;

  ChatModeration? get _clientModeration =>
      session is ChatModeration ? session as ChatModeration : null;

  ChatModeration get _backendModeration {
    final configured = controlPlane;
    if (configured != null) return configured;
    throw ChatError(
      code: ChatErrorCode.unsupportedFeature,
      message:
          'Provider ${session.providerId} requires a moderation backend for this operation.',
      providerId: session.providerId,
    );
  }

  Future<void> deleteMessage(String messageId) async {
    final capability = capabilities.deleteMessage;
    if (!capability.supported) return _unsupported('delete message');
    if (capability.execution == ChatManagementExecution.client ||
        capability.execution == ChatManagementExecution.hybrid) {
      await session.deleteMessage(messageId);
      if (capability.execution != ChatManagementExecution.hybrid) return;
    }
    await _backendModeration.recallMessage(messageId);
  }

  @override
  Future<void> removeMember(String userId) async {
    final capability = capabilities.removeMember;
    if (!capability.supported) return _unsupported('remove member');
    if (capability.execution == ChatManagementExecution.client ||
        capability.execution == ChatManagementExecution.hybrid) {
      if (session.capabilities.canDisconnectUser) {
        await session.disconnectUser(userId);
      } else {
        final client = _clientModeration;
        if (client == null) return _unsupported('client member removal');
        await client.removeMember(userId);
      }
      if (capability.execution != ChatManagementExecution.hybrid) return;
    }
    final backend = _backendModeration;
    if (capability.execution == ChatManagementExecution.hybrid &&
        backend is ChatModerationStateSync) {
      await (backend as ChatModerationStateSync).syncRemovedMember(userId);
      return;
    }
    await backend.removeMember(userId);
  }

  @override
  Future<List<ChatMember>> listMembers() {
    final capability = capabilities.listMembers;
    if (!capability.supported) {
      return Future<List<ChatMember>>.error(_unsupportedError('list members'));
    }
    if (capability.execution == ChatManagementExecution.client) {
      final client = _clientModeration;
      if (client == null) {
        return Future<List<ChatMember>>.error(
          _unsupportedError('client member listing'),
        );
      }
      return client.listMembers();
    }
    return _backendModeration.listMembers();
  }

  @override
  Future<void> muteMember(String userId, {required bool muted}) => _runAdvanced(
    capabilities.muteMember,
    'mute member',
    (moderation) => moderation.muteMember(userId, muted: muted),
  );

  @override
  Future<void> banMember(String userId, {required bool banned}) => _runAdvanced(
    capabilities.banMember,
    'ban member',
    (moderation) => moderation.banMember(userId, banned: banned),
  );

  @override
  Future<void> recallMessage(String messageId) => _runAdvanced(
    capabilities.recallMessage,
    'recall message',
    (moderation) => moderation.recallMessage(messageId),
  );

  @override
  Future<void> changeMemberRole(String userId, ChatRole role) => _runAdvanced(
    capabilities.manageRoles,
    'change member role',
    (moderation) => moderation.changeMemberRole(userId, role),
  );

  @override
  Future<void> closeRoom() => _runAdvanced(
    capabilities.closeRoom,
    'close chat room',
    (moderation) => moderation.closeRoom(),
  );

  Future<void> _runAdvanced(
    ChatManagementCapability capability,
    String operation,
    Future<void> Function(ChatModeration moderation) action,
  ) async {
    if (!capability.supported) return _unsupported(operation);
    if (capability.execution == ChatManagementExecution.client ||
        capability.execution == ChatManagementExecution.hybrid) {
      final client = _clientModeration;
      if (client == null) return _unsupported('client $operation');
      await action(client);
      if (capability.execution != ChatManagementExecution.hybrid) return;
    }
    await action(_backendModeration);
  }

  Future<void> _unsupported(String operation) =>
      Future<void>.error(_unsupportedError(operation));

  ChatError _unsupportedError(String operation) => ChatError(
    code: ChatErrorCode.unsupportedFeature,
    message: 'Provider ${session.providerId} does not support $operation.',
    providerId: session.providerId,
  );
}
