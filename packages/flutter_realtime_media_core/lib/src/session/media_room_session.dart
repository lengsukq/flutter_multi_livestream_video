import 'dart:async';

import '../client/media_backend_client.dart';
import '../client/media_backend_error.dart';
import '../model/media_error.dart';
import '../model/media_event.dart';
import '../model/media_recovery_status.dart';
import '../model/media_role.dart';
import '../model/media_room_participant_summary.dart';
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
    _eventSubscription = session.events.listen(_onSessionEvent);
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
  final StreamController<MediaRecoveryStatus> _recoveryController =
      StreamController<MediaRecoveryStatus>.broadcast();

  Timer? _heartbeatTimer;
  Timer? _initialHeartbeatTimer;
  StreamSubscription<MediaSessionState>? _stateSubscription;
  StreamSubscription<MediaEvent>? _eventSubscription;
  bool _leaveNotified = false;
  bool _disposed = false;
  Future<void>? _heartbeatFuture;
  Future<void>? _leaveNotificationFuture;
  Future<void>? _disposeFuture;
  Future<void>? _closeRoomFuture;
  int _recoveryAttempt = 0;
  int? _recoveryStartedAtMs;
  String? _recoveryReason;
  MediaRecoveryStatus? _recoveryStatus;

  /// Provider id of the underlying session.
  String get providerId => session.providerId;

  /// Role the session was created for.
  MediaRole get role => session.role;

  /// Latest media snapshot.
  MediaSnapshot get snapshot => session.snapshot;

  /// Backend presence failures (heartbeat, leave notification, ...).
  Stream<MediaBackendError> get backendErrors => _backendErrorController.stream;

  /// Latest reconnect/recovery status for this logical room session.
  MediaRecoveryStatus? get recoveryStatus => _recoveryStatus;

  /// Emits a normalized reconnect/recovered/failed lifecycle.
  Stream<MediaRecoveryStatus> get recoveries => _recoveryController.stream;

  /// Lists sanitized logical room participants. The backend remains the
  /// authority and rejects callers without room-management permission.
  Future<List<MediaRoomParticipantSummary>> listParticipants() => _backend
      .listRoomParticipants(roomCode, requesterParticipantId: participantId);

  /// Removes a participant when the backend/provider supports true moderation.
  Future<void> removeParticipant(String targetParticipantId) =>
      _backend.removeRoomParticipant(
        roomCode,
        requesterParticipantId: participantId,
        targetParticipantId: targetParticipantId,
      );

  /// Closes the logical room for future joins using backend-authoritative
  /// permissions.
  Future<void> closeRoom() {
    final current = _closeRoomFuture;
    if (current != null) return current;
    late final Future<void> future;
    future = _closeRoom().whenComplete(() {
      if (identical(_closeRoomFuture, future)) _closeRoomFuture = null;
    });
    _closeRoomFuture = future;
    return future;
  }

  Future<void> _closeRoom() async {
    if (_disposed || _leaveNotified) return;
    _stopHeartbeat();
    await _heartbeatFuture;
    try {
      await _backend.closeRoomAsParticipant(
        roomCode,
        requesterParticipantId: participantId,
      );
    } catch (_) {
      if (!_disposed && !_leaveNotified && !session.state.isTerminal) {
        _startHeartbeat();
      }
      rethrow;
    }

    // Closing a room supersedes the normal leave notification. Mark it before
    // disconnecting local media because terminal state callbacks also attempt
    // the best-effort leave path.
    _leaveNotified = true;
    try {
      await session.leave();
    } on MediaError {
      // The backend has already authoritatively closed the room. A local
      // adapter teardown failure must not turn a successful room close into a
      // misleading backend failure; dispose() will make one final cleanup pass.
    }
  }

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
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    try {
      await session.dispose();
    } on MediaError {
      // Disposal must stay safe even when the adapter already tore down.
    } finally {
      await _notifyLeaveBestEffort();
      await _backendErrorController.close();
      await _recoveryController.close();
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
      await _backend.heartbeat(roomCode, participantId: participantId);
    } on MediaBackendError catch (error) {
      _reportBackendError(error);
    }
  }

  void _onStateChanged(MediaSessionState state) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (state == MediaSessionState.reconnecting) {
      if (_recoveryStartedAtMs == null) {
        _recoveryAttempt++;
        _recoveryStartedAtMs = now;
      }
      _emitRecovery(
        MediaRecoveryStatus(
          phase: MediaRecoveryPhase.reconnecting,
          attempt: _recoveryAttempt,
          startedAtMs: _recoveryStartedAtMs!,
          updatedAtMs: now,
          reason: _recoveryReason,
        ),
      );
    } else if (state == MediaSessionState.connected &&
        _recoveryStartedAtMs != null) {
      _emitRecovery(
        MediaRecoveryStatus(
          phase: MediaRecoveryPhase.recovered,
          attempt: _recoveryAttempt,
          startedAtMs: _recoveryStartedAtMs!,
          updatedAtMs: now,
          reason: _recoveryReason,
        ),
      );
      _recoveryStartedAtMs = null;
      _recoveryReason = null;
    } else if (state.isTerminal && _recoveryStartedAtMs != null) {
      _emitRecovery(
        MediaRecoveryStatus(
          phase: MediaRecoveryPhase.failed,
          attempt: _recoveryAttempt,
          startedAtMs: _recoveryStartedAtMs!,
          updatedAtMs: now,
          reason: _recoveryReason,
        ),
      );
      _recoveryStartedAtMs = null;
      _recoveryReason = null;
    }
    if (state.isTerminal) {
      _stopHeartbeat();
      unawaited(_notifyLeaveBestEffort());
    }
  }

  void _onSessionEvent(MediaEvent event) {
    if (event is! MediaConnectionStateChanged) return;
    final reason = event.reason;
    if (reason == null) return;
    _recoveryReason = reason;
    final current = _recoveryStatus;
    if (current != null &&
        (event.current == MediaSessionState.reconnecting ||
            event.current == MediaSessionState.connected ||
            event.current.isTerminal)) {
      _emitRecovery(
        MediaRecoveryStatus(
          phase: current.phase,
          attempt: current.attempt,
          startedAtMs: current.startedAtMs,
          updatedAtMs: DateTime.now().millisecondsSinceEpoch,
          reason: reason,
        ),
      );
    }
  }

  void _emitRecovery(MediaRecoveryStatus status) {
    _recoveryStatus = status;
    if (!_recoveryController.isClosed) _recoveryController.add(status);
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
