import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';

/// Backend/provider-neutral room operations used by the Demo.
///
/// The widget is responsible only for displaying Pre-Join and navigating to
/// the resulting room. This coordinator never owns the resulting connection:
/// its caller must dispose it when the room route is closed.
class DemoRoomFlow {
  factory DemoRoomFlow({
    required Future<RealtimeConnection> Function(RealtimeRequest request) open,
    required Map<String, String> ownerCredentials,
  }) => DemoRoomFlow._(open, ownerCredentials);

  DemoRoomFlow._(this._open, this._ownerCredentials);

  final Future<RealtimeConnection> Function(RealtimeRequest request) _open;
  final Map<String, String> _ownerCredentials;

  static RealtimeRequest createRequest({
    required MediaRoomMode mode,
    MediaMeetingMode? meetingMode,
    required String deviceId,
    required String displayName,
    String? avatarUrl,
    String? roomCode,
  }) => RealtimeRequest.create(
    meetingMode: meetingMode,
    type: mode == MediaRoomMode.broadcast
        ? RealtimeExperience.live
        : RealtimeExperience.meeting,
    roomCode: roomCode?.trim().isEmpty == true ? null : roomCode,
    user: RealtimeUser(
      id: deviceId,
      name: displayName,
      deviceId: deviceId,
      avatarUrl: avatarUrl,
    ),
  );

  static RealtimeRequest joinRequest({
    required String code,
    required MediaRoomMode? mode,
    required String deviceId,
    required String displayName,
    String? avatarUrl,
    String? ownerCredential,
  }) => RealtimeRequest.join(
    type: mode == MediaRoomMode.broadcast
        ? RealtimeExperience.live
        : RealtimeExperience.meeting,
    roomCode: code,
    roomOwnerCredential: ownerCredential,
    user: RealtimeUser(
      id: deviceId,
      name: displayName,
      deviceId: deviceId,
      avatarUrl: avatarUrl,
    ),
  );

  Future<RealtimeConnection> create({
    required MediaRoomMode mode,
    MediaMeetingMode? meetingMode,
    required String deviceId,
    required String displayName,
    String? avatarUrl,
    String? roomCode,
  }) async {
    final connection = await _open(
      createRequest(
        mode: mode,
        meetingMode: meetingMode,
        deviceId: deviceId,
        displayName: displayName,
        avatarUrl: avatarUrl,
        roomCode: roomCode,
      ),
    );
    _rememberOwner(connection);
    return connection;
  }

  Future<RealtimeConnection> join({
    required String code,
    required MediaRoomMode? mode,
    required String deviceId,
    required String displayName,
    String? avatarUrl,
  }) async {
    final connection = await _open(
      joinRequest(
        code: code,
        mode: mode,
        deviceId: deviceId,
        displayName: displayName,
        avatarUrl: avatarUrl,
        ownerCredential: _ownerCredentials[code],
      ),
    );
    _rememberOwner(connection);
    return connection;
  }

  void _rememberOwner(RealtimeConnection connection) {
    final room = connection.mediaRoom;
    final credential = room?.media.roomOwnerCredential;
    if (credential != null && room != null) {
      _ownerCredentials[room.roomCode] = credential;
    }
  }
}
