import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'provider_web_join_info.dart';
import 'provider_web_profile.dart';

class ProviderWebJoinInfoDecoder {
  const ProviderWebJoinInfoDecoder(this.providerId, this.profile);
  final String providerId;
  final ProviderWebProfile profile;
  Set<MediaRole> get supportedRoles => profile.supportedRoles;
  ProviderWebJoinInfo decode(Map<String, dynamic> json) {
    final actualProvider = json['provider']?.toString().trim().toLowerCase();
    if (actualProvider != null &&
        actualProvider.isNotEmpty &&
        actualProvider != providerId) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidArgument,
        message:
            'Expected $providerId join information, got "$actualProvider".',
        providerId: providerId,
      );
    }
    final roomCode = MediaJoinInfo.requireStringIn(
      json,
      'roomCode',
      providerId: providerId,
    );
    final participantId = _participantIdFromPayload(json);
    final role = MediaRole.tryParse(json['role']) ?? MediaRole.participant;
    if (!supportedRoles.contains(role)) {
      throw RealtimeException(
        code: RealtimeErrorCode.unsupportedFeature,
        message: '$providerId does not support the ${role.wireName} role.',
        providerId: providerId,
      );
    }
    return ProviderWebJoinInfo(
      providerId: providerId,
      roomCode: roomCode,
      participantId: participantId,
      role: role,
      displayName: _displayNameFromPayload(json),
      backendPayload: Map<String, Object?>.from(json),
    );
  }

  String _participantIdFromPayload(Map<String, dynamic> json) {
    final supplied = json['participantId']?.toString().trim();
    if (supplied != null && supplied.isNotEmpty) return supplied;
    if (profile.usesChimeAttendeePayload) {
      final attendee = json['attendee'] ?? json['Attendee'];
      if (attendee is Map) {
        final id = (attendee['AttendeeId'] ?? attendee['attendeeId'])
            ?.toString()
            .trim();
        if (id != null && id.isNotEmpty) return id;
      }
    }
    throw RealtimeException(
      code: RealtimeErrorCode.invalidArgument,
      message: 'Join information is missing participantId.',
      providerId: providerId,
    );
  }

  String _displayNameFromPayload(Map<String, dynamic> json) {
    final displayName = json['displayName']?.toString().trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    final nickname = json['nickname']?.toString().trim();
    if (nickname != null && nickname.isNotEmpty) return nickname;
    if (profile.usesChimeAttendeePayload) {
      final attendee = json['attendee'] ?? json['Attendee'];
      if (attendee is Map) {
        return (attendee['ExternalUserId'] ?? attendee['externalUserId'])
                ?.toString()
                .trim() ??
            '';
      }
    }
    return '';
  }
}
