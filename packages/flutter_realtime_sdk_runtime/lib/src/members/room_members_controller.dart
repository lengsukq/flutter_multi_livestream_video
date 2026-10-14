import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

/// One logical user shown across both RTC and IM, without coupling identity
/// merging to any particular Flutter room page.
class RoomManagedMember {
  const RoomManagedMember({
    required this.userId,
    required this.displayName,
    this.media,
    this.chat,
    required this.isSelf,
  });

  final String userId;
  final String displayName;
  String? get avatarUrl => media?.avatarUrl ?? chat?.avatarUrl;
  final MediaRoomParticipantSummary? media;
  final ChatMember? chat;
  final bool isSelf;
}

class RoomMemberLoadResult {
  RoomMemberLoadResult({
    required List<RoomManagedMember> members,
    required this.completed,
    this.error,
  }) : members = List.unmodifiable(members);

  final List<RoomManagedMember> members;
  final bool completed;
  final Object? error;
}

/// Merge a user's media and chat presence only when their logical user IDs
/// match. Anonymous media IDs remain distinct from authenticated chat users.
List<RoomManagedMember> mergeRoomMembers(
  List<MediaRoomParticipantSummary> media,
  List<ChatMember> chat, {
  required String localMediaParticipantId,
  String? localChatUserId,
}) {
  final mediaByKey = <String, MediaRoomParticipantSummary>{};
  final chatByKey = <String, ChatMember>{};
  final orderedKeys = <String>[];

  String mediaKey(MediaRoomParticipantSummary item) =>
      item.userId.trim().isNotEmpty
      ? item.userId.trim()
      : 'media:${item.participantId}';

  for (final item in media) {
    final key = mediaKey(item);
    mediaByKey[key] = item;
    if (!orderedKeys.contains(key)) orderedKeys.add(key);
  }
  for (final item in chat) {
    final key = item.userId.trim();
    if (key.isEmpty) continue;
    chatByKey[key] = item;
    if (!orderedKeys.contains(key)) orderedKeys.add(key);
  }

  return List.unmodifiable(
    orderedKeys.map((key) {
      final mediaMember = mediaByKey[key];
      final chatMember = chatByKey[key];
      final rawName = mediaMember?.displayName.trim().isNotEmpty == true
          ? mediaMember!.displayName.trim()
          : chatMember?.displayName.trim().isNotEmpty == true
          ? chatMember!.displayName.trim()
          : key;
      final selfByMedia = mediaMember?.participantId == localMediaParticipantId;
      final selfByChat =
          localChatUserId != null &&
          localChatUserId.isNotEmpty &&
          chatMember?.userId == localChatUserId;
      return RoomManagedMember(
        userId: key,
        displayName: rawName,
        media: mediaMember,
        chat: chatMember,
        isSelf: selfByMedia || selfByChat,
      );
    }),
  );
}

/// A UI-independent roster that also shows current RTC participants when
/// backend membership discovery is unavailable or not yet refreshed.
List<RoomManagedMember> mergeSnapshotMembers(
  List<RoomManagedMember> directory,
  MediaSnapshot snapshot, {
  MediaRole? localRole,
}) {
  final members = [...directory];
  for (final participant in snapshot.participants) {
    final index = members.indexWhere(
      (member) =>
          member.media?.participantId == participant.id ||
          (member.media != null && member.isSelf && participant.isLocal),
    );
    if (index >= 0) {
      final existing = members[index];
      final media = existing.media;
      if (media != null && participant.avatarUrl != null) {
        members[index] = RoomManagedMember(
          userId: existing.userId,
          displayName: existing.displayName,
          isSelf: existing.isSelf,
          chat: existing.chat,
          media: MediaRoomParticipantSummary(
            participantId: media.participantId,
            userId: media.userId,
            displayName: media.displayName,
            role: media.role,
            joinedAt: media.joinedAt,
            avatarUrl: participant.avatarUrl,
          ),
        );
      }
      continue;
    }
    members.add(
      RoomManagedMember(
        userId: 'media:${participant.id}',
        displayName: participant.displayName.isEmpty
            ? participant.id
            : participant.displayName,
        media: MediaRoomParticipantSummary(
          participantId: participant.id,
          displayName: participant.displayName,
          avatarUrl: participant.avatarUrl,
          role: participant.isLocal ? localRole : null,
        ),
        isSelf: participant.isLocal,
      ),
    );
  }
  return List.unmodifiable(members);
}

class RoomMuteResult {
  RoomMuteResult(Map<MediaParticipant, Object> failures, this.completed)
    : failures = Map.unmodifiable(failures);
  final Map<MediaParticipant, Object> failures;
  final bool completed;
}

/// Provider-neutral administrative commands shared by legacy and composable
/// rooms. The backend/provider remains the authority for execution.
enum RoomMediaMemberAction { remove, mute, stopVideo, grantHost }

/// Executes member operations without retaining a widget or BuildContext.
class RoomMembersController {
  bool _busy = false;

