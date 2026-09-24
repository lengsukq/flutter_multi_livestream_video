import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:agora_rtc_engine/agora_rtc_engine.dart' as agora;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'agora_join_info.dart';
import 'agora_media_track.dart';

const _agoraProviderId = AgoraJoinInfo.providerIdValue;

MediaCapabilities _capabilitiesForRole(MediaRole role) {
  if (role == MediaRole.viewer) {
    return const MediaCapabilities(canSubscribeVideo: true, canSendData: false);
  }
  final canSwitchCamera =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);
  return MediaCapabilities(
    canPublishAudio: true,
    canPublishVideo: true,
    canSwitchCamera: canSwitchCamera,
    canScreenShare: false,
    canSendData: true,
    canSubscribeVideo: true,
    canEnumerateAudioDevices: false,
  );
}

abstract class _AgoraMediaSession implements MediaSession, MediaDataMessenger {
  _AgoraMediaSession(this.role)
    : _capabilities = _capabilitiesForRole(role),
      _snapshot = MediaSnapshot(
        role: role,
        capabilities: _capabilitiesForRole(role),
      );

  @override
  final MediaRole role;

  final StreamController<MediaSessionState> _stateController =
      StreamController<MediaSessionState>.broadcast();
  final StreamController<MediaSnapshot> _snapshotController =
      StreamController<MediaSnapshot>.broadcast();
  final StreamController<MediaEvent> _eventController =
      StreamController<MediaEvent>.broadcast();

  final Map<String, MediaParticipant> _participants = {};
  final List<MediaMessage> _messages = [];

  final MediaCapabilities _capabilities;
  MediaSnapshot _snapshot;
  MediaSessionState _state = MediaSessionState.idle;
  agora.RtcEngine? _engine;
  agora.RtcEngineEventHandler? _eventHandler;
  AgoraJoinInfo? _joinInfo;
  Completer<void>? _joinCompleter;
  Future<void>? _joinFuture;
  Future<void>? _leaveFuture;
  Future<void>? _disposeFuture;
  Future<int>? _dataStreamFuture;
  int? _localUid;
  int? _dataStreamId;
  int? _activeSpeakerUid;
  bool _localMuted = true;
  bool _localVideoEnabled = false;
  bool _disposed = false;
  MediaCameraPosition _cameraPosition = MediaCameraPosition.front;

  @override
  String get providerId => _agoraProviderId;

  @override
  MediaCapabilities get capabilities => _capabilities;

  @override
  MediaSessionState get state => _state;

  @override
  MediaSnapshot get snapshot => _snapshot;

  @override
  Stream<MediaSessionState> get states => _stateController.stream;

  @override
  Stream<MediaSnapshot> get snapshots => _snapshotController.stream;

  @override
  Stream<MediaEvent> get events => _eventController.stream;

  bool get _canPublish => role != MediaRole.viewer;

  @override
  Future<void> join(MediaJoinInfo joinInfo) =>
      _joinFuture ??= _join(joinInfo).whenComplete(() {
        _joinFuture = null;
      });

