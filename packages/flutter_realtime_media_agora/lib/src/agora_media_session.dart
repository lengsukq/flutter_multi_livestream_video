import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:agora_rtc_engine/agora_rtc_engine.dart' as agora;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'agora_join_info.dart';
import 'package:flutter_realtime_video_effects/flutter_realtime_video_effects.dart';
import 'agora_media_track.dart';

const _agoraProviderId = AgoraJoinInfo.providerIdValue;

MediaCapabilities _capabilitiesForRole(MediaRole role) {
  if (role == MediaRole.viewer) {
    return const MediaCapabilities(
      canSubscribeVideo: true,
      canSendData: false,
      canReceiveData: true,
      canReportNetworkStats: true,
    );
  }

  final canSwitchCamera =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);
  return MediaCapabilities(
    canPublishAudio: true,
    canPublishVideo: true,
    canBlurBackground:
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.macOS),
    canReplaceBackgroundImage:
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.macOS),
    canEnumerateCameras:
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.macOS),
    canSelectCamera:
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.macOS),
    canSwitchCamera: canSwitchCamera,
    // Android MediaProjection capture is supported by this native SDK.
    // Other platforms still require verified source picker/broadcast adapters.
    canScreenShare: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
    canSendData: true,
    canReceiveData: true,
    canSubscribeVideo: true,
    canEnumerateAudioDevices: false,
    canReportNetworkStats: true,
    maxDataMessageBytes: 1024,
    canListParticipants: role == MediaRole.host,
    canCloseRoom: role == MediaRole.host,
  );
}

