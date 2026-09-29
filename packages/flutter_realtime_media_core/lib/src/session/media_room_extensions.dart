import '../model/media_room_participant_summary.dart';
import '../model/media_role.dart';

/// Optional lifecycle integration for logical-room presence.
abstract interface class MediaRoomPresence {
  Future<void> heartbeat(String roomCode, {String? participantId});
  Future<void> leave(String roomCode, {String? participantId});
}

/// Optional advanced moderation contract.
///
/// Implementations may be provider-client backed, backend backed, or hybrid.
/// Providers must not implement an operation unless it is enforceable.
abstract interface class MediaRoomModeration implements MediaRoomManagement {
  Future<void> muteParticipant(
    String roomCode, {
    required String requesterParticipantId,
    required String targetParticipantId,
    String? participantCredential,
    String? roomOwnerCredential,
  });

  Future<void> stopParticipantVideo(
    String roomCode, {
    required String requesterParticipantId,
    required String targetParticipantId,
    String? participantCredential,
    String? roomOwnerCredential,
  });

  Future<void> changeParticipantRole(
    String roomCode, {
    required String requesterParticipantId,
    required String targetParticipantId,
    required MediaRole role,
    String? participantCredential,
    String? roomOwnerCredential,
  });
}

/// Optional privileged logical-room operations.
abstract interface class MediaRoomManagement {
  Future<List<MediaRoomParticipantSummary>> listParticipants(
    String roomCode, {
    required String requesterParticipantId,
    String? participantCredential,
    String? roomOwnerCredential,
  });

  Future<void> removeParticipant(
    String roomCode, {
    required String requesterParticipantId,
    required String targetParticipantId,
    String? participantCredential,
    String? roomOwnerCredential,
  });

  Future<void> closeRoomManaged(
    String roomCode, {
    required String requesterParticipantId,
    String? participantCredential,
    String? roomOwnerCredential,
  });
}
