import 'media_capabilities.dart';
import 'media_error.dart';
import 'media_message.dart';
import 'media_participant.dart';
import 'media_role.dart';
import 'media_state.dart';
import 'media_track.dart';

/// Immutable view of everything a session currently knows.
///
/// Adapters publish a new snapshot through `MediaSession.snapshots` whenever
/// anything changes. Late subscribers read the current value from
/// `MediaSession.snapshot`.
class MediaSnapshot {
  MediaSnapshot({
    this.state = MediaSessionState.idle,
    this.role = MediaRole.participant,
    List<MediaParticipant> participants = const [],
    List<MediaMessage> messages = const [],
    this.localParticipantId,
    this.localMuted = true,
    this.localVideoEnabled = false,
    this.contentShareTrack,
    this.capabilities = const MediaCapabilities.none(),
    this.lastError,
  }) : participants = List.unmodifiable(participants),
       messages = List.unmodifiable(messages);

  /// Current lifecycle state.
  final MediaSessionState state;

  /// Role requested when joining.
  final MediaRole role;

  /// Known participants, including the local one.
  final List<MediaParticipant> participants;

  /// Received data messages, oldest first.
  final List<MediaMessage> messages;

  /// Local participant id, when the provider assigned one.
  final String? localParticipantId;

  /// Whether the local microphone is muted.
  final bool localMuted;

  /// Whether the local camera is publishing.
  final bool localVideoEnabled;

  /// Screen share track currently received, if any.
  final MediaVideoTrack? contentShareTrack;

  /// Declared capabilities for this session.
  final MediaCapabilities capabilities;

  /// Most recent failure, cleared on a successful join.
  final MediaError? lastError;

  /// Whether a remote screen share is being received.
  bool get isReceivingScreenShare => contentShareTrack != null;

  /// Remote participants only, in provider order.
  List<MediaParticipant> get remoteParticipants =>
      participants.where((item) => !item.isLocal).toList(growable: false);

  /// The local participant, when present in [participants].
  MediaParticipant? get localParticipant {
    for (final participant in participants) {
      if (participant.isLocal) return participant;
    }
    return null;
  }

  MediaSnapshot copyWith({
    MediaSessionState? state,
    MediaRole? role,
    List<MediaParticipant>? participants,
    List<MediaMessage>? messages,
    String? localParticipantId,
    bool clearLocalParticipantId = false,
    bool? localMuted,
    bool? localVideoEnabled,
    MediaVideoTrack? contentShareTrack,
    bool clearContentShareTrack = false,
    MediaCapabilities? capabilities,
    MediaError? lastError,
    bool clearLastError = false,
  }) => MediaSnapshot(
    state: state ?? this.state,
    role: role ?? this.role,
    participants: participants ?? this.participants,
    messages: messages ?? this.messages,
    localParticipantId: clearLocalParticipantId
        ? null
        : localParticipantId ?? this.localParticipantId,
    localMuted: localMuted ?? this.localMuted,
    localVideoEnabled: localVideoEnabled ?? this.localVideoEnabled,
    contentShareTrack: clearContentShareTrack
        ? null
        : contentShareTrack ?? this.contentShareTrack,
    capabilities: capabilities ?? this.capabilities,
    lastError: clearLastError ? null : lastError ?? this.lastError,
  );
}
