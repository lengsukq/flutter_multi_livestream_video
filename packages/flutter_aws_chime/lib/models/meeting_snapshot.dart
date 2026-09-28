import 'audio_device.dart';

enum MeetingState {
  idle,
  joining,
  connecting,
  connected,
  reconnecting,
  leaving,
  ended,
  failed,
  disposed,
}

class MeetingSnapshot {
  MeetingSnapshot({
    this.state = MeetingState.idle,
    List<MeetingAttendee> attendees = const [],
    List<MeetingMessage> messages = const [],
    this.localAttendeeId,
    this.localMuted = true,
    this.localVideoEnabled = false,
    this.contentShareTile,
    List<ChimeAudioDevice> audioDevices = const [],
    this.selectedAudioDevice,
  }) : attendees = List.unmodifiable(attendees),
       messages = List.unmodifiable(messages),
       audioDevices = List.unmodifiable(audioDevices);

  final MeetingState state;
  final List<MeetingAttendee> attendees;
  final List<MeetingMessage> messages;
  final String? localAttendeeId;
  final bool localMuted;
  final bool localVideoEnabled;
  final MeetingVideoTile? contentShareTile;
  final List<ChimeAudioDevice> audioDevices;
  final ChimeAudioDevice? selectedAudioDevice;

  bool get isReceivingScreenShare => contentShareTile != null;

  MeetingAttendee? get localAttendee {
    for (final attendee in attendees) {
      if (attendee.attendeeId == localAttendeeId) return attendee;
    }
    return null;
  }

  MeetingSnapshot copyWith({
    MeetingState? state,
    List<MeetingAttendee>? attendees,
    List<MeetingMessage>? messages,
    String? localAttendeeId,
    bool clearLocalAttendeeId = false,
    bool? localMuted,
    bool? localVideoEnabled,
    MeetingVideoTile? contentShareTile,
    bool clearContentShareTile = false,
    List<ChimeAudioDevice>? audioDevices,
    ChimeAudioDevice? selectedAudioDevice,
    bool clearSelectedAudioDevice = false,
  }) => MeetingSnapshot(
    state: state ?? this.state,
    attendees: attendees ?? this.attendees,
    messages: messages ?? this.messages,
    localAttendeeId: clearLocalAttendeeId
        ? null
        : localAttendeeId ?? this.localAttendeeId,
    localMuted: localMuted ?? this.localMuted,
    localVideoEnabled: localVideoEnabled ?? this.localVideoEnabled,
    contentShareTile: clearContentShareTile
        ? null
        : contentShareTile ?? this.contentShareTile,
    audioDevices: audioDevices ?? this.audioDevices,
    selectedAudioDevice: clearSelectedAudioDevice
        ? null
        : selectedAudioDevice ?? this.selectedAudioDevice,
  );
}

class MeetingAttendee {
  const MeetingAttendee({
    required this.attendeeId,
    required this.externalUserId,
    this.isLocal = false,
    this.isMuted = false,
    this.isVideoEnabled = false,
    this.videoTile,
    this.joinedAt,
  });

  final String attendeeId;
  final String externalUserId;
  final bool isLocal;
  final bool isMuted;
  final bool isVideoEnabled;
  final MeetingVideoTile? videoTile;
  final DateTime? joinedAt;

  MeetingAttendee copyWith({
    bool? isMuted,
    bool? isVideoEnabled,
    MeetingVideoTile? videoTile,
    bool clearVideoTile = false,
  }) => MeetingAttendee(
    attendeeId: attendeeId,
    externalUserId: externalUserId,
    isLocal: isLocal,
    isMuted: isMuted ?? this.isMuted,
    isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
    videoTile: clearVideoTile ? null : videoTile ?? this.videoTile,
    joinedAt: joinedAt,
  );
}

class MeetingVideoTile {
  const MeetingVideoTile({
    required this.tileId,
    required this.attendeeId,
    required this.width,
    required this.height,
    required this.isLocal,
    required this.isContentShare,
  });

  final int tileId;
  final String attendeeId;
  final int width;
  final int height;
  final bool isLocal;
  final bool isContentShare;

  factory MeetingVideoTile.fromJson(Map<String, dynamic> json) =>
      MeetingVideoTile(
        tileId: _asInt(json['tileId']),
        attendeeId: json['attendeeId']?.toString() ?? '',
        width: _asInt(json['videoStreamContentWidth']),
        height: _asInt(json['videoStreamContentHeight']),
        isLocal: json['isLocalTile'] == true,
        isContentShare: json['isContent'] == true,
      );

  double get aspectRatio => width > 0 && height > 0 ? width / height : 16 / 9;
}

class MeetingMessage {
  const MeetingMessage({
    required this.attendeeId,
    required this.externalUserId,
    required this.message,
    required this.topic,
    required this.timestampMs,
    this.throttled = false,
  });

  final String attendeeId;
  final String externalUserId;
  final String message;
  final String topic;
  final int timestampMs;
  final bool throttled;

  factory MeetingMessage.fromJson(Map<String, dynamic> json) => MeetingMessage(
    attendeeId: json['attendeeId']?.toString() ?? '',
    externalUserId: json['externalUserId']?.toString() ?? '',
    message: json['message']?.toString() ?? '',
    topic: json['topic']?.toString() ?? 'chat',
    timestampMs: _asInt(json['timestampMs']),
    throttled: json['throttled'] == true,
  );
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
