part of 'media_room_session.dart';

class _RoomRecovery {
  final _recoveryController = StreamController<MediaRecoveryStatus>.broadcast();
  Future<void>? _disposeFuture;
  int _recoveryAttempt = 0;
  int? _recoveryStartedAtMs;
  String? _recoveryReason;
  MediaRecoveryStatus? _recoveryStatus;
  MediaRecoveryStatus? get status => _recoveryStatus;
  Stream<MediaRecoveryStatus> get stream => _recoveryController.stream;
  Future<void> dispose() => _disposeFuture ??= _recoveryController.close();
  void onState(MediaSessionState state) {
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
  }

  void onEvent(MediaEvent event) {
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
}
