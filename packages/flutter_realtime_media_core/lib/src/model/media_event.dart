import 'media_error.dart';
import 'media_message.dart';
import 'media_participant.dart';
import 'media_state.dart';
import 'media_track.dart';

/// Base type for events emitted by a media session.
///
/// Events are additive detail on top of snapshots: a UI can be built from
/// snapshots alone, while events drive logs, analytics, and transient effects.
sealed class MediaEvent {
  const MediaEvent();

  /// Session state this event belongs to, when it is state related.
  MediaSessionState? get state => null;
}

/// The session moved to a new lifecycle state.
class MediaConnectionStateChanged extends MediaEvent {
  const MediaConnectionStateChanged({
    required this.previous,
    required this.current,
    this.reason,
  });

  final MediaSessionState previous;
  final MediaSessionState current;

  /// Optional provider detail, for example `audioDropped`.
  final String? reason;

  @override
  MediaSessionState get state => current;

  @override
  String toString() =>
      'MediaConnectionStateChanged(${previous.name} -> ${current.name}'
      '${reason == null ? '' : ', reason: $reason'})';
}

/// A remote participant joined the session.
class MediaParticipantJoined extends MediaEvent {
  const MediaParticipantJoined(this.participant);

  final MediaParticipant participant;

  @override
  String toString() => 'MediaParticipantJoined(${participant.id})';
}

/// A participant left the session.
class MediaParticipantLeft extends MediaEvent {
  const MediaParticipantLeft({required this.participantId, this.displayName});

  final String participantId;
  final String? displayName;

  @override
  String toString() => 'MediaParticipantLeft($participantId)';
}

/// A participant started publishing a video track.
class MediaTrackPublished extends MediaEvent {
  const MediaTrackPublished(this.track);

  final MediaVideoTrack track;

  @override
  String toString() => 'MediaTrackPublished(${track.id})';
}

/// A participant stopped publishing a video track.
class MediaTrackUnpublished extends MediaEvent {
  const MediaTrackUnpublished({
    required this.trackId,
    required this.participantId,
    this.wasScreenShare = false,
  });

  final String trackId;
  final String participantId;
  final bool wasScreenShare;

  @override
  String toString() =>
      'MediaTrackUnpublished($trackId, participant: $participantId)';
}

/// A track was muted or unmuted without being unpublished.
class MediaTrackMutedChanged extends MediaEvent {
  const MediaTrackMutedChanged({
    required this.participantId,
    required this.muted,
    this.trackId,
    this.kind = MediaTrackKind.video,
  });

  final String participantId;
  final String? trackId;
  final bool muted;
  final MediaTrackKind kind;

  @override
  String toString() =>
      'MediaTrackMutedChanged($participantId, ${kind.name}, muted: $muted)';
}

/// Local microphone or camera state changed.
class MediaLocalMediaChanged extends MediaEvent {
  const MediaLocalMediaChanged({this.muted, this.videoEnabled});

  final bool? muted;
  final bool? videoEnabled;

  @override
  String toString() =>
      'MediaLocalMediaChanged(muted: $muted, video: $videoEnabled)';
}

/// A remote participant started or stopped speaking.
class MediaSpeakingChanged extends MediaEvent {
  const MediaSpeakingChanged({
    required this.participantId,
    required this.isSpeaking,
  });

  final String participantId;
  final bool isSpeaking;

  @override
  String toString() =>
      'MediaSpeakingChanged($participantId, speaking: $isSpeaking)';
}

/// A data message arrived from a participant.
class MediaMessageReceived extends MediaEvent {
  const MediaMessageReceived(this.message);

  final MediaMessage message;

  @override
  String toString() => 'MediaMessageReceived(${message.topic})';
}

/// The session reported a failure. The session may still be usable depending
/// on the error code; `MediaSnapshot.lastError` carries the same value.
class MediaFailureEvent extends MediaEvent {
  const MediaFailureEvent(this.error);

  final MediaError error;

  @override
  String toString() => 'MediaFailureEvent(${error.code.name})';
}
