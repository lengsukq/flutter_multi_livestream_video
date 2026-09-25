import 'media_role.dart';

/// Sanitized logical participant returned by room-management APIs.
class MediaRoomParticipantSummary {
  const MediaRoomParticipantSummary({
    required this.participantId,
    required this.displayName,
    this.role,
    this.joinedAt,
  });

  final String participantId;
  final String displayName;
  final MediaRole? role;
  final DateTime? joinedAt;

  factory MediaRoomParticipantSummary.fromJson(Map<String, dynamic> json) =>
      MediaRoomParticipantSummary(
        participantId: json['participantId']?.toString().trim() ?? '',
        displayName: json['displayName']?.toString().trim() ?? '',
        role: MediaRole.tryParse(json['role']),
        joinedAt: DateTime.tryParse(json['joinedAt']?.toString() ?? ''),
      );
}
