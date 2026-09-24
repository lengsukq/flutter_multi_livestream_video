import 'package:flutter_aws_chime/flutter_aws_chime.dart' as chime;
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

/// Provider-neutral wrapper around the existing short-lived Chime [chime.JoinInfo].
class ChimeJoinInfo extends MediaJoinInfo {
  ChimeJoinInfo({
    required super.roomCode,
    required super.participantId,
    required super.role,
    required this.chimeJoinInfo,
    super.displayName,
  }) : super(providerId: providerIdValue);

  static const String providerIdValue = 'chime';

  final chime.JoinInfo chimeJoinInfo;

  factory ChimeJoinInfo.fromBackendResponse(Map<String, dynamic> json) {
    final provider = json['provider']?.toString().trim().toLowerCase();
    if (provider != null &&
        provider.isNotEmpty &&
        provider != providerIdValue) {
      throw MediaError(
        code: MediaErrorCode.invalidJoinInfo,
        message: 'Expected Chime join information, got "$provider".',
        providerId: providerIdValue,
      );
    }

    final roomCode = MediaJoinInfo.requireStringIn(
      json,
      'roomCode',
      providerId: providerIdValue,
    );
    final role = MediaRole.tryParse(json['role']) ?? MediaRole.participant;
    if (role != MediaRole.participant) {
      throw MediaError(
        code: MediaErrorCode.unsupportedFeature,
        message:
            'The current Chime adapter implements symmetric meeting '
            'participants only.',
        providerId: providerIdValue,
      );
    }

    final chimeInfo = _parseChimeJoinInfo(json);
    final attendeeId = chimeInfo.attendee.attendeeId;
    final commonParticipantId = json['participantId']?.toString().trim();
    if (commonParticipantId != null &&
        commonParticipantId.isNotEmpty &&
        commonParticipantId != attendeeId) {
      throw const MediaError(
        code: MediaErrorCode.invalidJoinInfo,
        message: 'participantId must match attendee.AttendeeId for Chime.',
        providerId: providerIdValue,
      );
    }
    final displayName =
        json['displayName']?.toString().trim() ??
        json['nickname']?.toString().trim() ??
        chimeInfo.attendee.externalUserId;

    return ChimeJoinInfo(
      roomCode: roomCode,
      participantId: attendeeId,
      role: role,
      displayName: displayName,
      chimeJoinInfo: chimeInfo,
    );
  }

  static chime.JoinInfo _parseChimeJoinInfo(Map<String, dynamic> json) {
    try {
      final info = chime.JoinInfo.fromJson(json);
      info.validate();
      return info;
    } on FormatException catch (error) {
      throw MediaError(
        code: MediaErrorCode.invalidJoinInfo,
        message: error.message.toString(),
        details: error,
        providerId: providerIdValue,
      );
    }
  }
}
