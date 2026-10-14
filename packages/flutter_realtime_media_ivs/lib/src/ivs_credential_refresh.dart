part of 'ivs_media_session.dart';

class _IvsCredentialRefresh {
  _IvsCredentialRefresh(this._session);
  final _IvsMediaSession _session;
  String get providerId => _session.providerId;
  MediaCapabilities get capabilities => _session.capabilities;
  MediaRole get role => _session.role;
  MediaSessionState get state => _session.state;
  MediaSnapshot get snapshot => _session.snapshot;
  Duration get cleanupTimeout => _session.cleanupTimeout;
  void cancel() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void>? _disposeFuture;
  Future<void> dispose() => _disposeFuture ??= Future<void>.sync(() {
    cancel();
    _refreshCallback = null;
  });
  Future<void>? _refreshFuture;
  Timer? _refreshTimer;
  MediaCredentialRefreshCallback? _refreshCallback;
  void setCredentialRefreshCallback(MediaCredentialRefreshCallback? callback) {
    _refreshCallback = callback;
    _scheduleCredentialRefresh();
  }

  Future<void> _refreshCredentials() {
    final current = _refreshFuture;
    if (current != null) return current;
    late final Future<void> future;
    future = _refreshCredentialsOnce().whenComplete(() {
      if (identical(_refreshFuture, future)) _refreshFuture = null;
    });
    _refreshFuture = future;
    return future;
  }

  Future<void> _refreshCredentialsOnce() async {
    final generation = _session._connectionGeneration;
    final engine = _session._engine;
    bool currentLease() =>
        generation == _session._connectionGeneration &&
        identical(engine, _session._engine) &&
        !_session._disposed &&
        !state.isTerminal &&
        state != MediaSessionState.leaving;
    if (!currentLease() || engine == null) return;
    final callback = _refreshCallback;
    final current = _session._joinInfo;
    if (_session._disposed ||
        callback == null ||
        current == null ||
        _session._engine == null) {
      return;
    }
    _refreshTimer?.cancel();
    try {
      final refreshed = _validateRefreshedInfo(
        current,
        await callback(current),
      );
      if (!currentLease()) return;
      await engine.exchangeToken(refreshed.token);
      if (!currentLease()) return;
      _session._joinInfo = refreshed;
      _scheduleCredentialRefresh();
    } catch (error, stack) {
      if (!currentLease()) return;
      final mapped = _session._mapError(
        error,
        'refreshCredentials',
        stack: stack,
      );
      _session._setSnapshot(_session._snapshot.copyWith(lastError: mapped));
      _session._emit(MediaFailureEvent(mapped));
    }
  }

  IvsJoinInfo _validateRefreshedInfo(
    IvsJoinInfo current,
    MediaJoinInfo refreshed,
  ) {
    if (refreshed is! IvsJoinInfo ||
        refreshed.providerId != current.providerId ||
        refreshed.roomCode != current.roomCode ||
        refreshed.participantId != current.participantId ||
        refreshed.stageArn != current.stageArn ||
        refreshed.role != current.role) {
      throw _session._error(
        RealtimeErrorCode.invalidArgument,
        'IVS refreshed credentials changed the active stage or identity.',
      );
    }
    return refreshed;
  }

  void _scheduleCredentialRefresh() {
    _refreshTimer?.cancel();
    final info = _session._joinInfo;
    if (info == null ||
        _refreshCallback == null ||
        _session._state != MediaSessionState.connected) {
      return;
    }
    final delayMs =
        info.expiresAtMs - 30000 - DateTime.now().millisecondsSinceEpoch;
    _refreshTimer = Timer(
      Duration(milliseconds: delayMs > 0 ? delayMs : 0),
      () => unawaited(_refreshCredentials()),
    );
  }
}
