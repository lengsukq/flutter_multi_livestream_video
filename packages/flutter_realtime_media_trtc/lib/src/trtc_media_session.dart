import 'dart:async';
import 'dart:convert';

import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'trtc_engine.dart';
import 'trtc_join_info.dart';
import 'trtc_media_track.dart';

MediaCapabilities _publisherCapabilities(MediaRole role) => MediaCapabilities(
  canPublishAudio: true,
  canPublishVideo: true,
  canSwitchCamera: true,
  canSendData: true,
  canSubscribeVideo: true,
  canReportNetworkStats: true,
  maxDataMessageBytes: 1024,
  canListParticipants: role == MediaRole.host,
  canCloseRoom: role == MediaRole.host,
);
const _viewerCapabilities = MediaCapabilities(
  canSubscribeVideo: true,
  canSendData: false,
  canReportNetworkStats: true,
);
const _customMessageCommandId = 1;
const _userSigCheckFailed = -100018;

Object? _activeTrtcSession;

/// Shared TRTC room lifecycle exposed for provider-specific integrations.
abstract class TrtcMediaSession
    implements MediaSession, MediaCredentialRefreshable {}

/// TRTC meeting participant with symmetric publish and subscribe controls.
class TrtcParticipantSession extends _TrtcInteractiveSession {
  TrtcParticipantSession({
    TrtcEngineFactory engineFactory = createNativeTrtcEngine,
  }) : super(MediaRole.participant, engineFactory);
}

/// TRTC live-stream publisher. Screen sharing and device enumeration are not
/// part of this adapter's first release.
class TrtcHostSession extends _TrtcInteractiveSession
    implements BroadcastHostSession {
  TrtcHostSession({TrtcEngineFactory engineFactory = createNativeTrtcEngine})
    : super(MediaRole.host, engineFactory);
}

/// Subscribe-only TRTC audience session.
class TrtcViewerSession extends _TrtcSessionBase
    implements BroadcastViewerSession {
  TrtcViewerSession({TrtcEngineFactory engineFactory = createNativeTrtcEngine})
    : super(MediaRole.viewer, _viewerCapabilities, engineFactory);

  @override
  Future<void> sendMessage(String message, {String topic = 'chat'}) =>
      _sendMessage(message, topic: topic);
}