abstract class _AgoraMediaSession
    implements
        MediaSession,
        MediaDataMessenger,
        MediaDataPayloadSizer,
        MediaStatsProvider,
        ProcessedVideoSink,
        MediaDeviceController {
  _AgoraMediaSession(this.role, {agora.RtcEngine Function()? engineFactory})
    : _engineFactory = engineFactory ?? agora.createAgoraRtcEngine,
      _capabilities = _capabilitiesForRole(role),
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
  final StreamController<MediaConnectionStats> _statsController =
      StreamController<MediaConnectionStats>.broadcast();

  final Map<String, MediaParticipant> _participants = {};
  final List<MediaMessage> _messages = [];

  final MediaCapabilities _capabilities;
  MediaSnapshot _snapshot;
  MediaSessionState _state = MediaSessionState.idle;
  final agora.RtcEngine Function() _engineFactory;
  agora.RtcEngine? _engine;
  int? _customVideoTrackId;
  final _processedSink = NativeProcessedVideoSink(providerId: 'agora');
  @override
  bool supportsProcessedVideoSource(ProcessedVideoSource source) =>
      role != MediaRole.viewer &&
      capabilities.canBlurBackground &&
      _processedSink.supports(source) &&
      source.platform ==
          (defaultTargetPlatform == TargetPlatform.android
              ? VideoEffectsPlatform.android
              : VideoEffectsPlatform.macos);
  @override
  Future<void> attachProcessedVideoSource(ProcessedVideoSource source) async {
    _ensurePublisherActive('processed video');
    if (!supportsProcessedVideoSource(source)) {
      throw const RealtimeException(
        code: RealtimeErrorCode.unsupportedFeature,
        message: 'Processed video is unavailable.',
      );
    }
    await _requireEngine().enableLocalVideo(false);
    _customVideoTrackId ??= await _requireEngine().createCustomVideoTrack();
    await _processedSink.attach(
      source,
      arguments: {
        'engineHandle': await _requireEngine().getNativeHandle(),
        'trackId': _customVideoTrackId,
      },
    );
    await _updatePublishOptions();
  }

  @override
  Future<void> detachProcessedVideoSource() => _processedSink.detach();

  @override
  Future<List<MediaDevice>> listMediaDevices({
    Set<MediaDeviceKind>? kinds,
  }) async {
    _ensurePublisherActive('camera device selection');
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
    _ensurePublisherActive('camera device selection');
    if (device.kind != MediaDeviceKind.camera ||
        !capabilities.canSelectCamera) {
      throw RealtimeException(
        code: RealtimeErrorCode.unsupportedFeature,
        providerId: providerId,
        message: 'This media device cannot be selected.',
      );
    }
    if (_processedSink.source == null) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidState,
        providerId: providerId,
        message: 'Prepare the SDK video source before selecting a camera.',
      );
    }
    await _processedSink.selectCamera(device.id);
  }

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
  bool _localScreenShareEnabled = false;
  MediaVideoTrack? _localScreenTrack;
  bool _disposed = false;
  bool _joinCancelled = false;
  Duration cleanupTimeout = const Duration(seconds: 10);
  MediaCameraPosition _cameraPosition = MediaCameraPosition.front;
  MediaConnectionStats? _connectionStats;

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

  @override
  int dataPayloadSizeBytes(String message, MediaSendOptions options) => utf8
      .encode(
        jsonEncode({
          'version': 1,
          'topic': options.topic.trim(),
          'message': message.trim(),
          'timestampMs': DateTime.now().millisecondsSinceEpoch,
        }),
      )
      .length;

  @override
  MediaConnectionStats? get connectionStats => _connectionStats;

  @override
  Stream<MediaConnectionStats> get stats => _statsController.stream;

  bool get _canPublish => role != MediaRole.viewer;

  @override
  Future<void> join(MediaJoinInfo joinInfo) =>
      _joinFuture ??= _join(joinInfo).whenComplete(() {
        _joinFuture = null;
      });

  Future<void> _join(MediaJoinInfo rawJoinInfo) async {
    _ensureNotDisposed();
    _joinCancelled = false;
    if (rawJoinInfo is! AgoraJoinInfo) {
      throw const RealtimeException(
        code: RealtimeErrorCode.invalidArgument,
        message: 'Agora session requires AgoraJoinInfo.',
        providerId: _agoraProviderId,
      );
    }
    if (rawJoinInfo.role != role) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidArgument,
        message:
            'Agora session role ${role.wireName} does not match join role '
            '${rawJoinInfo.role.wireName}.',
        providerId: providerId,
      );
    }
    if (_state.isActive ||
        _state == MediaSessionState.joining ||
        _state == MediaSessionState.leaving) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidState,
        message: 'Agora session is already active or changing state.',
        providerId: providerId,
      );
    }

    _joinInfo = rawJoinInfo;
    _localMuted = true;
    _localVideoEnabled = false;
    _localScreenShareEnabled = false;
    _localScreenTrack = null;
    _cameraPosition = MediaCameraPosition.front;
    _participants.clear();
    _messages.clear();
    _activeSpeakerUid = null;
    _dataStreamId = null;
    _setState(MediaSessionState.joining);

    final engine = _engineFactory();
    _engine = engine;
    final completer = Completer<void>();
    _joinCompleter = completer;

    try {
      if (_disposed) {
        throw const RealtimeException(
          code: RealtimeErrorCode.cancelled,
          message: 'Session is closing.',
        );
      }
      await engine.initialize(
        agora.RtcEngineContext(
          appId: rawJoinInfo.appId,
          channelProfile:
              agora.ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );
      _ensureJoinNotCancelled();
      final handler = _buildEventHandler();
      _eventHandler = handler;
      engine.registerEventHandler(handler);
      await engine.enableAudio();
      _ensureJoinNotCancelled();
      await engine.enableVideo();
      _ensureJoinNotCancelled();
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
      _ensureJoinNotCancelled();

      await completer.future.timeout(const Duration(seconds: 20));
      _ensureJoinNotCancelled();
      _refreshSnapshot(clearLastError: true);
      if (_state != MediaSessionState.connected) {
        _setState(MediaSessionState.connected);
      }
    } on RealtimeException catch (error, stack) {
      await _rollbackJoin(error, stack);
    } catch (error, stack) {
      final mapped = _mapError(error, 'Unable to join the Agora channel.');
      await _rollbackJoin(mapped, stack);
    } finally {
      _joinCompleter = null;
    }
  }

  void _ensureJoinNotCancelled() {
    if (_disposed || _joinCancelled) {
      throw RealtimeException(
        code: RealtimeErrorCode.cancelled,
        message: 'The Agora join was cancelled.',
        providerId: providerId,
      );
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
    publishCameraTrack:
        _canPublish &&
        _localVideoEnabled &&
        !_localScreenShareEnabled &&
        _processedSink.source == null,
    publishCustomVideoTrack:
        _canPublish &&
        _localVideoEnabled &&
        !_localScreenShareEnabled &&
        _processedSink.source != null,
    customVideoTrackId: _customVideoTrackId,
    publishScreenCaptureAudio: false,
    publishScreenCaptureVideo: _canPublish && _localScreenShareEnabled,
    enableAudioRecordingOrPlayout: true,
  );

  agora.RtcEngineEventHandler _buildEventHandler() {
    return agora.RtcEngineEventHandler(
      onError: (err, message) {
        final error = RealtimeException(
          code: RealtimeErrorCode.providerError,
          message: 'Agora error ${err.name}: $message',
          details: err,
          providerId: providerId,
        );
        _failPendingJoin(error);
        _reportFailure(error);
      },
      onJoinChannelSuccess: (connection, elapsed) {
        if (_disposed ||
            _joinCancelled ||
            _state == MediaSessionState.leaving ||
            _state == MediaSessionState.ended) {
          return;
        }
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
      onRtcStats: (connection, value) {
        _updateConnectionStats(
          (_connectionStats ??
                  MediaConnectionStats(
                    timestampMs: DateTime.now().millisecondsSinceEpoch,
                  ))
              .copyWith(
                timestampMs: DateTime.now().millisecondsSinceEpoch,
                rttMs: value.lastmileDelay,
                uplinkPacketLossPercent: value.txPacketLossRate?.toDouble(),
                downlinkPacketLossPercent: value.rxPacketLossRate?.toDouble(),
                uploadKbps: value.txKBitRate,
                downloadKbps: value.rxKBitRate,
              ),
        );
      },
      onNetworkQuality: (connection, remoteUid, txQuality, rxQuality) {
        if (remoteUid != 0) return;
        _updateConnectionStats(
          (_connectionStats ??
                  MediaConnectionStats(
                    timestampMs: DateTime.now().millisecondsSinceEpoch,
                  ))
              .copyWith(
                timestampMs: DateTime.now().millisecondsSinceEpoch,
                upstreamQuality: _mapAgoraQuality(txQuality),
                downstreamQuality: _mapAgoraQuality(rxQuality),
              ),
        );
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
            final error = RealtimeException(
              code: RealtimeErrorCode.providerError,
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
              final error = RealtimeException(
                code: RealtimeErrorCode.providerError,
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
          if (source == agora.VideoSourceType.videoSourceScreen &&
              _localScreenShareEnabled) {
            final track = _localScreenTrack;
            _localScreenShareEnabled = false;
            _localScreenTrack = null;
            if (track != null) {
              _emit(
                MediaTrackUnpublished(
                  trackId: track.id,
                  participantId: track.participantId,
                  wasScreenShare: true,
                ),
              );
            }
            _refreshSnapshot();
            final engine = _engine;
            if (engine != null) {
              unawaited(() async {
                try {
                  await engine.stopScreenCapture();
                  if (!_disposed && !_joinCancelled) {
                    await _updatePublishOptions();
                  }
                } catch (error) {
                  _reportFailure(
                    _mapError(
                      error,
                      'Unable to stop failed Agora screen capture.',
                    ),
                  );
                }
              }());
            }
          }
          _reportFailure(
            RealtimeException(
              code: RealtimeErrorCode.providerError,
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
        final error = RealtimeException(
          code: RealtimeErrorCode.providerError,
          message:
              'Agora requested a new token before the session finished joining. '
              'Check the App ID, App Certificate, token TTL, channel name, and UID.',
          providerId: providerId,
        );
        _failPendingJoin(error);
        _reportFailure(error);
      },
      onPermissionError: (permissionType) {
        final error = RealtimeException(
          code: RealtimeErrorCode.permissionDenied,
          message: 'Agora media permission denied: ${permissionType.name}.',
          providerId: providerId,
        );
        _failPendingJoin(error);
        _reportFailure(error);
      },
    );
  }

  bool _failPendingJoin(RealtimeException error) {
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
    final metadata = <String, String>{};
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
          if (ts is num) metadata['senderTimestampMs'] = ts.toInt().toString();
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
      providerId: providerId,
      metadata: metadata,
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
      processedSource: local ? _processedSink.source : null,
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
      if (_processedSink.source == null) {
        await engine.enableLocalVideo(enabled);
      } else {
        await _processedSink.setEnabled(enabled);
      }
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
      throw const RealtimeException(
        code: RealtimeErrorCode.unsupportedFeature,
        message:
            'Agora front/back camera switching is available on Android and '
            'iOS only. macOS uses the current desktop camera.',
        providerId: _agoraProviderId,
      );
    }
    _ensurePublisherActive('camera switching');
    if (position == _cameraPosition) return;
    try {
      if (_processedSink.source != null) {
        await _processedSink.selectCamera(
          position == MediaCameraPosition.front ? 'front' : 'back',
        );
      } else {
        await _requireEngine().switchCamera();
      }
      _cameraPosition = position;
    } catch (error) {
      throw _mapError(error, 'Unable to switch the Agora camera.');
    }
  }

  Future<void> setScreenShareEnabledInternal(bool enabled) async {
    if (!capabilities.canScreenShare) {
      throw const RealtimeException(
        code: RealtimeErrorCode.unsupportedFeature,
        message:
            'Agora native screen sharing is currently available only on Android. '
            'Other native platforms require a verified capture-source adapter.',
        providerId: _agoraProviderId,
      );
    }
    _ensurePublisherActive('screen sharing');
    if (_localScreenShareEnabled == enabled) return;
    final engine = _requireEngine();
    try {
      if (enabled) {
        await engine.startScreenCapture(
          const agora.ScreenCaptureParameters2(
            captureVideo: true,
            captureAudio: false,
          ),
        );
        _localScreenShareEnabled = true;
        try {
          await _updatePublishOptions();
        } catch (_) {
          _localScreenShareEnabled = false;
          await engine.stopScreenCapture();
          rethrow;
        }
        final uid = _localUid;
        if (uid != null) {
          final track = AgoraMediaVideoTrack(
            engine: engine,
            channelId: _joinInfo!.channelName,
            uid: uid,
            local: true,
            screenShare: true,
          );
          _localScreenTrack = track;
          _emit(MediaTrackPublished(track));
        }
      } else {
        await engine.stopScreenCapture();
        _localScreenShareEnabled = false;
        final track = _localScreenTrack;
        _localScreenTrack = null;
        if (track != null) {
          _emit(
            MediaTrackUnpublished(
              trackId: track.id,
              participantId: track.participantId,
              wasScreenShare: true,
            ),
          );
        }
        await _updatePublishOptions();
      }
      _refreshSnapshot();
    } catch (error) {
      _refreshSnapshot();
      throw _mapError(error, 'Unable to change Agora screen-share state.');
    }
  }

  Future<List<MediaAudioDevice>> listAudioDevicesInternal() {
    throw const RealtimeException(
      code: RealtimeErrorCode.unsupportedFeature,
      message: 'Agora audio-device enumeration is not exposed yet.',
      providerId: _agoraProviderId,
    );
  }

  Future<void> selectAudioDeviceInternal(MediaAudioDevice device) {
    throw const RealtimeException(
      code: RealtimeErrorCode.unsupportedFeature,
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
      throw const RealtimeException(
        code: RealtimeErrorCode.unsupportedFeature,
        message:
            'Agora viewer data sending is disabled because RTC data streams '
            'are host-only in live broadcasting.',
        providerId: _agoraProviderId,
      );
    }
    final normalizedMessage = message.trim();
    final normalizedTopic = topic.trim();
    if (normalizedMessage.isEmpty) {
      throw const RealtimeException(
        code: RealtimeErrorCode.invalidArgument,
        message: 'Message must not be empty.',
        providerId: _agoraProviderId,
      );
    }
    if (normalizedTopic.isEmpty) {
      throw const RealtimeException(
        code: RealtimeErrorCode.invalidArgument,
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
      throw RealtimeException(
        code: RealtimeErrorCode.invalidArgument,
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
    if (_joinFuture != null) {
      _joinCancelled = true;
      final pending = _joinCompleter;
      if (pending != null && !pending.isCompleted) pending.complete();
    }
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
        if (!_joinCancelled) {
          _reportFailure(
            _mapError(error, 'Unable to leave the Agora channel.'),
          );
        }
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
    _disposed = true;
    _joinCancelled = true;
    final pending = _joinCompleter;
    if (pending != null && !pending.isCompleted) pending.complete();
    final cleanup = Cleanup(timeout: cleanupTimeout);
    await cleanup.run('join.pending', () async {
      try {
        await _joinFuture;
      } catch (_) {
        /* The join caller receives its failure. */
      }
    });
    await cleanup.run('engine', () async {
      await _tearDownEngine();
    });
    await cleanup.run('terminal', () async {
      _setState(MediaSessionState.disposed);
    });
    await cleanup.run('states', () async {
      await _stateController.close();
    });
    await cleanup.run('snapshots', () async {
      await _snapshotController.close();
    });
    await cleanup.run('events', () async {
      await _eventController.close();
    });
    await cleanup.run('stats', () async {
      await _statsController.close();
    });
    cleanup.finish(domain: providerId);
  }

  void _updateConnectionStats(MediaConnectionStats value) {
    _connectionStats = value;
    if (!_statsController.isClosed) _statsController.add(value);
    _emit(MediaNetworkStatsUpdated(value));
  }

  MediaNetworkQuality _mapAgoraQuality(agora.QualityType value) =>
      switch (value) {
        agora.QualityType.qualityExcellent => MediaNetworkQuality.excellent,
        agora.QualityType.qualityGood => MediaNetworkQuality.good,
        agora.QualityType.qualityPoor => MediaNetworkQuality.fair,
        agora.QualityType.qualityBad => MediaNetworkQuality.poor,
        agora.QualityType.qualityVbad => MediaNetworkQuality.bad,
        agora.QualityType.qualityDown => MediaNetworkQuality.down,
        _ => MediaNetworkQuality.unknown,
      };

  Future<Never> _rollbackJoin(
    RealtimeException primary,
    StackTrace stack,
  ) async {
    final cancelled = _disposed || _joinCancelled;
    final error = cancelled
        ? RealtimeException(
            code: RealtimeErrorCode.cancelled,
            message: 'The Agora join was cancelled.',
            providerId: providerId,
            cause: primary,
          )
        : primary;
    final cleanup = Cleanup(timeout: cleanupTimeout);
    await cleanup.run('join.rollback', _tearDownEngine);
    if (!cancelled) _setState(MediaSessionState.failed, error: error);
    cleanup.finish(domain: providerId, cause: error);
    Error.throwWithStackTrace(error, stack);
  }

  Future<void> _tearDownEngine() async {
    final engine = _engine;
    final handler = _eventHandler;
    final customTrackId = _customVideoTrackId;
    final hadScreenCapture = _localScreenShareEnabled;
    _localScreenShareEnabled = false;
    _localScreenTrack = null;
    _engine = null;
    _eventHandler = null;
    _customVideoTrackId = null;
    _dataStreamId = null;
    _dataStreamFuture = null;
    final cleanup = Cleanup(timeout: cleanupTimeout);
    await cleanup.run('processed.input', _processedSink.detach);
    if (engine != null) {
      if (hadScreenCapture) {
        await cleanup.run('engine.stopScreenCapture', engine.stopScreenCapture);
      }
      if (handler != null) {
        await cleanup.run(
          'engine.events',
          () => engine.unregisterEventHandler(handler),
        );
      }
      if (customTrackId != null) {
        await cleanup.run(
          'engine.customTrack',
          () => engine.destroyCustomVideoTrack(customTrackId),
        );
      }
      await cleanup.run('engine.release', engine.release);
    }
    cleanup.finish(domain: providerId);
  }

  agora.RtcEngine _requireEngine() {
    final engine = _engine;
    if (engine == null) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidState,
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
      throw RealtimeException(
        code: RealtimeErrorCode.unsupportedFeature,
        message: 'Agora viewer sessions cannot use $feature.',
        providerId: providerId,
      );
    }
  }

  void _ensureActive() {
    _ensureNotDisposed();
    if (!_state.isActive) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidState,
        message: 'The Agora session is not active.',
        providerId: providerId,
      );
    }
  }

  void _ensureNotDisposed() {
    if (_disposed || _state == MediaSessionState.disposed) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidState,
        message: 'The Agora session has been disposed.',
        providerId: providerId,
      );
    }
  }

  void _refreshSnapshot({
    RealtimeException? error,
    bool clearLastError = false,
  }) {
    if (_disposed) return;
    _snapshot = _snapshot.copyWith(
      state: _state,
      role: role,
      participants: _participants.values.toList(growable: false),
      messages: List<MediaMessage>.unmodifiable(_messages),
      localParticipantId: _localUid?.toString(),
      clearLocalParticipantId: _localUid == null,
      localMuted: _localMuted,
      localVideoEnabled: _localVideoEnabled,
      localScreenShareEnabled: _localScreenShareEnabled,
      contentShareTrack: _localScreenTrack,
      clearContentShareTrack: _localScreenTrack == null,
      capabilities: _capabilities,
      lastError: error,
      clearLastError: clearLastError,
    );
    if (!_snapshotController.isClosed) {
      _snapshotController.add(_snapshot);
    }
  }

  void _setState(
    MediaSessionState next, {
    String? reason,
    RealtimeException? error,
  }) {
    if (_disposed) {
      if (next == MediaSessionState.disposed) {
        _state = next;
        _snapshot = _snapshot.copyWith(state: next);
      }
      return;
    }
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

  void _reportFailure(RealtimeException error) {
    _refreshSnapshot(error: error);
    _emit(MediaFailureEvent(error));
  }

  void _emit(MediaEvent event) {
    if (!_disposed && !_eventController.isClosed) _eventController.add(event);
  }

  RealtimeException _mapError(Object error, String message) {
    if (error is RealtimeException) return error.withProvider(providerId);
    if (error is TimeoutException) {
      return RealtimeException(
        code: RealtimeErrorCode.timeout,
        message: '$message Timed out waiting for Agora.',
        details: error,
        providerId: providerId,
      );
    }
    return RealtimeException(
      code: RealtimeErrorCode.providerError,
      message: message,
      details: error,
      providerId: providerId,
    );
  }
}

class AgoraInteractiveSession extends _AgoraMediaSession
    implements InteractiveMediaSession {
  AgoraInteractiveSession({super.engineFactory}) : super(MediaRole.participant);

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
  AgoraHostSession({super.engineFactory}) : super(MediaRole.host);

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
  AgoraViewerSession({super.engineFactory}) : super(MediaRole.viewer);
}
