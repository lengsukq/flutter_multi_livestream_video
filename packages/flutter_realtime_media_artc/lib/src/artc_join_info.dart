import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

/// Channel mode ARTC needs before joining.
enum ArtcRoomMode { communication, interactiveLive }

/// Short-lived credentials returned by the application backend for ARTC.
class ArtcJoinInfo extends MediaJoinInfo {
  ArtcJoinInfo({
    required super.roomCode,
    required super.participantId,
    required super.role,
    required super.displayName,
    super.avatarUrl,
    required this.appId,
    required this.channelId,
    required this.userId,
    required this.authInfo,
    required this.expiresAtMs,
  }) : super(
         providerId: providerIdValue,
         payload: {
           'appId': appId,
           'channelId': channelId,
           'userId': userId,
           'authInfo': authInfo,
           'expiresAtMs': expiresAtMs,
         },
       );

  static const String providerIdValue = 'artc';

  final String appId;
  final String channelId;
  final String userId;

  /// Opaque, server-generated, single-parameter ARTC authentication payload.
  final String authInfo;

  /// Expiration time as Unix milliseconds.
  final int expiresAtMs;

  ArtcRoomMode get roomMode => role == MediaRole.participant
      ? ArtcRoomMode.communication
      : ArtcRoomMode.interactiveLive;

  factory ArtcJoinInfo.fromJson(Map<String, dynamic> json) {
    final provider = json['provider']?.toString().trim().toLowerCase();
    if (provider != providerIdValue) {
      throw const RealtimeException(
        code: RealtimeErrorCode.invalidArgument,
        message: 'Join information does not identify the ARTC provider.',
        providerId: providerIdValue,
      );
    }
    final roomCode = MediaJoinInfo.requireStringIn(
      json,
      'roomCode',
      providerId: providerIdValue,
    );
    final participantId = MediaJoinInfo.requireStringIn(
      json,
      'participantId',
      providerId: providerIdValue,
    );
    final role = MediaRole.tryParse(json['role']);
    if (role == null) {
      throw const RealtimeException(
        code: RealtimeErrorCode.invalidArgument,
        message: 'ARTC join information is missing a valid role.',
        providerId: providerIdValue,
      );
    }
    final block = json['artc'];
    if (block is! Map) {
      throw const RealtimeException(
        code: RealtimeErrorCode.invalidArgument,
        message: 'Join information is missing the ARTC credential block.',
        providerId: providerIdValue,
      );
    }
    final artc = Map<String, Object?>.from(block);
    final appId = MediaJoinInfo.requireStringIn(
      artc,
      'appId',
      providerId: providerIdValue,
    );
    final channelId = MediaJoinInfo.requireStringIn(
      artc,
      'channelId',
      providerId: providerIdValue,
    );
    final userId = MediaJoinInfo.requireStringIn(
      artc,
      'userId',
      providerId: providerIdValue,
    );
    if (participantId != userId) {
      throw const RealtimeException(
        code: RealtimeErrorCode.invalidArgument,
        message: 'ARTC userId must match participantId.',
        providerId: providerIdValue,
      );
    }
    final authInfo = MediaJoinInfo.requireStringIn(
      artc,
      'authInfo',
      providerId: providerIdValue,
    );
    final expiryValue = artc['expiresAtMs'];
    final expiresAtMs = expiryValue is num
        ? expiryValue.toInt()
        : int.tryParse(expiryValue?.toString() ?? '') ?? 0;
    if (expiresAtMs <= 0) {
      throw const RealtimeException(
        code: RealtimeErrorCode.invalidArgument,
        message:
            'ARTC expiresAtMs must be a positive Unix timestamp in milliseconds.',
        providerId: providerIdValue,
      );
    }

    return ArtcJoinInfo(
      roomCode: roomCode,
      participantId: participantId,
      role: role,
      displayName: json['displayName']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString(),
      appId: appId,
      channelId: channelId,
      userId: userId,
      authInfo: authInfo,
      expiresAtMs: expiresAtMs,
    );
  }
}