  /// Runs the same permission-checked batch moderation regardless of UI.
  /// Partial failures are returned rather than aborting subsequent targets.
  Future<RoomMuteResult> muteAll(
    MediaRoomSession room, {
    Iterable<MediaParticipant>? targets,
    required bool Function() isCurrent,
  }) => mute(
    room,
    (targets ?? room.snapshot.participants.where((p) => !p.isLocal)).toList(
      growable: false,
    ),
    isCurrent: isCurrent,
  );

  Future<void> manageMedia(
    MediaRoomSession room,
    String participantId,
    RoomMediaMemberAction action,
  ) async {
    if (participantId.trim().isEmpty ||
        participantId == room.participantId ||
        !room.isLogicalOwner) {
      throw const RealtimeException(
        code: RealtimeErrorCode.invalidState,
        message: 'Only the room owner can manage another participant.',
      );
    }
    final capabilities = room.managementCapabilities;
    final available = switch (action) {
      RoomMediaMemberAction.remove => capabilities.removeParticipant.supported,
      RoomMediaMemberAction.mute => capabilities.muteParticipant.supported,
      RoomMediaMemberAction.stopVideo =>
        capabilities.stopParticipantVideo.supported,
      RoomMediaMemberAction.grantHost =>
        capabilities.changeParticipantRole.supported,
    };
    if (!available) {
      throw const RealtimeException(
        code: RealtimeErrorCode.unsupportedFeature,
        message: 'The current provider does not support this operation.',
      );
    }
    switch (action) {
      case RoomMediaMemberAction.remove:
        await room.removeParticipant(participantId);
      case RoomMediaMemberAction.mute:
        await room.muteParticipant(participantId);
      case RoomMediaMemberAction.stopVideo:
        await room.stopParticipantVideo(participantId);
      case RoomMediaMemberAction.grantHost:
        await room.changeParticipantRole(participantId, MediaRole.host);
    }
  }

  Future<void> removeChatMember(
    ChatModeration moderation,
    String userId, {
    ChatSession? session,
  }) async {
    final ownUserId = session is ChatSessionIdentity
        ? (session as ChatSessionIdentity).localUserId
        : null;
    if (userId.trim().isEmpty || userId == ownUserId) {
      throw const RealtimeException(
        code: RealtimeErrorCode.invalidState,
        message: 'Cannot remove the current chat member.',
      );
    }
    final capabilities = moderation is ChatModerationCapabilitySource
        ? (moderation as ChatModerationCapabilitySource).moderationCapabilities
        : const ChatManagementCapabilities();
    if (!capabilities.removeMember.supported) {
      throw const RealtimeException(
        code: RealtimeErrorCode.unsupportedFeature,
        message: 'The current chat provider cannot remove members.',
      );
    }
    await moderation.removeMember(userId);
  }

  /// Capability-aware RTC + IM roster query, independent of widget lifecycle.
  /// Caller checks [completed] before exposing results after a room swap.
  Future<RoomMemberLoadResult> load(
    MediaRoomSession room, {
    ChatSession? chatSession,
    ChatModeration? chatModeration,
    required bool Function() isCurrent,
  }) async {
    final mediaCapabilities = room.managementCapabilities;
    final chatCapabilities = chatModeration is ChatModerationCapabilitySource
        ? (chatModeration as ChatModerationCapabilitySource)
              .moderationCapabilities
        : const ChatManagementCapabilities();
    List<MediaRoomParticipantSummary> mediaParticipants = const [];
    List<ChatMember> chatMembers = const [];
    final errors = <Object>[];

    if (mediaCapabilities.listParticipants.supported) {
      try {
        mediaParticipants = await room.listParticipants();
      } catch (error) {
        errors.add(error);
      }
    }
    if (!isCurrent()) {
      return RoomMemberLoadResult(members: const [], completed: false);
    }
    if (chatModeration != null && chatCapabilities.listMembers.supported) {
      try {
        chatMembers = await chatModeration.listMembers();
      } catch (error) {
        errors.add(error);
      }
    }
    if (!isCurrent()) {
      return RoomMemberLoadResult(members: const [], completed: false);
    }
    return RoomMemberLoadResult(
      members: mergeRoomMembers(
        mediaParticipants,
        chatMembers,
        localMediaParticipantId: room.participantId,
        localChatUserId: chatSession is ChatSessionIdentity
            ? (chatSession as ChatSessionIdentity).localUserId
            : null,
      ),
      completed: true,
      error: errors.isEmpty ? null : errors.first,
    );
  }

  Future<RoomMuteResult> mute(
    MediaRoomSession room,
    List<MediaParticipant> targets, {
    required bool Function() isCurrent,
  }) async {
    if (_busy) {
      throw const RealtimeException(
        code: RealtimeErrorCode.invalidState,
        message: 'Member management is already running.',
      );
    }
    _busy = true;
    final failures = <MediaParticipant, Object>{};
    try {
      for (final participant in targets) {
        if (!isCurrent()) return RoomMuteResult(failures, false);
        try {
          await manageMedia(room, participant.id, RoomMediaMemberAction.mute);
        } catch (error, stack) {
          failures[participant] = normalizeRealtimeException(
            error,
            domain: 'media',
            operation: 'muteParticipant',
            stackTrace: stack,
          );
        }
      }
      return RoomMuteResult(failures, isCurrent());
    } finally {
      _busy = false;
    }
  }
}
