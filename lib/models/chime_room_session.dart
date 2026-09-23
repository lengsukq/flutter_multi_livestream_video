import 'dart:async';

import '../client/chime_backend_client.dart';
import 'chime_backend_exception.dart';
import 'chime_meeting_session.dart';
import 'meeting_snapshot.dart';

/// High-level room lifecycle returned by `ChimeClient`.
///
/// The underlying [session] remains the source of media state and controls.
/// This wrapper only adds backend presence lifecycle such as heartbeat and
/// best-effort leave notification.
class ChimeRoomSession {
  ChimeRoomSession._({
    required this.roomCode,
    required this.attendeeId,
    required this.session,
    required this._backend,
    required this._heartbeatInterval,
  }) {
    _stateSubscription = session.states.listen(_onMeetingState);
    _startHeartbeat();
  }

  static ChimeRoomSession attach({
    required String roomCode,
    required String attendeeId,
    required ChimeMeetingSession session,
    required ChimeBackendClient backend,
    required Duration heartbeatInterval,
  }) => ChimeRoomSession._(
    roomCode: roomCode,
    attendeeId: attendeeId,
    session: session,
    backend: backend,
    heartbeatInterval: heartbeatInterval,
  );

  final String roomCode;
  final String attendeeId;
  final ChimeMeetingSession session;
  final ChimeBackendClient _backend;
  final Duration _heartbeatInterval;
  final StreamController<ChimeBackendException> _backendErrorController =
      StreamController<ChimeBackendException>.broadcast();

  Timer? _heartbeatTimer;
  Timer? _initialHeartbeatTimer;
  StreamSubscription<MeetingState>? _stateSubscription;
  bool _leaveNotified = false;
  bool _disposed = false;
  Future<void>? _heartbeatFuture;
  Future<void>? _leaveNotificationFuture;
  Future<void>? _disposeFuture;

  Stream<ChimeBackendException> get backendErrors =>
      _backendErrorController.stream;

  Future<void> leave() async {
    if (_disposed) return;
    _stopHeartbeat();
    await session.leave();
    await _notifyLeaveBestEffort();
  }

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
    } on ChimeBackendException catch (error) {
      if (!_backendErrorController.isClosed) {
        _backendErrorController.add(error);
      }
    }
  }

  void _onMeetingState(MeetingState state) {
    if (state == MeetingState.ended ||
        state == MeetingState.failed ||
        state == MeetingState.disposed) {
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
      await _backend.leave(roomCode, attendeeId: attendeeId);
    } on ChimeBackendException catch (error) {
      if (!_backendErrorController.isClosed) {
        _backendErrorController.add(error);
      }
    }
  }
}
