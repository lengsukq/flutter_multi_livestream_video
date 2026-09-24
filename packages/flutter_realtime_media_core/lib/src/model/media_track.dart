/// Kind of media a track carries.
enum MediaTrackKind {
  audio,
  video,

  /// Screen share video published alongside or instead of camera video.
  screenShare,
}

/// Handle to a renderable video track.
///
/// The core package never imports a provider SDK. Adapters subclass this type
/// and keep the SDK-specific handle inside, then render it through a
/// `MediaTrackRenderer`.
abstract class MediaVideoTrack {
  const MediaVideoTrack();

  /// Provider track identifier, unique within a session.
  String get id;

  /// Participant that publishes this track.
  String get participantId;

  /// Whether the track belongs to the local participant.
  bool get isLocal;

  /// Whether this track is a screen share rather than a camera feed.
  bool get isScreenShare;

  /// Current frame width in pixels, or 0 when unknown.
  int get width;

  /// Current frame height in pixels, or 0 when unknown.
  int get height;

  /// Aspect ratio used by UI layout, defaulting to 16:9 while unknown.
  double get aspectRatio => width > 0 && height > 0 ? width / height : 16 / 9;

  @override
  String toString() =>
      'MediaVideoTrack($id, participant: $participantId, local: $isLocal, '
      'screenShare: $isScreenShare)';
}
