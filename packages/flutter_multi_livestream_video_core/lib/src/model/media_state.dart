/// Connection lifecycle shared by every media provider adapter.
///
/// The state machine matches the Chime v3 session states so that a Chime
/// adapter can map onto it without inventing new transitions.
enum MediaSessionState {
  /// No connection has been attempted yet.
  idle,

  /// [MediaSession.join] is running (credentials parsed, permissions pending).
  joining,

  /// Transport is being established.
  connecting,

  /// Media is flowing.
  connected,

  /// The transport dropped and the adapter is trying to restore it.
  reconnecting,

  /// [MediaSession.leave] is running.
  leaving,

  /// The session ended normally and may be joined again.
  ended,

  /// The session could not be established or was terminated by an error.
  failed,

  /// [MediaSession.dispose] released the session resources.
  disposed;

  /// Whether media operations such as mute or camera control are allowed.
  bool get isActive =>
      this == MediaSessionState.connecting ||
      this == MediaSessionState.connected ||
      this == MediaSessionState.reconnecting;

  /// Whether the session will not become active again without a new join.
  bool get isTerminal =>
      this == MediaSessionState.ended ||
      this == MediaSessionState.failed ||
      this == MediaSessionState.disposed;
}