abstract class _TrtcSessionBase
    implements TrtcMediaSession, MediaStatsProvider, MediaDataPayloadSizer {
  _TrtcSessionBase(this.role, this._capabilities, this._engineFactory)
    : _snapshot = MediaSnapshot(role: role, capabilities: _capabilities);

  @override
  String get providerId => TrtcJoinInfo.providerIdValue;

  @override
  final MediaRole role;

  final MediaCapabilities _capabilities;
  final TrtcEngineFactory _engineFactory;
  MediaSnapshot _snapshot;
  TrtcEngine? _engine;
  TrtcJoinInfo? _joinInfo;
  MediaCredentialRefreshCallback? _refreshCallback;
  Future<void>? _joinFuture;
  Future<void>? _leaveFuture;
  Future<void>? _disposeFuture;
  Future<void>? _refreshFuture;
  Timer? _refreshTimer;
  bool _enterRequested = false;
  bool _disposed = false;
  int _streamGeneration = 0;

  final _stateController = StreamController<MediaSessionState>.broadcast();
  final _snapshotController = StreamController<MediaSnapshot>.broadcast();
  final _eventController = StreamController<MediaEvent>.broadcast();
  final _statsController = StreamController<MediaConnectionStats>.broadcast();
  MediaConnectionStats? _connectionStats;

  @override
  MediaCapabilities get capabilities => _capabilities;

  @override
  MediaSessionState get state => _snapshot.state;

  @override
  MediaSnapshot get snapshot => _snapshot;

  @override
  Stream<MediaSessionState> get states => _stateController.stream;

  @override
  Stream<MediaSnapshot> get snapshots => _snapshotController.stream;

  @override
  Stream<MediaEvent> get events => _eventController.stream;

  @override
  MediaConnectionStats? get connectionStats => _connectionStats;

  @override
  Stream<MediaConnectionStats> get stats => _statsController.stream;

  @override
  void setCredentialRefreshCallback(MediaCredentialRefreshCallback? callback) {
    _refreshCallback = callback;
    if (callback == null) _refreshTimer?.cancel();
    if (callback != null && state == MediaSessionState.connected) {
      _scheduleCredentialRefresh();
    }
  }

  @override
  int dataPayloadSizeBytes(String message, MediaSendOptions options) => utf8
      .encode(
        jsonEncode({'topic': options.topic.trim(), 'message': message.trim()}),
      )
      .length;

  @override
  Future<void> join(MediaJoinInfo joinInfo) {
    final current = _joinFuture;
    if (current != null) return current;
    late final Future<void> future;
    future = _join(joinInfo).whenComplete(() {
      if (identical(_joinFuture, future)) _joinFuture = null;
    });
    _joinFuture = future;
    return future;
  }

  Future<void> _join(MediaJoinInfo rawInfo) async {
    _ensureNotDisposed();
    if (state != MediaSessionState.idle &&
        state != MediaSessionState.ended &&
        state != MediaSessionState.failed) {
      throw MediaError(
        code: MediaErrorCode.invalidState,
        message: 'This TRTC session is already joining or active.',
        providerId: providerId,
      );
    }
    if (rawInfo is! TrtcJoinInfo ||
        rawInfo.providerId != providerId ||
        rawInfo.role != role ||
        rawInfo.participantId != rawInfo.userId) {
      throw MediaError(
        code: MediaErrorCode.invalidJoinInfo,
        message: 'Join information does not match this TRTC session.',
        providerId: providerId,
      );
    }
    if (_activeTrtcSession != null && !identical(_activeTrtcSession, this)) {
      throw MediaError(
        code: MediaErrorCode.sessionAlreadyActive,
        message: 'Another TRTC session is already using the native engine.',
        providerId: providerId,
      );
    }
    _activeTrtcSession = this;
    _joinInfo = rawInfo;
    _setState(MediaSessionState.joining);
    try {
      var refreshedOnJoin = false;
      while (true) {
        try {
          await _enterRoom(_joinInfo!);
          break;
        } on MediaError catch (error) {
          if (refreshedOnJoin ||
              !_isCredentialError(error) ||
              _refreshCallback == null) {
            rethrow;
          }
          refreshedOnJoin = true;
          await _exitCloudRoom();
          _joinInfo = await _refreshCredentials(_joinInfo!);
        }
      }
      if (role.canPublishMedia) {
        _engine!.startLocalAudio();
        _engine!.muteLocalAudio(true);
      }
      _setSnapshot(
        _snapshot.copyWith(
          participants: [
            MediaParticipant(
              id: _joinInfo!.userId,
              displayName: _joinInfo!.displayName,
              isLocal: true,
              isMuted: role.canPublishMedia,
            ),
          ],
          localParticipantId: _joinInfo!.userId,
          localMuted: role.canPublishMedia,
          localVideoEnabled: false,
          clearLastError: true,
        ),
      );
      _setState(MediaSessionState.connected);
      _scheduleCredentialRefresh();
    } catch (error) {
      final mapped = _mapError(error, 'Unable to join the TRTC room.');
      await _releaseCloud();
      _activeTrtcSession = null;
      _setState(MediaSessionState.failed, error: mapped);
      throw mapped;
    }
  }

  Future<void> _enterRoom(TrtcJoinInfo info) async {
    _engine ??= await _engineFactory();
    _setState(
      state == MediaSessionState.reconnecting
          ? MediaSessionState.reconnecting
          : MediaSessionState.connecting,
    );
    _enterRequested = true;
    final result = await _engine!
        .enterRoom(info, _engineEvents)
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw MediaError(
            code: MediaErrorCode.nativeError,
            message: 'TRTC did not confirm room entry before the timeout.',
            providerId: providerId,
          ),
        );
    if (result <= 0) {
      throw MediaError(
        code: MediaErrorCode.nativeError,
        message: 'TRTC rejected room entry (code $result).',
        details: {'code': result},
        providerId: providerId,
      );
    }
  }

  TrtcEngineEvents get _engineEvents => TrtcEngineEvents(
    onError: (code, message) {
      if (_isUserSigFailure(code, message) &&
          state == MediaSessionState.connected) {
        unawaited(_refreshAndRejoin());
        return;
      }
      if (state == MediaSessionState.connected ||
          state == MediaSessionState.reconnecting) {
        _reportFailure(
          MediaError(
            code: MediaErrorCode.nativeError,
            message: 'TRTC reported an error: $message',
            details: {'code': code, 'message': message},
            providerId: providerId,
          ),
        );
      }
    },
    onRemoteUserEnterRoom: _remoteUserEntered,
    onRemoteUserLeaveRoom: _remoteUserLeft,
    onUserVideoAvailable: _remoteVideoAvailable,
    onUserAudioAvailable: _remoteAudioAvailable,
    onRecvCustomCmdMsg: _messageReceived,
    onConnectionLost: () => _setState(MediaSessionState.reconnecting),
    onTryToReconnect: () => _setState(MediaSessionState.reconnecting),
    onConnectionRecovery: () {
      if (state == MediaSessionState.reconnecting) {
        _setState(MediaSessionState.connected);
      }
    },
    onStats: (stats) {
      _connectionStats = stats;
      if (!_statsController.isClosed) _statsController.add(stats);
      _eventController.add(MediaNetworkStatsUpdated(stats));
    },
  );

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
    final callback = _refreshCallback;
    final current = _joinInfo;
    if (_disposed || current == null || callback == null) {
      _reportFailure(
        MediaError(
          code: MediaErrorCode.nativeError,
          message:
              'TRTC credentials expired and no refresh callback is available.',
          providerId: providerId,
        ),
      );
      return;
    }
    _refreshTimer?.cancel();
    _setState(MediaSessionState.reconnecting);
    try {
      final refreshed = await _refreshCredentials(current);
      await _exitCloudRoom();
      _joinInfo = refreshed;
      _streamGeneration++;
      await _enterRoom(refreshed);
      if (role.canPublishMedia) {
        _engine!.startLocalAudio();
        _engine!.muteLocalAudio(_snapshot.localMuted);
        if (_snapshot.localVideoEnabled) _engine!.muteLocalVideo(false);
      }
      _refreshLocalTrack();
      _setState(MediaSessionState.connected);
      _scheduleCredentialRefresh();
    } catch (error) {
      final mapped = _mapError(error, 'Unable to renew TRTC credentials.');
      _reportFailure(mapped);
      await _releaseCloud();
      _activeTrtcSession = null;
      _setState(MediaSessionState.failed, error: mapped);
    }
  }

  Future<TrtcJoinInfo> _refreshCredentials(TrtcJoinInfo current) async {
    final callback = _refreshCallback;
    if (callback == null) {
      throw MediaError(
        code: MediaErrorCode.nativeError,
        message: 'No backend credential refresh callback is configured.',
        providerId: providerId,
      );
    }
    final refreshed = await callback(current);
    if (refreshed is! TrtcJoinInfo ||
        refreshed.providerId != current.providerId ||
        refreshed.roomCode != current.roomCode ||
        refreshed.participantId != current.participantId ||
        refreshed.userId != current.userId ||
        refreshed.role != current.role ||
        refreshed.strRoomId != current.strRoomId) {
      throw MediaError(
        code: MediaErrorCode.invalidJoinInfo,
        message: 'TRTC refresh credentials changed the current room identity.',
        providerId: providerId,
      );
    }
    return refreshed;
  }

  void _scheduleCredentialRefresh() {
    _refreshTimer?.cancel();
    final info = _joinInfo;
    if (info == null || _refreshCallback == null || info.expiresAtMs <= 0) {
      return;
    }
    final refreshAtMs = info.expiresAtMs - 30000;
    final delayMs = refreshAtMs - DateTime.now().millisecondsSinceEpoch;
    _refreshTimer = Timer(
      Duration(milliseconds: delayMs > 0 ? delayMs : 0),
      () => unawaited(_refreshAndRejoin()),
    );
  }

  Future<void> _exitCloudRoom() async {
    final engine = _engine;
    if (engine == null || !_enterRequested) return;
    try {
      await engine.exitRoom();
    } on TimeoutException {
      // A timeout must not keep the app from releasing the SDK or applying a
      // refreshed credential. The next enter attempt remains the final check.
    } finally {
      _enterRequested = false;
    }
  }

  Future<void> _releaseCloud() async {
    _refreshTimer?.cancel();
    await _exitCloudRoom();
    final engine = _engine;
    _engine = null;
    if (engine != null) await engine.dispose();
  }

  void _remoteUserEntered(String userId) {
    if (userId == _joinInfo?.userId) return;
    if (_findParticipant(userId) != null) return;
    final participant = MediaParticipant(id: userId, displayName: userId);
    _setSnapshot(
      _snapshot.copyWith(
        participants: [..._snapshot.participants, participant],
      ),
    );
    _eventController.add(MediaParticipantJoined(participant));
  }

  void _remoteUserLeft(String userId) {
    if (_findParticipant(userId) == null) return;
    _setSnapshot(
      _snapshot.copyWith(
        participants: _snapshot.participants
            .where((item) => item.id != userId)
            .toList(),
      ),
    );
    _eventController.add(MediaParticipantLeft(participantId: userId));
    _eventController.add(
      MediaTrackUnpublished(
        trackId: 'trtc:$userId:camera',
        participantId: userId,
      ),
    );
  }

  void _remoteVideoAvailable(String userId, bool available) {
    if (userId == _joinInfo?.userId) return;
    var participant = _findParticipant(userId);
    if (participant == null) {
      _remoteUserEntered(userId);
      participant = _findParticipant(userId);
    }
    if (participant == null) return;
    if (available && _engine != null) {
      final track = _makeVideoTrack(userId, local: false);
      _replaceParticipant(
        participant.copyWith(videoTrack: track, isVideoEnabled: true),
      );
      _eventController.add(MediaTrackPublished(track));
    } else {
      _replaceParticipant(
        participant.copyWith(clearVideoTrack: true, isVideoEnabled: false),
      );
      _eventController.add(
        MediaTrackUnpublished(
          trackId: 'trtc:$userId:camera',
          participantId: userId,
        ),
      );
    }
  }

  void _remoteAudioAvailable(String userId, bool available) {
    if (userId == _joinInfo?.userId) return;
    var participant = _findParticipant(userId);
    if (participant == null) {
      _remoteUserEntered(userId);
      participant = _findParticipant(userId);
    }
    if (participant == null) return;
    _replaceParticipant(participant.copyWith(isMuted: !available));
  }

  void _messageReceived(String userId, int cmdId, String data) {
    if (cmdId != _customMessageCommandId) return;
    String message = data;
    String topic = 'chat';
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map) {
        message = decoded['message']?.toString() ?? data;
        topic = decoded['topic']?.toString() ?? topic;
      }
    } on FormatException {
      // Older TRTC senders may send a plain text payload.
    }
    final incoming = MediaMessage(
      participantId: userId,
      displayName: _findParticipant(userId)?.displayName ?? userId,
      message: message,
      topic: topic,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );
    _setSnapshot(
      _snapshot.copyWith(messages: [..._snapshot.messages, incoming]),
    );
    _eventController.add(MediaMessageReceived(incoming));
  }

  Future<void> _sendMessage(String message, {required String topic}) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      throw MediaError(
        code: MediaErrorCode.invalidArgument,
        message: 'Message must not be empty.',
        providerId: providerId,
      );
    }
    if (!_capabilities.canSendData) {
      throw MediaError(
        code: MediaErrorCode.unsupportedFeature,
        message: 'TRTC viewers cannot send custom messages.',
        providerId: providerId,
      );
    }
    _requireConnected();
    final payload = jsonEncode({'topic': topic, 'message': trimmed});
    if (utf8.encode(payload).length > 1000) {
      throw MediaError(
        code: MediaErrorCode.invalidArgument,
        message: 'TRTC custom messages must be 1000 bytes or fewer.',
        providerId: providerId,
      );
    }
    try {
      final sent = _engine!.sendCustomCmdMsg(_customMessageCommandId, payload);
      if (!sent) {
        throw MediaError(
          code: MediaErrorCode.nativeError,
          message: 'TRTC did not accept the custom message.',
          providerId: providerId,
        );
      }
      final info = _joinInfo!;
      final outgoing = MediaMessage(
        participantId: info.userId,
        displayName: info.displayName,
        message: trimmed,
        topic: topic,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      );
      _setSnapshot(
        _snapshot.copyWith(messages: [..._snapshot.messages, outgoing]),
      );
    } catch (error) {
      throw _mapError(error, 'Unable to send the TRTC message.');
    }
  }

  MediaParticipant? _findParticipant(String id) {
    for (final participant in _snapshot.participants) {
      if (participant.id == id) return participant;
    }
    return null;
  }

  void _replaceParticipant(MediaParticipant replacement) {
    final participants = _snapshot.participants
        .map((item) => item.id == replacement.id ? replacement : item)
        .toList();
    _setSnapshot(_snapshot.copyWith(participants: participants));
  }

  void _refreshLocalTrack() {
    final info = _joinInfo;
    if (info == null || _engine == null || !_snapshot.localVideoEnabled) {
      return;
    }
    final local = _findParticipant(info.userId);
    if (local == null) return;
    _replaceParticipant(
      local.copyWith(videoTrack: _makeVideoTrack(info.userId, local: true)),
    );
  }

  TrtcMediaVideoTrack _makeVideoTrack(String userId, {required bool local}) {
    final engine = _engine!;
    return TrtcMediaVideoTrack(
      userId: userId,
      local: local,
      generation: _streamGeneration,
      startRendering: local
          ? engine.startLocalPreview
          : (viewId) => engine.startRemoteView(userId, viewId),
      stopRendering: local
          ? engine.clearLocalView
          : () => engine.stopRemoteView(userId),
    );
  }

  bool _isCredentialError(MediaError error) =>
      error.details is Map &&
      (error.details as Map)['code'] == _userSigCheckFailed;

  bool _isUserSigFailure(int code, String message) =>
      code == _userSigCheckFailed ||
      (message.toLowerCase().contains('usersig') &&
          (message.toLowerCase().contains('expired') ||
              message.toLowerCase().contains('过期')));

  MediaError _mapError(Object error, String message) {
    if (error is MediaError) return error.withProvider(providerId);
    return MediaError(
      code: MediaErrorCode.nativeError,
      message: message,
      details: error,
      providerId: providerId,
    );
  }

  void _reportFailure(MediaError error) {
    _setSnapshot(_snapshot.copyWith(lastError: error));
    _eventController.add(MediaFailureEvent(error));
  }

  void _setState(MediaSessionState value, {MediaError? error}) {
    if (_snapshot.state == value && error == null) return;
    final previous = _snapshot.state;
    _setSnapshot(_snapshot.copyWith(state: value, lastError: error));
    if (previous != value) {
      if (!_stateController.isClosed) _stateController.add(value);
      _eventController.add(
        MediaConnectionStateChanged(previous: previous, current: value),
      );
    }
  }

  void _setSnapshot(MediaSnapshot value) {
    _snapshot = value;
    if (!_snapshotController.isClosed) _snapshotController.add(value);
  }

  void _requireConnected() {
    if (state != MediaSessionState.connected) {
      throw MediaError(
        code: MediaErrorCode.invalidState,
        message: 'The TRTC session is not connected.',
        providerId: providerId,
      );
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw MediaError(
        code: MediaErrorCode.invalidState,
        message: 'The TRTC session has been disposed.',
        providerId: providerId,
      );
    }
  }

  @override
  Future<void> leave() {
    final current = _leaveFuture;
    if (current != null) return current;
    late final Future<void> future;
    future = _leave().whenComplete(() {
      if (identical(_leaveFuture, future)) _leaveFuture = null;
    });
    _leaveFuture = future;
    return future;
  }

  Future<void> _leave() async {
    if (_disposed) return;
    final joining = _joinFuture;
    if (joining != null) {
      try {
        await joining;
      } catch (_) {
        return;
      }
    }
    if (state == MediaSessionState.ended || state == MediaSessionState.idle) {
      _setState(MediaSessionState.ended);
      _activeTrtcSession = null;
      return;
    }
    _setState(MediaSessionState.leaving);
    _refreshTimer?.cancel();
    await _releaseCloud();
    _activeTrtcSession = null;
    _setSnapshot(
      _snapshot.copyWith(
        participants: const [],
        clearLocalParticipantId: true,
        localVideoEnabled: false,
      ),
    );
    _setState(MediaSessionState.ended);
  }

  @override
  Future<void> dispose() {
    final current = _disposeFuture;
    if (current != null) return current;
    late final Future<void> future;
    future = _dispose().whenComplete(() {
      if (identical(_disposeFuture, future)) _disposeFuture = null;
    });
    _disposeFuture = future;
    return future;
  }

  Future<void> _dispose() async {
    if (_disposed) return;
    await leave();
    _disposed = true;
    _refreshCallback = null;
    _refreshTimer?.cancel();
    _setState(MediaSessionState.disposed);
    await _stateController.close();
    await _snapshotController.close();
    await _eventController.close();
    await _statsController.close();
  }
}

