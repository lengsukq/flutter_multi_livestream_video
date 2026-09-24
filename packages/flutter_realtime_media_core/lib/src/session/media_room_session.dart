import 'dart:async';

import '../client/media_backend_client.dart';
import '../client/media_backend_error.dart';
import '../model/media_error.dart';
import '../model/media_role.dart';
import '../model/media_snapshot.dart';
import '../model/media_state.dart';
import 'media_session.dart';

/// High-level room lifecycle returned by `MediaClient`.
///
/// The underlying [session] stays the source of media state and controls. This
/// wrapper only adds backend presence: heartbeat while the media session is
/// alive and a best-effort leave notification.
///
/// Backend presence failures are reported on [backendErrors] and never stop
/// healthy media, exactly like the Chime `ChimeRoomSession`.
class MediaRoomSession {
  MediaRoomSession._(
    this._backend,
    this._heartbeatInterval, {
    required this.roomCode,
    required this.participantId,
    required this.session,
  }) {
    _stateSubscription = session.states.listen(_onStateChanged);
    _startHeartbeat();
  }

  /// Attaches backend presence handling to an already joined [session].
  static MediaRoomSession attach({
    required String roomCode,
    required String participantId,
    required MediaSession session,
    required MediaBackendClient backend,
    required Duration heartbeatInterval,
  }) => MediaRoomSession._(
    backend,
    heartbeatInterval,
    roomCode: roomCode,
    participantId: participantId,
    session: session,
  );

  final String roomCode;
  final String participantId;
  final MediaSession session;
  final MediaBackendClient _backend;
  final Duration _heartbeatInterval;
  final StreamController<MediaBackendError> _backendErrorController =
      StreamController<MediaBackendError>.broadcast();

  Timer? _heartbeatTimer;
  Timer? _initialHeartbeatTimer;
  StreamSubscription<MediaSessionState>? _stateSubscription;
  bool _leaveNotified = false;
  bool _disposed = false;
  Future<void>? _heartbeatFuture;
  Future<void>? _leaveNotificationFuture;
  Future<void>? _disposeFuture;

  /// Provider id of the underlying session.
  String get providerId => session.providerId;

  /// Role the session was created for.
  MediaRole get role => session.role;

  /// Latest media snapshot.
  MediaSnapshot get snapshot => session.snapshot;

  /// Backend presence failures (heartbeat, leave notification, ...).
  Stream<MediaBackendError> get backendErrors => _backendErrorController.stream;

  /// Leaves the media session and notifies the backend (best effort).
  Future<void> leave() async {
    if (_disposed) return;
    _stopHeartbeat();
    await session.leave();
    await _notifyLeaveBestEffort();
  }

  /// Disposes the media session and this wrapper. Safe to call repeatedly.
  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    if (_disposed) return;
    _disposed = true;
    _stopHeartbeat();
    await _heartbeatFuture;
    await _stateSubscription?.cancel();
    _stateSubscription = null;
    try {
      await session.dispose();
    } on MediaError {
      // Disposal must stay safe even when the adapter already tore down.
    } finally {
      await _notifyLeaveBestEffort();
      await _backendErrorController.close();
    }
  }

  void _startHeartbeat() {
    if (_heartbeatInterval <= Duration.zero) return;
    _initialHeartbeatTimer = Timer(
      Duration.zero,
      () => unawaited(_heartbeat()),
    );
    _heartbeatTimer = Timer.periodic(
      _heartbeatInterval,
      (_) => unawaited(_heartbeat()),
    );
  }

  void _stopHeartbeat() {
    _initialHeartbeatTimer?.cancel();
    _initialHeartbeatTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _heartbeat() {
    if (_disposed || _leaveNotified) return Future<void>.value();
    final current = _heartbeatFuture;
    if (current != null) return current;
    late final Future<void> future;
    future = _sendHeartbeat().whenComplete(() {
      if (identical(_heartbeatFuture, future)) _heartbeatFuture = null;
    });
    _heartbeatFuture = future;
    return future;
  }

  Future<void> _sendHeartbeat() async {
    try {
      await _backend.heartbeat(roomCode);
    } on MediaBackendError catch (error) {
      _reportBackendError(error);
    }
  }

  void _onStateChanged(MediaSessionState state) {
    if (state.isTerminal) {
      _stopHeartbeat();
      unawaited(_notifyLeaveBestEffort());
    }
  }

  Future<void> _notifyLeaveBestEffort() {
    final current = _leaveNotificationFuture;
    if (current != null) return current;
    if (_leaveNotified) return Future<void>.value();
    _leaveNotified = true;
    late final Future<void> future;
    future = _sendLeaveBestEffort().whenComplete(() {
      if (identical(_leaveNotificationFuture, future)) {
        _leaveNotificationFuture = null;
      }
    });
    _leaveNotificationFuture = future;
    return future;
  }

  Future<void> _sendLeaveBestEffort() async {
    try {
      await _backend.leave(roomCode, participantId: participantId);
    } on MediaBackendError catch (error) {
      _reportBackendError(error);
    }
  }

  void _reportBackendError(MediaBackendError error) {
    if (!_backendErrorController.isClosed) {
      _backendErrorController.add(error);
    }
  }
}
