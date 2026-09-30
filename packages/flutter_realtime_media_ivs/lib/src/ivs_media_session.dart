import 'package:flutter_realtime_video_effects/flutter_realtime_video_effects.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'ivs_engine.dart';
import 'ivs_join_info.dart';
import 'ivs_media_track.dart';

abstract class _IvsMediaSession
    implements
        MediaSession,
        MediaCredentialRefreshable,
        MediaStatsProvider,
        ProcessedVideoSink,
        MediaDeviceController {
  _IvsMediaSession({required this.role, required this.engineFactory})
    : _snapshot = MediaSnapshot(role: role);

  static _IvsMediaSession? _activeSession;
  final IvsEngineFactory engineFactory;
  final StreamController<MediaSessionState> _states =
      StreamController<MediaSessionState>.broadcast();
  final StreamController<MediaSnapshot> _snapshots =
      StreamController<MediaSnapshot>.broadcast();
  final StreamController<MediaEvent> _events =
      StreamController<MediaEvent>.broadcast();
  final StreamController<MediaConnectionStats> _stats =
      StreamController<MediaConnectionStats>.broadcast();

  IvsEngine? _engine;
  IvsJoinInfo? _joinInfo;
  MediaCredentialRefreshCallback? _refreshCallback;
  Timer? _refreshTimer;
  Timer? _statsTimer;
  Future<void>? _refreshFuture;
  MediaSessionState _state = MediaSessionState.idle;
  MediaSnapshot _snapshot;
  MediaConnectionStats? _connectionStats;
  MediaCameraPosition _cameraPosition = MediaCameraPosition.front;
  int _trackGeneration = 0;
  bool _disposed = false;

  @override
  final MediaRole role;
  bool _macEffectsInputAvailable = false;
  bool get _effectsPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          (defaultTargetPlatform == TargetPlatform.macOS &&
              _macEffectsInputAvailable));
  Future<void> _probeProcessedVideoInput() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return;
    try {
      _macEffectsInputAvailable =
          await MethodChannel(
            _processedSink.channelName,
          ).invokeMethod<bool>('probeProcessedVideoInput') ??
          false;
    } on MissingPluginException {
      _macEffectsInputAvailable = false;
    } on PlatformException {
      _macEffectsInputAvailable = false;
    }
  }

  final _processedSink = NativeProcessedVideoSink(
    providerId: 'ivs',
    channelName: 'com.oneplusdream.flutter_realtime_media_ivs/methods',
    attachMethod: 'attachProcessedVideoSource',
    detachMethod: 'detachProcessedVideoSource',
  );
  @override
  bool supportsProcessedVideoSource(ProcessedVideoSource source) =>
      capabilities.canPublishVideo &&
      _effectsPlatform &&
      _processedSink.supports(source) &&
      source.platform ==
          (defaultTargetPlatform == TargetPlatform.android
              ? VideoEffectsPlatform.android
              : VideoEffectsPlatform.macos);
  @override
  Future<void> attachProcessedVideoSource(ProcessedVideoSource source) async {
    _requireActive();
    if (!supportsProcessedVideoSource(source)) {
      throw MediaError(
        code: MediaErrorCode.unsupportedFeature,
        providerId: providerId,
        message:
            'Processed video input is unavailable for this role or platform.',
      );
    }
    await _processedSink.attach(source);
  }

  @override
  Future<void> detachProcessedVideoSource() => _processedSink.detach();

  @override
  Future<List<MediaDevice>> listMediaDevices({
    Set<MediaDeviceKind>? kinds,
  }) async {
    _requireActive();
    if (!capabilities.canEnumerateCameras ||
        (kinds != null && !kinds.contains(MediaDeviceKind.camera))) {
      return const [];
    }
    return List.unmodifiable([
      for (final camera in await VideoEffectsBridge().listCameras())
        MediaDevice(
          id: camera.id,
          label: camera.label,
          kind: MediaDeviceKind.camera,
        ),
    ]);
  }

  @override
  Future<void> selectMediaDevice(MediaDevice device) async {
    _requireActive();
    if (device.kind != MediaDeviceKind.camera ||
        !capabilities.canSelectCamera) {
      throw MediaError(
        code: MediaErrorCode.unsupportedFeature,
        providerId: providerId,
        message: 'This media device cannot be selected.',
      );
    }
    if (_processedSink.source == null) {
      throw MediaError(
        code: MediaErrorCode.invalidState,
        providerId: providerId,
        message: 'Prepare the SDK video source before selecting a camera.',
      );
    }
    await _processedSink.selectCamera(device.id);
  }

  @override
  String get providerId => IvsJoinInfo.providerIdValue;

  @override
  MediaCapabilities get capabilities {
    final publisher = role != MediaRole.viewer;
    return MediaCapabilities(
      canPublishAudio: publisher,
      canPublishVideo: publisher,
      canSwitchCamera:
          publisher && defaultTargetPlatform != TargetPlatform.macOS,
      canBlurBackground: publisher && _effectsPlatform,
      canReplaceBackgroundImage: publisher && _effectsPlatform,
      canEnumerateCameras: publisher && _effectsPlatform,
      canSelectCamera: publisher && _effectsPlatform,
      canSubscribeVideo: true,
      canReportNetworkStats: true,
      canListParticipants: role == MediaRole.host,
      canRemoveParticipants: role == MediaRole.host,
      canCloseRoom: role == MediaRole.host,
    );
  }

  @override
  MediaSessionState get state => _state;
  @override
  MediaSnapshot get snapshot => _snapshot;
  @override
  Stream<MediaSessionState> get states => _states.stream;
  @override
  Stream<MediaSnapshot> get snapshots => _snapshots.stream;
  @override
  Stream<MediaEvent> get events => _events.stream;
  @override
  MediaConnectionStats? get connectionStats => _connectionStats;
  @override
  Stream<MediaConnectionStats> get stats => _stats.stream;

  @override
  void setCredentialRefreshCallback(MediaCredentialRefreshCallback? callback) {
    _refreshCallback = callback;
    _scheduleCredentialRefresh();
  }

  @override
  Future<void> join(MediaJoinInfo joinInfo) async {
    if (_disposed || _state == MediaSessionState.disposed) {
      throw _error(
        MediaErrorCode.invalidState,
        'An IVS session cannot join after dispose.',
      );
    }
    if (_state == MediaSessionState.joining || _state.isActive) {
      throw _error(
        MediaErrorCode.invalidState,
        'This IVS session is already joining or active.',
      );
    }
    if (joinInfo is! IvsJoinInfo ||
        joinInfo.providerId != providerId ||
        joinInfo.role != role) {
      throw _error(
        MediaErrorCode.invalidJoinInfo,
        'IVS join information does not match this session.',
      );
    }
    if (_activeSession != null && !identical(_activeSession, this)) {
      throw _error(
        MediaErrorCode.sessionAlreadyActive,
        'The IVS Flutter bridge currently supports one active Stage per app process.',
      );
    }
    _activeSession = this;
    _joinInfo = joinInfo;
    _setState(MediaSessionState.joining);
    try {
      _engine ??= await engineFactory();
      _setState(MediaSessionState.connecting);
      await _engine!.join(joinInfo, _createEngineEvents());
      await _probeProcessedVideoInput();
      if (_disposed) return;
      final local = MediaParticipant(
        id: joinInfo.participantId,
        displayName: joinInfo.displayName.isEmpty
            ? joinInfo.participantId
            : joinInfo.displayName,
        isLocal: true,
        isMuted: true,
      );
      _setSnapshot(
        _snapshot.copyWith(
          participants: [local],
          localParticipantId: joinInfo.participantId,
          localMuted: true,
          localVideoEnabled: false,
          capabilities: capabilities,
          clearLastError: true,
        ),
      );
      _setState(MediaSessionState.connected);
      _scheduleCredentialRefresh();
      _startStatsPolling();
    } catch (error) {
      final mapped = _mapError(error, 'Unable to join the Amazon IVS Stage.');
      await _releaseEngine(leave: true);
      _activeSession = null;
      _setState(MediaSessionState.failed, error: mapped);
      throw mapped;
    }
  }

  @override
  Future<void> leave() async {
    if (_disposed ||
        _state == MediaSessionState.idle ||
        _state == MediaSessionState.ended) {
      return;
    }
    _refreshTimer?.cancel();
    _statsTimer?.cancel();
    _setState(MediaSessionState.leaving);
    await _releaseEngine(leave: true);
    _activeSession = null;
    _trackGeneration++;
    _setSnapshot(
      _snapshot.copyWith(
        participants: const [],
        messages: const [],
        clearLocalParticipantId: true,
        localMuted: true,
        localVideoEnabled: false,
        clearContentShareTrack: true,
      ),
    );
    _setState(MediaSessionState.ended);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    await leave();
    _disposed = true;
    _refreshTimer?.cancel();
    _statsTimer?.cancel();
    _refreshCallback = null;
    await _releaseEngine(leave: false);
    if (identical(_activeSession, this)) _activeSession = null;
    _setState(MediaSessionState.disposed);
    await _states.close();
    await _snapshots.close();
    await _events.close();
    await _stats.close();
  }

  IvsEngineEvents _createEngineEvents() => IvsEngineEvents(
    onError: _onNativeError,
    onParticipantJoined: _participantJoined,
    onParticipantLeft: _participantLeft,
    onRemoteVideoChanged: _remoteVideoChanged,
    onRemoteAudioChanged: _remoteAudioChanged,
    onReconnecting: () {
      if (_state == MediaSessionState.connected) {
        _setState(MediaSessionState.reconnecting);
      }
    },
    onRecovered: () {
      if (_state == MediaSessionState.reconnecting) {
        _setState(MediaSessionState.connected);
      }
    },
    onStats: _onStats,
  );

  void _participantJoined(String userId, String displayName) {
    if (userId.isEmpty || userId == _joinInfo?.participantId) return;
    final current = _participantById(userId);
    if (current != null) {
      if (displayName.isNotEmpty && displayName != current.displayName) {
        _setSnapshot(
          _snapshot.copyWith(
            participants: _snapshot.participants
                .map(
                  (item) => item.id == userId
                      ? item.copyWith(displayName: displayName)
                      : item,
                )
                .toList(),
          ),
        );
      }
      return;
    }
    final participant = MediaParticipant(
      id: userId,
      displayName: displayName.isEmpty ? userId : displayName,
      joinedAt: DateTime.now(),
    );
    _setSnapshot(
      _snapshot.copyWith(
        participants: [..._snapshot.participants, participant],
      ),
    );
    _events.add(MediaParticipantJoined(participant));
  }

  void _participantLeft(String userId) {
    final existing = _participantById(userId);
    if (existing == null || existing.isLocal) return;
    _setSnapshot(
      _snapshot.copyWith(
        participants: _snapshot.participants
            .where((item) => item.id != userId)
            .toList(),
      ),
    );
    _events.add(
      MediaParticipantLeft(
        participantId: userId,
        displayName: existing.displayName,
      ),
    );
  }

  void _remoteVideoChanged(String userId, bool available) {
    if (userId == _joinInfo?.participantId) return;
    _ensureRemoteParticipant(userId);
    final participants = _snapshot.participants.map((item) {
      if (item.id != userId) return item;
      final track = available
          ? IvsMediaVideoTrack(
              userId: userId,
              local: false,
              generation: _trackGeneration,
            )
          : null;
      return item.copyWith(
        isVideoEnabled: available,
        videoTrack: track,
        clearVideoTrack: !available,
      );
    }).toList();
    _setSnapshot(_snapshot.copyWith(participants: participants));
    if (available) {
      _events.add(
        MediaTrackPublished(
          participants.firstWhere((item) => item.id == userId).videoTrack!,
        ),
      );
    } else {
      _events.add(
        MediaTrackUnpublished(
          trackId: 'ivs:$userId:camera:$_trackGeneration',
          participantId: userId,
        ),
      );
    }
  }

  void _remoteAudioChanged(String userId, bool available) {
    if (userId == _joinInfo?.participantId) return;
    _ensureRemoteParticipant(userId);
    _setSnapshot(
      _snapshot.copyWith(
        participants: _snapshot.participants
            .map(
              (item) =>
                  item.id == userId ? item.copyWith(isMuted: !available) : item,
            )
            .toList(),
      ),
    );
    _events.add(
      MediaTrackMutedChanged(
        participantId: userId,
        muted: !available,
        kind: MediaTrackKind.audio,
      ),
    );
  }

  void _ensureRemoteParticipant(String userId) {
    if (_participantById(userId) == null) _participantJoined(userId, userId);
  }

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
    _stats.add(stats);
    _events.add(MediaNetworkStatsUpdated(stats));
  }

  void _onNativeError(int code, String message) {
    final error = MediaError(
      code: MediaErrorCode.nativeError,
      message: 'Amazon IVS reported an error: $message',
      details: {'code': code, 'message': message},
      providerId: providerId,
    );
    _setSnapshot(_snapshot.copyWith(lastError: error));
    _events.add(MediaFailureEvent(error));
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
    final callback = _refreshCallback;
    final current = _joinInfo;
    if (_disposed || callback == null || current == null || _engine == null) {
      return;
    }
    _refreshTimer?.cancel();
    try {
      final refreshed = _validateRefreshedInfo(
        current,
        await callback(current),
      );
      await _engine!.exchangeToken(refreshed.token);
      _joinInfo = refreshed;
      _scheduleCredentialRefresh();
    } catch (error) {
      final mapped = _mapError(error, 'Unable to refresh IVS credentials.');
      _setSnapshot(_snapshot.copyWith(lastError: mapped));
      _events.add(MediaFailureEvent(mapped));
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
      throw _error(
        MediaErrorCode.invalidJoinInfo,
        'IVS refreshed credentials changed the active stage or identity.',
      );
    }
    return refreshed;
  }

  void _scheduleCredentialRefresh() {
    _refreshTimer?.cancel();
    final info = _joinInfo;
    if (info == null ||
        _refreshCallback == null ||
        _state != MediaSessionState.connected) {
      return;
    }
    final delayMs =
        info.expiresAtMs - 30000 - DateTime.now().millisecondsSinceEpoch;
    _refreshTimer = Timer(
      Duration(milliseconds: delayMs > 0 ? delayMs : 0),
      () => unawaited(_refreshCredentials()),
    );
  }

  void _startStatsPolling() {
    _statsTimer?.cancel();
    if (!capabilities.canReportNetworkStats) return;
    _statsTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_state == MediaSessionState.connected && _engine != null) {
        unawaited(_engine!.requestStats());
      }
    });
  }

  Future<void> _setMuted(bool muted) async {
    _requireActive();
    _requireCapability(capabilities.canPublishAudio, 'publishing audio');
    await _engine!.setMuted(muted);
    _setSnapshot(_snapshot.copyWith(localMuted: muted));
    _events.add(MediaLocalMediaChanged(muted: muted));
  }

  Future<void> _setVideoEnabled(bool enabled) async {
    _requireActive();
    _requireCapability(capabilities.canPublishVideo, 'publishing video');
    await _processedSink.setEnabled(enabled);
    await _engine!.setVideoEnabled(enabled);
    final info = _joinInfo!;
    final track = enabled
        ? IvsMediaVideoTrack(
            userId: info.participantId,
            local: true,
            generation: _trackGeneration,
          )
        : null;
    _setSnapshot(
      _snapshot.copyWith(
        participants: _snapshot.participants
            .map(
              (item) => item.isLocal
                  ? item.copyWith(
                      isVideoEnabled: enabled,
                      videoTrack: track,
                      clearVideoTrack: !enabled,
                    )
                  : item,
            )
            .toList(),
        localVideoEnabled: enabled,
      ),
    );
    if (enabled) {
      _events.add(MediaTrackPublished(track!));
    } else {
      _events.add(
        MediaTrackUnpublished(
          trackId: 'ivs:${info.participantId}:camera:$_trackGeneration',
          participantId: info.participantId,
        ),
      );
    }
    _events.add(MediaLocalMediaChanged(videoEnabled: enabled));
  }

  Future<void> _switchCamera(MediaCameraPosition position) async {
    _requireActive();
    _requireCapability(capabilities.canSwitchCamera, 'switching cameras');
    if (_cameraPosition == position) return;
    if (_processedSink.source != null) {
      await _processedSink.selectCamera(
        position == MediaCameraPosition.front ? 'front' : 'back',
      );
    } else {
      await _engine!.switchCamera(position);
    }
    _cameraPosition = position;
    _trackGeneration++;
    final info = _joinInfo;
    if (_snapshot.localVideoEnabled && info != null) {
      final track = IvsMediaVideoTrack(
        userId: info.participantId,
        local: true,
        generation: _trackGeneration,
      );
      _setSnapshot(
        _snapshot.copyWith(
          participants: _snapshot.participants
              .map(
                (item) => item.isLocal
                    ? item.copyWith(videoTrack: track, isVideoEnabled: true)
                    : item,
              )
              .toList(),
        ),
      );
      _events.add(MediaTrackPublished(track));
    }
  }

  Future<void> _unsupported(String feature) async {
    throw _error(
      MediaErrorCode.unsupportedFeature,
      'Amazon IVS Real-Time does not expose $feature through the media adapter.',
    );
  }

  void _setState(MediaSessionState next, {MediaError? error}) {
    final previous = _state;
    if (previous == next && error == null) return;
    _state = next;
    _snapshot = _snapshot.copyWith(
      state: next,
      lastError: error,
      clearLastError: error == null,
    );
    _states.add(next);
    _snapshots.add(_snapshot);
    _events.add(MediaConnectionStateChanged(previous: previous, current: next));
    if (error != null) _events.add(MediaFailureEvent(error));
  }

  void _setSnapshot(MediaSnapshot next) {
    _snapshot = next;
    _snapshots.add(next);
  }

  MediaParticipant? _participantById(String id) {
    for (final participant in _snapshot.participants) {
      if (participant.id == id) return participant;
    }
    return null;
  }

  Future<void> _releaseEngine({required bool leave}) async {
    try {
      await _processedSink.detach();
    } catch (error) {
      if (!_events.isClosed) {
        _events.add(
          MediaFailureEvent(
            _mapError(error, 'Unable to detach the processed video input.'),
          ),
        );
      }
    }
    final engine = _engine;
    if (engine == null) return;
    if (leave) {
      try {
        await engine.leave();
      } catch (_) {}
    } else {
      try {
        await engine.dispose();
      } finally {
        _engine = null;
      }
    }
  }

  void _requireActive() {
    if (!_state.isActive || _engine == null) {
      throw _error(
        MediaErrorCode.invalidState,
        'IVS media controls require an active session.',
      );
    }
  }

  void _requireCapability(bool allowed, String feature) {
    if (!allowed) {
      throw _error(
        MediaErrorCode.unsupportedFeature,
        'IVS ${role.name} sessions do not support $feature.',
      );
    }
  }

  MediaError _mapError(Object error, String fallback) {
    if (error is MediaError) return error.withProvider(providerId);
    return MediaError(
      code: MediaErrorCode.unknown,
      message: error.toString().isEmpty ? fallback : error.toString(),
      providerId: providerId,
    );
  }

  MediaError _error(MediaErrorCode code, String message) =>
      MediaError(code: code, message: message, providerId: providerId);

  int? _asInt(Object? value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
  double? _asDouble(Object? value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');
}

class IvsParticipantSession extends _IvsMediaSession
    implements InteractiveMediaSession {
  IvsParticipantSession({required super.engineFactory})
    : super(role: MediaRole.participant);

  @override
  Future<void> setMuted(bool muted) => _setMuted(muted);
  @override
  Future<void> toggleMute() => setMuted(!snapshot.localMuted);
  @override
  Future<void> setVideoEnabled(bool enabled) => _setVideoEnabled(enabled);
  @override
  Future<void> switchCamera(MediaCameraPosition position) =>
      _switchCamera(position);
  @override
  Future<void> setScreenShareEnabled(bool enabled) =>
      _unsupported('screen sharing');
  @override
  Future<List<MediaAudioDevice>> listAudioDevices() async {
    await _unsupported('audio-output enumeration');
    return const [];
  }

  @override
  Future<void> selectAudioDevice(MediaAudioDevice device) =>
      _unsupported('audio-output selection');
  @override
  Future<void> sendMessage(String message, {String topic = 'chat'}) =>
      _unsupported('RTC data messaging; use a Chat Provider instead');
}

class IvsBroadcastHostSession extends _IvsMediaSession
    implements BroadcastHostSession {
  IvsBroadcastHostSession({required super.engineFactory})
    : super(role: MediaRole.host);

  @override
  Future<void> setMuted(bool muted) => _setMuted(muted);
  @override
  Future<void> toggleMute() => setMuted(!snapshot.localMuted);
  @override
  Future<void> setVideoEnabled(bool enabled) => _setVideoEnabled(enabled);
  @override
  Future<void> switchCamera(MediaCameraPosition position) =>
      _switchCamera(position);
  @override
  Future<void> setScreenShareEnabled(bool enabled) =>
      _unsupported('screen sharing');
  @override
  Future<List<MediaAudioDevice>> listAudioDevices() async {
    await _unsupported('audio-output enumeration');
    return const [];
  }

  @override
  Future<void> selectAudioDevice(MediaAudioDevice device) =>
      _unsupported('audio-output selection');
  @override
  Future<void> sendMessage(String message, {String topic = 'chat'}) =>
      _unsupported('RTC data messaging; use a Chat Provider instead');
}

class IvsBroadcastViewerSession extends _IvsMediaSession
    implements BroadcastViewerSession {
  IvsBroadcastViewerSession({required super.engineFactory})
    : super(role: MediaRole.viewer);

  @override
  Future<void> sendMessage(String message, {String topic = 'chat'}) =>
      _unsupported('RTC data messaging; use a Chat Provider instead');
}
