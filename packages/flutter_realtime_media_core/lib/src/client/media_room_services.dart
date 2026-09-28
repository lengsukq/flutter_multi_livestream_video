import '../model/media_identity.dart';
import '../model/media_role.dart';
import '../model/media_room_mode.dart';
import '../model/media_room_summary.dart';
import 'media_backend_client.dart';

/// Application-defined room provisioning. Implementations may call any
/// backend/runtime; Core does not prescribe HTTP or the repository demo server.
abstract interface class MediaRoomProvisioner {
  Future<MediaRoomJoinResponse> create({
    required MediaIdentity identity,
    MediaRoomMode roomMode = MediaRoomMode.meeting,
    MediaRole? role,
    String? roomCode,
  });

  Future<MediaRoomJoinResponse> join({
    required String roomCode,
    required MediaIdentity identity,
    MediaRole? role,
    String? roomOwnerCredential,
  });

  Future<MediaRoomJoinResponse> refresh({
    required String roomCode,
    required String participantId,
    required MediaRole role,
    String? participantCredential,
  });
}

abstract interface class MediaRoomDiscovery {
  Future<List<MediaRoomSummary>> listRooms();
}