  Future<void> _join(MediaJoinInfo rawJoinInfo) async {
    _ensureNotDisposed();
    if (rawJoinInfo is! AgoraJoinInfo) {
      throw const MediaError(
        code: MediaErrorCode.invalidJoinInfo,
        message: 'Agora session requires AgoraJoinInfo.',
        providerId: _agoraProviderId,
      );
    }
    if (rawJoinInfo.role != role) {
      throw MediaError(
        code: MediaErrorCode.invalidJoinInfo,
        message:
            'Agora session role ${role.wireName} does not match join role '
            '${rawJoinInfo.role.wireName}.',
        providerId: providerId,
      );
    }
    if (_state.isActive ||
        _state == MediaSessionState.joining ||
        _state == MediaSessionState.leaving) {
      throw MediaError(
        code: MediaErrorCode.invalidState,
        message: 'Agora session is already active or changing state.',
        providerId: providerId,
      );
    }

    _joinInfo = rawJoinInfo;
    _localMuted = true;
    _localVideoEnabled = false;
    _cameraPosition = MediaCameraPosition.front;
    _participants.clear();
    _messages.clear();
    _activeSpeakerUid = null;
    _dataStreamId = null;
    _setState(MediaSessionState.joining);

    final engine = agora.createAgoraRtcEngine();
    _engine = engine;
    final completer = Completer<void>();
    _joinCompleter = completer;

    try {
      await engine.initialize(
        agora.RtcEngineContext(
          appId: rawJoinInfo.appId,
          channelProfile:
              agora.ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );
      final handler = _buildEventHandler();
      _eventHandler = handler;
      engine.registerEventHandler(handler);
      await engine.enableAudio();
      await engine.enableVideo();
      await engine.enableAudioVolumeIndication(
        interval: 250,
        smooth: 3,
        reportVad: true,
      );

      _setState(MediaSessionState.connecting);
      await engine.joinChannel(
        token: rawJoinInfo.token,
        channelId: rawJoinInfo.channelName,
        uid: rawJoinInfo.uid,
        options: _channelOptions(),
      );

      await completer.future.timeout(const Duration(seconds: 20));
      _refreshSnapshot(clearLastError: true);
      if (_state != MediaSessionState.connected) {
        _setState(MediaSessionState.connected);
      }
    } on MediaError {
      await _tearDownEngine();
      _setState(MediaSessionState.failed);
      rethrow;
    } catch (error) {
      final mapped = _mapError(error, 'Unable to join the Agora channel.');
      await _tearDownEngine();
      _setState(MediaSessionState.failed, error: mapped);
      throw mapped;
    } finally {
      _joinCompleter = null;
    }
  }

  agora.ChannelMediaOptions _channelOptions() => agora.ChannelMediaOptions(
    channelProfile: agora.ChannelProfileType.channelProfileLiveBroadcasting,
    clientRoleType: _canPublish
        ? agora.ClientRoleType.clientRoleBroadcaster
        : agora.ClientRoleType.clientRoleAudience,
    autoSubscribeAudio: true,
    autoSubscribeVideo: true,
    publishMicrophoneTrack: _canPublish && !_localMuted,
    publishCameraTrack: _canPublish && _localVideoEnabled,
    publishScreenCaptureAudio: false,
    publishScreenCaptureVideo: false,
    enableAudioRecordingOrPlayout: true,
  );

  agora.RtcEngineEventHandler _buildEventHandler() {
    return agora.RtcEngineEventHandler(
      onError: (err, message) {
        final error = MediaError(
          code: MediaErrorCode.nativeError,
          message: 'Agora error ${err.name}: $message',
          details: err,
          providerId: providerId,
        );
        _failPendingJoin(error);
        _reportFailure(error);
      },
      onJoinChannelSuccess: (connection, elapsed) {
        final uid = connection.localUid ?? _joinInfo?.uid;
        if (uid != null) {
          _localUid = uid;
          final info = _joinInfo;
          _participants[uid.toString()] = MediaParticipant(
            id: uid.toString(),
            displayName: (info?.displayName.isNotEmpty ?? false)
                ? info!.displayName
                : uid.toString(),
            isLocal: true,
            isMuted: _localMuted,
            isVideoEnabled: _localVideoEnabled,
            videoTrack: _localVideoEnabled
                ? _videoTrack(uid, local: true)
                : null,
            joinedAt: DateTime.now(),
          );
        }
        _refreshSnapshot();
        if (_state != MediaSessionState.connected) {
          _setState(MediaSessionState.connected);
        }
        final completer = _joinCompleter;
        if (completer != null && !completer.isCompleted) {
          completer.complete();
        }
      },
      onRejoinChannelSuccess: (connection, elapsed) {
        _refreshSnapshot();
        _setState(MediaSessionState.connected);
      },
      onConnectionStateChanged: (connection, state, reason) {
        switch (state) {
          case agora.ConnectionStateType.connectionStateConnecting:
            if (_state != MediaSessionState.joining) {
              _setState(MediaSessionState.connecting, reason: reason.name);
            }
          case agora.ConnectionStateType.connectionStateConnected:
            if (_state == MediaSessionState.reconnecting) {
              _setState(MediaSessionState.connected, reason: reason.name);
            }
          case agora.ConnectionStateType.connectionStateReconnecting:
            _setState(MediaSessionState.reconnecting, reason: reason.name);
          case agora.ConnectionStateType.connectionStateFailed:
            final error = MediaError(
              code: MediaErrorCode.nativeError,
              message: 'Agora connection failed: ${reason.name}.',
              providerId: providerId,
            );
            _failPendingJoin(error);
            _reportFailure(error);
            _setState(
              MediaSessionState.failed,
              reason: reason.name,
              error: error,
            );
          case agora.ConnectionStateType.connectionStateDisconnected:
            final pending = _joinCompleter;
            if (pending != null && !pending.isCompleted) {
              final error = MediaError(
                code: MediaErrorCode.nativeError,
                message:
                    'Agora disconnected before join completed: ${reason.name}.',
                providerId: providerId,
              );
              _failPendingJoin(error);
              _reportFailure(error);
              _setState(
                MediaSessionState.failed,
                reason: reason.name,
                error: error,
              );
              return;
            }
            if (_state != MediaSessionState.leaving &&
                _state != MediaSessionState.ended &&
                _state != MediaSessionState.disposed &&
                _state != MediaSessionState.failed &&
                _state != MediaSessionState.idle) {
              _setState(MediaSessionState.ended, reason: reason.name);
            }
        }
      },
      onUserJoined: (connection, uid, elapsed) {
        final id = uid.toString();
        final participant = MediaParticipant(
          id: id,
          displayName: id,
          joinedAt: DateTime.now(),
        );
        _participants[id] = participant;
        _refreshSnapshot();
        _emit(MediaParticipantJoined(participant));
      },
      onUserOffline: (connection, uid, reason) {
        final id = uid.toString();
        final removed = _participants.remove(id);
        if (_activeSpeakerUid == uid) _activeSpeakerUid = null;
        _refreshSnapshot();
        _emit(
          MediaParticipantLeft(
            participantId: id,
            displayName: removed?.displayName,
          ),
        );
      },
      onUserMuteAudio: (connection, remoteUid, muted) {
        _updateRemoteParticipant(
          remoteUid,
          (participant) => participant.copyWith(isMuted: muted),
        );
        _emit(
          MediaTrackMutedChanged(
            participantId: remoteUid.toString(),
            muted: muted,
            kind: MediaTrackKind.audio,
          ),
        );
      },
      onUserMuteVideo: (connection, remoteUid, muted) {
        _setRemoteVideoState(remoteUid, enabled: !muted);
        _emit(
          MediaTrackMutedChanged(
            participantId: remoteUid.toString(),
            muted: muted,
            trackId: 'agora:${_joinInfo?.channelName}:$remoteUid:camera',
          ),
        );
      },
      onRemoteVideoStateChanged:
          (connection, remoteUid, state, reason, elapsed) {
            final enabled =
                state == agora.RemoteVideoState.remoteVideoStateStarting ||
                state == agora.RemoteVideoState.remoteVideoStateDecoding ||
                state == agora.RemoteVideoState.remoteVideoStateFrozen;
            _setRemoteVideoState(remoteUid, enabled: enabled);
          },
      onLocalVideoStateChanged: (source, state, reason) {
        if (state == agora.LocalVideoStreamState.localVideoStreamStateFailed) {
          _reportFailure(
            MediaError(
              code: MediaErrorCode.nativeError,
              message: 'Agora local video failed: ${reason.name}.',
              providerId: providerId,
            ),
          );
        }
      },
      onActiveSpeaker: (connection, uid) {
        final previous = _activeSpeakerUid;
        if (previous == uid) return;
        _activeSpeakerUid = uid == 0 ? null : uid;
        if (previous != null) {
          _updateRemoteParticipant(
            previous,
            (participant) => participant.copyWith(isSpeaking: false),
            emitSnapshot: false,
          );
          _emit(
            MediaSpeakingChanged(
              participantId: previous.toString(),
              isSpeaking: false,
            ),
          );
        }
        if (uid != 0) {
          _updateRemoteParticipant(
            uid,
            (participant) => participant.copyWith(isSpeaking: true),
            emitSnapshot: false,
          );
          _emit(
            MediaSpeakingChanged(
              participantId: uid.toString(),
              isSpeaking: true,
            ),
          );
        }
        _refreshSnapshot();
      },
      onStreamMessage: (connection, remoteUid, streamId, data, length, sentTs) {
        _handleStreamMessage(remoteUid, data, sentTs);
      },
      onRequestToken: (connection) {
        final error = MediaError(
          code: MediaErrorCode.nativeError,
          message:
              'Agora requested a new token before the session finished joining. '
              'Check the App ID, App Certificate, token TTL, channel name, and UID.',
          providerId: providerId,
        );
        _failPendingJoin(error);
        _reportFailure(error);
      },
      onPermissionError: (permissionType) {
        final error = MediaError(
          code: MediaErrorCode.permissionDenied,
          message: 'Agora media permission denied: ${permissionType.name}.',
          providerId: providerId,
        );
        _failPendingJoin(error);
        _reportFailure(error);
      },
    );
  }

  bool _failPendingJoin(MediaError error) {
    final completer = _joinCompleter;
    if (completer == null || completer.isCompleted) return false;
    completer.completeError(error);
    return true;
  }

  void _handleStreamMessage(int remoteUid, Uint8List data, int sentTs) {
    final text = utf8.decode(data, allowMalformed: true);
    String topic = 'data';
    String message = text;
    int timestampMs = sentTs > 0
        ? sentTs
        : DateTime.now().millisecondsSinceEpoch;
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        final mappedMessage = map['message']?.toString();
        if (mappedMessage != null) {
          message = mappedMessage;
          topic = map['topic']?.toString().trim().isNotEmpty == true
              ? map['topic'].toString().trim()
              : 'chat';
          final ts = map['timestampMs'];
          if (ts is num) timestampMs = ts.toInt();
        }
      }
    } catch (_) {
      // Plain-text data from non-SDK Agora clients remains readable.
    }
    final participant = _participants[remoteUid.toString()];
    final mediaMessage = MediaMessage(
      participantId: remoteUid.toString(),
      displayName: participant?.displayName ?? remoteUid.toString(),
      message: message,
      topic: topic,
      timestampMs: timestampMs,
    );
    _messages.add(mediaMessage);
    _refreshSnapshot();
    _emit(MediaMessageReceived(mediaMessage));
  }

  void _setRemoteVideoState(int uid, {required bool enabled}) {
    final id = uid.toString();
    final before = _participants[id];
    final track = enabled ? _videoTrack(uid, local: false) : null;
    final participant =
        (before ??
                MediaParticipant(
                  id: id,
                  displayName: id,
                  joinedAt: DateTime.now(),
                ))
            .copyWith(
              isVideoEnabled: enabled,
              videoTrack: track,
              clearVideoTrack: !enabled,
            );
    _participants[id] = participant;
    _refreshSnapshot();
    if (enabled && track != null && before?.isVideoEnabled != true) {
      _emit(MediaTrackPublished(track));
    } else if (!enabled && before?.isVideoEnabled == true) {
      _emit(
        MediaTrackUnpublished(
          trackId: 'agora:${_joinInfo?.channelName}:$uid:camera',
          participantId: id,
        ),
      );
    }
  }

  void _updateRemoteParticipant(
    int uid,
    MediaParticipant Function(MediaParticipant participant) update, {
    bool emitSnapshot = true,
  }) {
    final id = uid.toString();
    final participant =
        _participants[id] ??
        MediaParticipant(id: id, displayName: id, joinedAt: DateTime.now());
    _participants[id] = update(participant);
    if (emitSnapshot) _refreshSnapshot();
  }

  AgoraMediaVideoTrack? _videoTrack(int uid, {required bool local}) {
    final engine = _engine;
    final channel = _joinInfo?.channelName;
    if (engine == null || channel == null) return null;
    return AgoraMediaVideoTrack(
      engine: engine,
      channelId: channel,
      uid: uid,
      local: local,
    );
  }

  Future<void> setMutedInternal(bool muted) async {
    _ensurePublisherActive('microphone');
    final engine = _requireEngine();
    try {
      await engine.enableLocalAudio(!muted);
      await engine.muteLocalAudioStream(muted);
      _localMuted = muted;
      await _updatePublishOptions();
      _updateLocalParticipant();
      _refreshSnapshot();
      _emit(MediaLocalMediaChanged(muted: muted));
    } catch (error) {
      throw _mapError(error, 'Unable to update Agora microphone state.');
    }
  }

  Future<void> toggleMuteInternal() => setMutedInternal(!_localMuted);

  Future<void> setVideoEnabledInternal(bool enabled) async {
    _ensurePublisherActive('camera');
    final engine = _requireEngine();
    try {
      await engine.enableLocalVideo(enabled);
      await engine.muteLocalVideoStream(!enabled);
      _localVideoEnabled = enabled;
      await _updatePublishOptions();
      final localId = _localUid;
      final beforeTrack = localId == null
          ? null
          : _participants[localId.toString()]?.videoTrack;
      _updateLocalParticipant();
      _refreshSnapshot();
      _emit(MediaLocalMediaChanged(videoEnabled: enabled));
      if (localId != null) {
        if (enabled && beforeTrack == null) {
          final track = _videoTrack(localId, local: true);
          if (track != null) _emit(MediaTrackPublished(track));
        } else if (!enabled && beforeTrack != null) {
          _emit(
            MediaTrackUnpublished(
              trackId: beforeTrack.id,
              participantId: localId.toString(),
            ),
          );
        }
      }
    } catch (error) {
      throw _mapError(error, 'Unable to update Agora camera state.');
    }
  }

  Future<void> switchCameraInternal(MediaCameraPosition position) async {
    if (!capabilities.canSwitchCamera) {
      throw const MediaError(
        code: MediaErrorCode.unsupportedFeature,
        message:
            'Agora front/back camera switching is available on Android and '
            'iOS only. macOS uses the current desktop camera.',
        providerId: _agoraProviderId,
      );
    }
    _ensurePublisherActive('camera switching');
    if (position == _cameraPosition) return;
    try {
      await _requireEngine().switchCamera();
      _cameraPosition = position;
    } catch (error) {
      throw _mapError(error, 'Unable to switch the Agora camera.');
    }
  }

  Future<void> setScreenShareEnabledInternal(bool enabled) {
    throw const MediaError(
      code: MediaErrorCode.unsupportedFeature,
      message: 'Agora screen sharing is deferred in this SDK version.',
      providerId: _agoraProviderId,
    );
  }

  Future<List<MediaAudioDevice>> listAudioDevicesInternal() {
    throw const MediaError(
      code: MediaErrorCode.unsupportedFeature,
      message: 'Agora audio-device enumeration is not exposed yet.',
      providerId: _agoraProviderId,
    );
  }

  Future<void> selectAudioDeviceInternal(MediaAudioDevice device) {
    throw const MediaError(
      code: MediaErrorCode.unsupportedFeature,
      message: 'Agora audio-device selection is not exposed yet.',
      providerId: _agoraProviderId,
    );
  }

  Future<void> _updatePublishOptions() async {
    if (!_canPublish) return;
    await _requireEngine().updateChannelMediaOptions(_channelOptions());
  }

  void _updateLocalParticipant() {
    final uid = _localUid;
    if (uid == null) return;
    final id = uid.toString();
    final current = _participants[id];
    final info = _joinInfo;
    _participants[id] = MediaParticipant(
      id: id,
      displayName:
          current?.displayName ??
          ((info?.displayName.isNotEmpty ?? false) ? info!.displayName : id),
      isLocal: true,
      isMuted: _localMuted,
      isVideoEnabled: _localVideoEnabled,
      isSpeaking: current?.isSpeaking ?? false,
      videoTrack: _localVideoEnabled ? _videoTrack(uid, local: true) : null,
      joinedAt: current?.joinedAt ?? DateTime.now(),
    );
  }

  @override
  Future<void> sendMessage(String message, {String topic = 'chat'}) async {
    _ensureActive();
    if (!capabilities.canSendData) {
      throw const MediaError(
        code: MediaErrorCode.unsupportedFeature,
        message:
            'Agora viewer data sending is disabled because RTC data streams '
            'are host-only in live broadcasting.',
        providerId: _agoraProviderId,
      );
    }
    final normalizedMessage = message.trim();
    final normalizedTopic = topic.trim();
    if (normalizedMessage.isEmpty) {
      throw const MediaError(
        code: MediaErrorCode.invalidArgument,
        message: 'Message must not be empty.',
        providerId: _agoraProviderId,
      );
    }
    if (normalizedTopic.isEmpty) {
      throw const MediaError(
        code: MediaErrorCode.invalidArgument,
        message: 'Message topic must not be empty.',
        providerId: _agoraProviderId,
      );
    }
    final streamId = await _ensureDataStream();
    final encoded = utf8.encode(
      jsonEncode({
        'version': 1,
        'topic': normalizedTopic,
        'message': normalizedMessage,
        'timestampMs': DateTime.now().millisecondsSinceEpoch,
      }),
    );
    if (encoded.length > 1024) {
      throw MediaError(
        code: MediaErrorCode.invalidArgument,
        message:
            'Agora RTC data-stream messages must be at most 1024 bytes; '
            'encoded payload is ${encoded.length} bytes.',
        providerId: providerId,
      );
    }
    try {
      final data = Uint8List.fromList(encoded);
      await _requireEngine().sendStreamMessage(
        streamId: streamId,
        data: data,
        length: data.length,
      );
    } catch (error) {
      throw _mapError(error, 'Unable to send Agora data.');
    }
  }

  @override
  Future<void> leave() => _leaveFuture ??= _leave().whenComplete(() {
    _leaveFuture = null;
  });

  Future<void> _leave() async {
    if (_disposed || _state == MediaSessionState.disposed) return;
    if (_state == MediaSessionState.idle ||
        _state == MediaSessionState.ended ||
        _state == MediaSessionState.failed) {
      if (_state != MediaSessionState.ended) {
        _setState(MediaSessionState.ended);
      }
      await _tearDownEngine();
      return;
    }
    _setState(MediaSessionState.leaving);
    final engine = _engine;
    if (engine != null) {
      try {
        await engine.leaveChannel();
      } catch (error) {
        _reportFailure(_mapError(error, 'Unable to leave the Agora channel.'));
      }
    }
    await _tearDownEngine();
    _participants.clear();
    _messages.clear();
    _localUid = null;
    _dataStreamId = null;
    _refreshSnapshot();
    _setState(MediaSessionState.ended);
  }

  @override
  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    if (_disposed) return;
    if (_state.isActive ||
        _state == MediaSessionState.joining ||
        _state == MediaSessionState.leaving) {
      await leave();
    } else {
      await _tearDownEngine();
    }
    _disposed = true;
    _setState(MediaSessionState.disposed);
    await _stateController.close();
    await _snapshotController.close();
    await _eventController.close();
  }

  Future<void> _tearDownEngine() async {
    final engine = _engine;
    final handler = _eventHandler;
    _engine = null;
    _eventHandler = null;
    _dataStreamId = null;
    _dataStreamFuture = null;
    if (engine == null) return;
    if (handler != null) {
      engine.unregisterEventHandler(handler);
    }
    try {
      await engine.release();
    } catch (_) {
      // Resource release is best-effort after leave/join failures.
    }
  }

  agora.RtcEngine _requireEngine() {
    final engine = _engine;
    if (engine == null) {
      throw MediaError(
        code: MediaErrorCode.sessionNotFound,
        message: 'The Agora engine is unavailable.',
        providerId: providerId,
      );
    }
    return engine;
  }

  Future<int> _ensureDataStream() async {
    final existing = _dataStreamId;
    if (existing != null) return existing;

    final inFlight = _dataStreamFuture;
    if (inFlight != null) return inFlight;

    final engine = _requireEngine();
    final future = engine
        .createDataStream(
          const agora.DataStreamConfig(syncWithAudio: false, ordered: true),
        )
        .timeout(const Duration(seconds: 5));
    _dataStreamFuture = future;
    try {
      final streamId = await future;
      _dataStreamId = streamId;
      return streamId;
    } catch (error) {
      throw _mapError(error, 'Unable to create the Agora data stream.');
    } finally {
      _dataStreamFuture = null;
    }
  }

  void _ensurePublisherActive(String feature) {
    _ensureActive();
    if (!_canPublish) {
      throw MediaError(
        code: MediaErrorCode.unsupportedFeature,
        message: 'Agora viewer sessions cannot use $feature.',
        providerId: providerId,
      );
    }
  }

  void _ensureActive() {
    _ensureNotDisposed();
    if (!_state.isActive) {
      throw MediaError(
        code: MediaErrorCode.invalidState,
        message: 'The Agora session is not active.',
        providerId: providerId,
      );
    }
  }

  void _ensureNotDisposed() {
    if (_disposed || _state == MediaSessionState.disposed) {
      throw MediaError(
        code: MediaErrorCode.invalidState,
        message: 'The Agora session has been disposed.',
        providerId: providerId,
      );
    }
  }

  void _refreshSnapshot({MediaError? error, bool clearLastError = false}) {
    _snapshot = _snapshot.copyWith(
      state: _state,
      role: role,
      participants: _participants.values.toList(growable: false),
      messages: List<MediaMessage>.unmodifiable(_messages),
      localParticipantId: _localUid?.toString(),
      clearLocalParticipantId: _localUid == null,
      localMuted: _localMuted,
      localVideoEnabled: _localVideoEnabled,
      capabilities: _capabilities,
      lastError: error,
      clearLastError: clearLastError,
    );
    if (!_snapshotController.isClosed) {
      _snapshotController.add(_snapshot);
    }
  }

  void _setState(MediaSessionState next, {String? reason, MediaError? error}) {
    final previous = _state;
    if (previous == next && error == null) return;
    _state = next;
    _refreshSnapshot(error: error);
    if (!_stateController.isClosed) _stateController.add(next);
    _emit(
      MediaConnectionStateChanged(
        previous: previous,
        current: next,
        reason: reason,
      ),
    );
  }

  void _reportFailure(MediaError error) {
    _refreshSnapshot(error: error);
    _emit(MediaFailureEvent(error));
  }

  void _emit(MediaEvent event) {
    if (!_eventController.isClosed) _eventController.add(event);
  }

  MediaError _mapError(Object error, String message) {
    if (error is MediaError) return error.withProvider(providerId);
    if (error is TimeoutException) {
      return MediaError(
        code: MediaErrorCode.nativeError,
        message: '$message Timed out waiting for Agora.',
        details: error,
        providerId: providerId,
      );
    }
    return MediaError(
      code: MediaErrorCode.nativeError,
      message: message,
      details: error,
      providerId: providerId,
    );
  }
}

