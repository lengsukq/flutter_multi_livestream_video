/// Short-lived meeting and attendee information returned by your application
/// backend. Never construct this value from AWS long-lived credentials.
class JoinInfo {
  const JoinInfo({required this.meeting, required this.attendee});

  final MeetingInfo meeting;
  final AttendeeInfo attendee;

  factory JoinInfo.fromJson(Map<String, dynamic> json) {
    final meeting = json['meeting'] ?? json['Meeting'];
    final attendee = json['attendee'] ?? json['Attendee'];
    if (meeting is! Map || attendee is! Map) {
      throw const FormatException(
        'JoinInfo must contain meeting and attendee objects.',
      );
    }
    return JoinInfo(
      meeting: MeetingInfo.fromJson(Map<String, dynamic>.from(meeting)),
      attendee: AttendeeInfo.fromJson(Map<String, dynamic>.from(attendee)),
    );
  }

  /// Flattens the AWS response models into the method-channel wire format.
  Map<String, dynamic> toJson() => {
    'MeetingId': meeting.meetingId,
    'ExternalMeetingId': meeting.externalMeetingId,
    'MediaRegion': meeting.mediaRegion,
    'AudioHostUrl': meeting.mediaPlacement.audioHostUrl,
    'AudioFallbackUrl': meeting.mediaPlacement.audioFallbackUrl,
    'SignalingUrl': meeting.mediaPlacement.signalingUrl,
    'TurnControlUrl': meeting.mediaPlacement.turnControlUrl,
    'ExternalUserId': attendee.externalUserId,
    'AttendeeId': attendee.attendeeId,
    'JoinToken': attendee.joinToken,
  };

  /// Validates fields required by the native Chime SDK configuration.
  void validate() {
    final values = <String, String>{
      'MeetingId': meeting.meetingId,
      'ExternalMeetingId': meeting.externalMeetingId,
      'MediaRegion': meeting.mediaRegion,
      'AudioHostUrl': meeting.mediaPlacement.audioHostUrl,
      'AudioFallbackUrl': meeting.mediaPlacement.audioFallbackUrl,
      'SignalingUrl': meeting.mediaPlacement.signalingUrl,
      'TurnControlUrl': meeting.mediaPlacement.turnControlUrl,
      'ExternalUserId': attendee.externalUserId,
      'AttendeeId': attendee.attendeeId,
      'JoinToken': attendee.joinToken,
    };
    final missing = values.entries
        .where((entry) => entry.value.trim().isEmpty)
        .map((entry) => entry.key)
        .toList(growable: false);
    if (missing.isNotEmpty) {
      throw FormatException('JoinInfo is missing: ${missing.join(', ')}.');
    }
  }
}

class MeetingInfo {
  const MeetingInfo({
    required this.meetingId,
    required this.externalMeetingId,
    required this.mediaRegion,
    required this.mediaPlacement,
  });

  final String meetingId;
  final String externalMeetingId;
  final String mediaRegion;
  final MediaPlacement mediaPlacement;

  factory MeetingInfo.fromJson(Map<String, dynamic> json) => MeetingInfo(
    meetingId: _requiredString(json, 'MeetingId'),
    externalMeetingId: _requiredString(json, 'ExternalMeetingId'),
    mediaRegion: _requiredString(json, 'MediaRegion'),
    mediaPlacement: MediaPlacement.fromJson(
      _requiredMap(json, 'MediaPlacement'),
    ),
  );
}

class AttendeeInfo {
  const AttendeeInfo({
    required this.externalUserId,
    required this.attendeeId,
    required this.joinToken,
  });

  final String externalUserId;
  final String attendeeId;
  final String joinToken;

  factory AttendeeInfo.fromJson(Map<String, dynamic> json) => AttendeeInfo(
    externalUserId: _requiredString(json, 'ExternalUserId'),
    attendeeId: _requiredString(json, 'AttendeeId'),
    joinToken: _requiredString(json, 'JoinToken'),
  );
}

class MediaPlacement {
  const MediaPlacement({
    required this.audioHostUrl,
    required this.audioFallbackUrl,
    required this.signalingUrl,
    required this.turnControlUrl,
  });

  final String audioHostUrl;
  final String audioFallbackUrl;
  final String signalingUrl;
  final String turnControlUrl;

  factory MediaPlacement.fromJson(Map<String, dynamic> json) => MediaPlacement(
    audioHostUrl: _requiredString(json, 'AudioHostUrl'),
    audioFallbackUrl: _requiredString(json, 'AudioFallbackUrl'),
    signalingUrl: _requiredString(json, 'SignalingUrl'),
    turnControlUrl: _requiredString(json, 'TurnControlUrl'),
  );
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('Expected "$key" to be a string.');
  }
  return value;
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map) {
    throw FormatException('Expected "$key" to be an object.');
  }
  return Map<String, dynamic>.from(value);
}