abstract class _TrtcInteractiveSession extends _TrtcSessionBase
    implements InteractiveMediaSession {
  _TrtcInteractiveSession(MediaRole role, TrtcEngineFactory engineFactory)
    : super(role, _publisherCapabilities(role), engineFactory);

  @override
  Future<void> setMuted(bool muted) async {
    _requireConnected();
    try {
      _engine!.muteLocalAudio(muted);
      final info = _joinInfo!;
      final local = _findParticipant(info.userId);
      if (local != null) _replaceParticipant(local.copyWith(isMuted: muted));
      _setSnapshot(_snapshot.copyWith(localMuted: muted));
      _eventController.add(MediaLocalMediaChanged(muted: muted));
    } catch (error) {
      throw _mapError(error, 'Unable to change TRTC microphone state.');
    }
  }

  @override
  Future<void> toggleMute() => setMuted(!_snapshot.localMuted);

  @override
  Future<void> setVideoEnabled(bool enabled) async {
    _requireConnected();
    if (_snapshot.localVideoEnabled == enabled) return;
    try {
      _engine!.muteLocalVideo(!enabled);
      if (!enabled) _engine!.stopLocalPreview();
      final info = _joinInfo!;
      final local = _findParticipant(info.userId);
      TrtcMediaVideoTrack? track;
      if (enabled) {
        track = _makeVideoTrack(info.userId, local: true);
      }
      if (local != null) {
        _replaceParticipant(
          local.copyWith(
            clearVideoTrack: !enabled,
            videoTrack: track,
            isVideoEnabled: enabled,
          ),
        );
      }
      _setSnapshot(_snapshot.copyWith(localVideoEnabled: enabled));
      if (track != null) _eventController.add(MediaTrackPublished(track));
      if (!enabled) {
        _eventController.add(
          MediaTrackUnpublished(
            trackId: 'trtc:${info.userId}:camera',
            participantId: info.userId,
          ),
        );
      }
      _eventController.add(MediaLocalMediaChanged(videoEnabled: enabled));
    } catch (error) {
      throw _mapError(error, 'Unable to change TRTC camera state.');
    }
  }

  @override
  Future<void> setScreenShareEnabled(bool enabled) => Future.error(
    MediaError(
      code: MediaErrorCode.unsupportedFeature,
      message: 'TRTC screen sharing is not supported by this adapter.',
      providerId: providerId,
    ),
  );

  @override
  Future<void> switchCamera(MediaCameraPosition position) async {
    _requireConnected();
    try {
      final result = _engine!.switchCamera(
        position == MediaCameraPosition.front,
      );
      if (result < 0) {
        throw MediaError(
          code: MediaErrorCode.nativeError,
          message: 'TRTC camera switch failed (code $result).',
          details: {'code': result},
          providerId: providerId,
        );
      }
    } catch (error) {
      throw _mapError(error, 'Unable to switch the TRTC camera.');
    }
  }

  @override
  Future<List<MediaAudioDevice>> listAudioDevices() => Future.error(
    MediaError(
      code: MediaErrorCode.unsupportedFeature,
      message:
          'TRTC audio-device enumeration is not supported by this adapter.',
      providerId: providerId,
    ),
  );

  @override
  Future<void> selectAudioDevice(MediaAudioDevice device) => Future.error(
    MediaError(
      code: MediaErrorCode.unsupportedFeature,
      message: 'TRTC audio-device selection is not supported by this adapter.',
      providerId: providerId,
    ),
  );

  @override
  Future<void> sendMessage(String message, {String topic = 'chat'}) =>
      _sendMessage(message, topic: topic);
}