class AgoraInteractiveSession extends _AgoraMediaSession
    implements InteractiveMediaSession {
  AgoraInteractiveSession() : super(MediaRole.participant);

  @override
  Future<void> setMuted(bool muted) => setMutedInternal(muted);

  @override
  Future<void> toggleMute() => toggleMuteInternal();

  @override
  Future<void> setVideoEnabled(bool enabled) =>
      setVideoEnabledInternal(enabled);

  @override
  Future<void> setScreenShareEnabled(bool enabled) =>
      setScreenShareEnabledInternal(enabled);

  @override
  Future<void> switchCamera(MediaCameraPosition position) =>
      switchCameraInternal(position);

  @override
  Future<List<MediaAudioDevice>> listAudioDevices() =>
      listAudioDevicesInternal();

  @override
  Future<void> selectAudioDevice(MediaAudioDevice device) =>
      selectAudioDeviceInternal(device);
}

class AgoraHostSession extends _AgoraMediaSession
    implements BroadcastHostSession {
  AgoraHostSession() : super(MediaRole.host);

  @override
  Future<void> setMuted(bool muted) => setMutedInternal(muted);

  @override
  Future<void> toggleMute() => toggleMuteInternal();

  @override
  Future<void> setVideoEnabled(bool enabled) =>
      setVideoEnabledInternal(enabled);

  @override
  Future<void> setScreenShareEnabled(bool enabled) =>
      setScreenShareEnabledInternal(enabled);

  @override
  Future<void> switchCamera(MediaCameraPosition position) =>
      switchCameraInternal(position);

  @override
  Future<List<MediaAudioDevice>> listAudioDevices() =>
      listAudioDevicesInternal();

  @override
  Future<void> selectAudioDevice(MediaAudioDevice device) =>
      selectAudioDeviceInternal(device);
}

class AgoraViewerSession extends _AgoraMediaSession
    implements BroadcastViewerSession {
  AgoraViewerSession() : super(MediaRole.viewer);
}
