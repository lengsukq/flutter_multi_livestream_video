part of 'ivs_media_session.dart';

class _IvsStatistics {
  _IvsStatistics(this._session);
  final _IvsMediaSession _session;
  String get providerId => _session.providerId;
  MediaCapabilities get capabilities => _session.capabilities;
  MediaRole get role => _session.role;
  MediaSessionState get state => _session.state;
  MediaSnapshot get snapshot => _session.snapshot;
  Duration get cleanupTimeout => _session.cleanupTimeout;
  void stop() {
    _statsTimer?.cancel();
    _statsTimer = null;
  }

  Future<void>? _disposeFuture;
  Future<void> dispose() => _disposeFuture ??= _dispose();
  Future<void> _dispose() async {
    stop();
    await _stats.close();
  }

  final StreamController<MediaConnectionStats> _stats =
      StreamController<MediaConnectionStats>.broadcast();
  MediaConnectionStats? _connectionStats;
  Timer? _statsTimer;
  void _onStats(Map<String, Object?> raw) {
    final stats = MediaConnectionStats(
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      rttMs: _asInt(raw['rttMs']),
      uplinkPacketLossPercent: _asDouble(raw['uplinkPacketLossPercent']),
      downlinkPacketLossPercent: _asDouble(raw['downlinkPacketLossPercent']),
      uploadKbps: _asInt(raw['uploadKbps']),
      downloadKbps: _asInt(raw['downloadKbps']),
      jitterMs: _asInt(raw['jitterMs']),
    );
    _connectionStats = stats;
    if (!_session._disposed && !_stats.isClosed) _stats.add(stats);
    _session._emit(MediaNetworkStatsUpdated(stats));
  }

  void _startStatsPolling() {
    _statsTimer?.cancel();
    if (!capabilities.canReportNetworkStats) return;
    _statsTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_session._state == MediaSessionState.connected &&
          _session._engine != null) {
        final engine = _session._engine!;
        final generation = _session._connectionGeneration;
        unawaited(
          engine.requestStats().catchError((Object error, StackTrace stack) {
            if (!_session._disposed &&
                generation == _session._connectionGeneration &&
                identical(engine, _session._engine) &&
                _session._state == MediaSessionState.connected) {
              final mapped = _session._mapError(
                error,
                'requestStats',
                stack: stack,
              );
              _session._setSnapshot(
                _session._snapshot.copyWith(lastError: mapped),
              );
              _session._emit(MediaFailureEvent(mapped));
            }
          }),
        );
      }
    });
  }

  int? _asInt(Object? value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
  double? _asDouble(Object? value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');
}
