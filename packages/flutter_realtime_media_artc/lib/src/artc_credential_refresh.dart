part of 'artc_media_session.dart';

class _ArtcCredentialRefresh {
  _ArtcCredentialRefresh(this._session);
  final _ArtcMediaSession _session;
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

  Future<void> _refreshAndRejoin() {
    final current = _refreshFuture;
    if (current != null) return current;
    late final Future<void> future;
    future = _refreshAndRejoinOnce().whenComplete(() {
      if (identical(_refreshFuture, future)) _refreshFuture = null;
    });
    _refreshFuture = future;
    return future;
  }

  Future<void> _refreshAndRejoinOnce() async {
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
    if (_session._disposed || current == null || callback == null) {
      _session._onNativeError(
        -2,
        'ARTC credentials are expiring and no refresh callback is configured.',
      );
      return;
    }
    _refreshTimer?.cancel();
    _session._setState(MediaSessionState.reconnecting);
    try {
      final rawRefreshed = await callback(current);
      if (!currentLease()) return;
      final refreshed = _validateRefreshedInfo(current, rawRefreshed);
      final source = _session._publishing._processedSink.source;
      await _session._publishing._processedSink.detach();
      if (!currentLease()) return;
      await _session._engine!.leave();
      if (!currentLease()) return;
      _session._joinInfo = refreshed;
      _session._mapper._trackGeneration++;
      await _session._engine!.join(
        refreshed,
        _session._mapper._createEngineEvents(),
      );
      if (!currentLease()) return;
      await _session._publishing._probeProcessedVideoInput();
      if (!currentLease()) return;
      if (source != null) {
        await _session._publishing._processedSink.attach(source);
        if (!currentLease()) return;
        await _session._engine!.setVideoEnabled(
          _session._snapshot.localVideoEnabled,
        );
        if (!currentLease()) return;
      }
      _session._setSnapshot(_session._snapshot.copyWith(clearLastError: true));
      _session._setState(MediaSessionState.connected);
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
      _session._setState(MediaSessionState.failed, error: mapped);
      await _session._releaseEngine(leave: true);
      if (identical(_activeArtcSession, _session)) _activeArtcSession = null;
    }
  }

  ArtcJoinInfo _validateRefreshedInfo(
    MediaJoinInfo current,
    MediaJoinInfo refreshed,
  ) {
    if (current is! ArtcJoinInfo ||
        refreshed is! ArtcJoinInfo ||
        refreshed.providerId != current.providerId ||
        refreshed.roomCode != current.roomCode ||
        refreshed.participantId != current.participantId ||
        refreshed.userId != current.userId ||
        refreshed.channelId != current.channelId ||
        refreshed.appId != current.appId ||
        refreshed.role != current.role) {
      throw _session._error(
        RealtimeErrorCode.invalidArgument,
        'ARTC refresh credentials changed the active room or identity.',
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
      () => unawaited(_refreshAndRejoin()),
    );
  }
}
