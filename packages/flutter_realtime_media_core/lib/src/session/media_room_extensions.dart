import '../model/media_room_participant_summary.dart';

/// Optional lifecycle integration for logical-room presence.
abstract interface class MediaRoomPresence {
  Future<void> heartbeat(String roomCode, {String? participantId});
  Future<void> leave(String roomCode, {String? participantId});
}

/// Optional privileged logical-room operations.
abstract interface class MediaRoomManagement {
  Future<List<MediaRoomParticipantSummary>> listParticipants(
    String roomCode, {
    required String requesterParticipantId,
    String? participantCredential,
  });

  Future<void> removeParticipant(
    String roomCode, {
    required String requesterParticipantId,
    required String targetParticipantId,
    String? participantCredential,
  });

  Future<void> closeRoomManaged(
    String roomCode, {
    required String requesterParticipantId,
    String? participantCredential,
  });
}
