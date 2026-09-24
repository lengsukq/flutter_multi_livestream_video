import 'media_track.dart';

/// Participant of a media session, provider-neutral.
class MediaParticipant {
  const MediaParticipant({
    required this.id,
    required this.displayName,
    this.isLocal = false,
    this.isMuted = false,
    this.isVideoEnabled = false,
    this.isSpeaking = false,
    this.videoTrack,
    this.joinedAt,
  });

  /// Provider participant identifier (Chime attendee id, LiveKit identity, ...).
  final String id;

  /// Human-readable name shown in UI. Falls back to [id] when unavailable.
  final String displayName;

  /// Whether this participant is the local user.
  final bool isLocal;

  /// Whether the participant's audio is currently muted.
  final bool isMuted;

  /// Whether the participant currently publishes camera video.
  final bool isVideoEnabled;

  /// Whether the provider currently reports active speech.
  final bool isSpeaking;

  /// Camera (or screen share) track to render for this participant, if any.
  final MediaVideoTrack? videoTrack;

  /// When the participant was first observed, when known.
  final DateTime? joinedAt;

  MediaParticipant copyWith({
    String? displayName,
    bool? isMuted,
    bool? isVideoEnabled,
    bool? isSpeaking,
    MediaVideoTrack? videoTrack,
    bool clearVideoTrack = false,
  }) => MediaParticipant(
    id: id,
    displayName: displayName ?? this.displayName,
    isLocal: isLocal,
    isMuted: isMuted ?? this.isMuted,
    isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
    isSpeaking: isSpeaking ?? this.isSpeaking,
    videoTrack: clearVideoTrack ? null : videoTrack ?? this.videoTrack,
    joinedAt: joinedAt,
  );

  @override
  String toString() =>
      'MediaParticipant($id, name: $displayName, local: $isLocal, '
      'muted: $isMuted, video: $isVideoEnabled)';
}
