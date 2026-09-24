import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

/// Parsed LiveKit credentials returned by a media backend.
class LiveKitJoinInfo extends MediaJoinInfo {
  LiveKitJoinInfo({
    required super.roomCode,
    required super.participantId,
    required super.role,
    required this.url,
    required this.token,
    required this.identity,
    super.displayName,
  }) : super(
         providerId: providerIdValue,
         payload: <String, Object?>{
           'url': url,
           'token': token,
           'identity': identity,
         },
       );

  static const String providerIdValue = 'livekit';

  final String url;
  final String token;
  final String identity;

  /// Parses the `livekit` provider block from `MEDIA_BACKEND_CONTRACT.md`.
  factory LiveKitJoinInfo.fromBackendResponse(Map<String, dynamic> json) {
    final provider = json['provider']?.toString().trim().toLowerCase();
    if (provider != null &&
        provider.isNotEmpty &&
        provider != providerIdValue) {
      throw MediaError(
        code: MediaErrorCode.invalidJoinInfo,
        message: 'Expected LiveKit join information, got "$provider".',
        providerId: providerIdValue,
      );
    }

    final roomCode = MediaJoinInfo.requireStringIn(
      json,
      'roomCode',
      providerId: providerIdValue,
    );
    final role = MediaRole.tryParse(json['role']) ?? MediaRole.participant;
    final livekitValue = json['livekit'];
    if (livekitValue is! Map) {
      throw const MediaError(
        code: MediaErrorCode.invalidJoinInfo,
        message: 'Join information is missing the "livekit" provider block.',
        providerId: providerIdValue,
      );
    }
    final livekit = Map<String, Object?>.from(livekitValue);
    final url = MediaJoinInfo.requireStringIn(
      livekit,
      'url',
      providerId: providerIdValue,
    );
    final token = MediaJoinInfo.requireStringIn(
      livekit,
      'token',
      providerId: providerIdValue,
    );
    final nestedIdentity = livekit['identity']?.toString().trim();
    final commonParticipantId = json['participantId']?.toString().trim();
    final participantId =
        commonParticipantId != null && commonParticipantId.isNotEmpty
        ? commonParticipantId
        : nestedIdentity;
    if (participantId == null || participantId.isEmpty) {
      throw const MediaError(
        code: MediaErrorCode.invalidJoinInfo,
        message: 'Join information is missing "participantId".',
        providerId: providerIdValue,
      );
    }
    final identity = nestedIdentity == null || nestedIdentity.isEmpty
        ? participantId
        : nestedIdentity;
    if (identity != participantId) {
      throw const MediaError(
        code: MediaErrorCode.invalidJoinInfo,
        message: 'livekit.identity must match participantId.',
        providerId: providerIdValue,
      );
    }

    final displayName =
        json['displayName']?.toString().trim() ??
        json['nickname']?.toString().trim() ??
        '';
    return LiveKitJoinInfo(
      roomCode: roomCode,
      participantId: participantId,
      role: role,
      url: url,
      token: token,
      identity: identity,
      displayName: displayName,
    );
  }
}
