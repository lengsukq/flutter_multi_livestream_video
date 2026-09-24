import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

/// Parsed Agora credentials returned by a media backend.
class AgoraJoinInfo extends MediaJoinInfo {
  AgoraJoinInfo({
    required super.roomCode,
    required super.participantId,
    required super.role,
    required this.appId,
    required this.channelName,
    required this.token,
    required this.uid,
    super.displayName,
  }) : super(
         providerId: providerIdValue,
         payload: <String, Object?>{
           'appId': appId,
           'channelName': channelName,
           'token': token,
           'uid': uid,
         },
       );

  static const String providerIdValue = 'agora';

  final String appId;
  final String channelName;
  final String token;
  final int uid;

  factory AgoraJoinInfo.fromBackendResponse(Map<String, dynamic> json) {
    final provider = json['provider']?.toString().trim().toLowerCase();
    if (provider != null &&
        provider.isNotEmpty &&
        provider != providerIdValue) {
      throw MediaError(
        code: MediaErrorCode.invalidJoinInfo,
        message: 'Expected Agora join information, got "$provider".',
        providerId: providerIdValue,
      );
    }

    final roomCode = MediaJoinInfo.requireStringIn(
      json,
      'roomCode',
      providerId: providerIdValue,
    );
    final role = MediaRole.tryParse(json['role']) ?? MediaRole.participant;
    final agoraValue = json['agora'];
    if (agoraValue is! Map) {
      throw const MediaError(
        code: MediaErrorCode.invalidJoinInfo,
        message: 'Join information is missing the "agora" provider block.',
        providerId: providerIdValue,
      );
    }

    final agora = Map<String, Object?>.from(agoraValue);
    final appId = MediaJoinInfo.requireStringIn(
      agora,
      'appId',
      providerId: providerIdValue,
    );
    final channelName = MediaJoinInfo.requireStringIn(
      agora,
      'channelName',
      providerId: providerIdValue,
    );
    final token = MediaJoinInfo.requireStringIn(
      agora,
      'token',
      providerId: providerIdValue,
    );

    final uid = _parseUid(agora['uid']);
    if (uid == null || uid <= 0 || uid > 0x7fffffff) {
      throw const MediaError(
        code: MediaErrorCode.invalidJoinInfo,
        message: 'agora.uid must be an integer between 1 and 2147483647.',
        providerId: providerIdValue,
      );
    }

    final participantId = json['participantId']?.toString().trim();
    final resolvedParticipantId = participantId == null || participantId.isEmpty
        ? uid.toString()
        : participantId;
    if (resolvedParticipantId != uid.toString()) {
      throw const MediaError(
        code: MediaErrorCode.invalidJoinInfo,
        message: 'participantId must match agora.uid.',
        providerId: providerIdValue,
      );
    }

    final displayName =
        json['displayName']?.toString().trim() ??
        json['nickname']?.toString().trim() ??
        '';

    return AgoraJoinInfo(
      roomCode: roomCode,
      participantId: resolvedParticipantId,
      role: role,
      appId: appId,
      channelName: channelName,
      token: token,
      uid: uid,
      displayName: displayName,
    );
  }

  static int? _parseUid(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().trim() ?? '');
  }
}
