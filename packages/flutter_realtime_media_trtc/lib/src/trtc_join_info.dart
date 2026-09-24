import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

/// TRTC credentials returned by the application backend.
class TrtcJoinInfo extends MediaJoinInfo {
  TrtcJoinInfo({
    required super.roomCode,
    required super.participantId,
    required super.role,
    required super.displayName,
    required this.sdkAppId,
    required this.strRoomId,
    required this.userId,
    required this.userSig,
    required this.privateMapKey,
    required this.expiresAtMs,
  }) : super(
         providerId: providerIdValue,
         payload: {
           'sdkAppId': sdkAppId,
           'strRoomId': strRoomId,
           'userId': userId,
           'userSig': userSig,
           'privateMapKey': privateMapKey,
           'expiresAtMs': expiresAtMs,
         },
       );

  static const String providerIdValue = 'trtc';

  final int sdkAppId;
  final String strRoomId;
  final String userId;
  final String userSig;
  final String privateMapKey;
  final int expiresAtMs;

  /// Parses and validates the provider-specific response block.
  factory TrtcJoinInfo.fromJson(Map<String, dynamic> json) {
    final provider = json['provider']?.toString().trim().toLowerCase();
    if (provider != providerIdValue) {
      throw const MediaError(
        code: MediaErrorCode.invalidJoinInfo,
        message: 'Join information does not identify the TRTC provider.',
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
      throw const MediaError(
        code: MediaErrorCode.invalidJoinInfo,
        message: 'TRTC join information is missing a valid role.',
        providerId: providerIdValue,
      );
    }
    final block = json['trtc'];
    if (block is! Map) {
      throw const MediaError(
        code: MediaErrorCode.invalidJoinInfo,
        message: 'Join information is missing the TRTC credential block.',
        providerId: providerIdValue,
      );
    }
    final trtc = Map<String, Object?>.from(block);
    final sdkAppIdValue = trtc['sdkAppId'];
    final sdkAppId = sdkAppIdValue is num
        ? sdkAppIdValue.toInt()
        : int.tryParse(sdkAppIdValue?.toString() ?? '');
    if (sdkAppId == null || sdkAppId <= 0) {
      throw const MediaError(
        code: MediaErrorCode.invalidJoinInfo,
        message: 'TRTC SDKAppId must be a positive integer.',
        providerId: providerIdValue,
      );
    }
    final userId = MediaJoinInfo.requireStringIn(
      trtc,
      'userId',
      providerId: providerIdValue,
    );
    if (participantId != userId) {
      throw const MediaError(
        code: MediaErrorCode.invalidJoinInfo,
        message: 'TRTC userId must match participantId.',
        providerId: providerIdValue,
      );
    }
    final expiresValue = trtc['expiresAtMs'];
    final expiresAtMs = expiresValue is num
        ? expiresValue.toInt()
        : int.tryParse(expiresValue?.toString() ?? '') ?? 0;
    return TrtcJoinInfo(
      roomCode: roomCode,
      participantId: participantId,
      role: role,
      displayName: json['displayName']?.toString() ?? '',
      sdkAppId: sdkAppId,
      strRoomId: MediaJoinInfo.requireStringIn(
        trtc,
        'strRoomId',
        providerId: providerIdValue,
      ),
      userId: userId,
      userSig: MediaJoinInfo.requireStringIn(
        trtc,
        'userSig',
        providerId: providerIdValue,
      ),
      privateMapKey: MediaJoinInfo.requireStringIn(
        trtc,
        'privateMapKey',
        providerId: providerIdValue,
      ),
      expiresAtMs: expiresAtMs,
    );
  }

  /// Role-specific TRTC scene shared by every user in the provider room.
  TrtcRoomScene get scene => role == MediaRole.participant
      ? TrtcRoomScene.videoCall
      : TrtcRoomScene.live;
}

/// TRTC scenes supported by this adapter.
enum TrtcRoomScene { videoCall, live }
