import 'dart:async';
import 'dart:convert';

import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'artc_engine.dart';
import 'artc_join_info.dart';
import 'artc_media_track.dart';

typedef ArtcSessionEngineFactory = Future<ArtcEngine> Function();

abstract class _ArtcMediaSession
    implements MediaSession, MediaCredentialRefreshable {
  _ArtcMediaSession({
    required this.role,
    required ArtcSessionEngineFactory engineFactory,
  }) : _engineFactory = engineFactory;

  static _ArtcMediaSession? _activeSession;

  final ArtcSessionEngineFactory _engineFactory;
  final StreamController<MediaSessionState> _states =
      StreamController<MediaSessionState>.broadcast();
  final StreamController<MediaSnapshot> _snapshots =
      StreamController<MediaSnapshot>.broadcast();
  final StreamController<MediaEvent> _events =
      StreamController<MediaEvent>.broadcast();

  ArtcEngine? _engine;
  ArtcJoinInfo? _joinInfo;
  MediaCredentialRefreshCallback? _refreshCallback;
  Timer? _refreshTimer;
  Future<void>? _refreshFuture;
  MediaSessionState _state = MediaSessionState.idle;
  MediaCapabilities _capabilities = const MediaCapabilities.none();
  late MediaSnapshot _snapshot = MediaSnapshot(role: role);
  MediaCameraPosition _cameraPosition = MediaCameraPosition.front;
  int _trackGeneration = 0;
  bool _disposed = false;

  @override
  final MediaRole role;

  @override
  String get providerId => ArtcJoinInfo.providerIdValue;

  @override
  MediaCapabilities get capabilities => _capabilities;

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
  void setCredentialRefreshCallback(MediaCredentialRefreshCallback? callback) {
    _refreshCallback = callback;
    _scheduleCredentialRefresh();
  }

  @override
  Future<void> join(MediaJoinInfo joinInfo) async {
    if (_disposed || _state == MediaSessionState.disposed) {
      throw _error(
        MediaErrorCode.invalidState,
        'An ARTC session cannot join after dispose.',
      );
    }
    if (_state == MediaSessionState.joining || _state.isActive) {
      throw _error(
        MediaErrorCode.invalidState,
        'This ARTC session is already joining or active.',
      );
    }
    if (joinInfo is! ArtcJoinInfo ||
        joinInfo.providerId != providerId ||
        joinInfo.role != role ||
        joinInfo.participantId != joinInfo.userId) {
      throw _error(
        MediaErrorCode.invalidJoinInfo,
        'ARTC join information does not match this session.',
      );
    }
    if (_activeSession != null && !identical(_activeSession, this)) {
      throw _error(
        MediaErrorCode.sessionAlreadyActive,
        'ARTC supports one active engine session per app process.',
      );
    }

    _activeSession = this;
    _joinInfo = joinInfo;
    _capabilities = switch (role) {
      MediaRole.participant || MediaRole.host => const MediaCapabilities(
        canPublishAudio: true,
        canPublishVideo: true,
        canSwitchCamera: true,
        canSendData: true,
        canSubscribeVideo: true,
      ),
      MediaRole.viewer => const MediaCapabilities.broadcastViewer(
        canSendData: false,
      ),
    };
    _setState(MediaSessionState.joining);
    try {
      _engine ??= await _engineFactory();
      _setState(MediaSessionState.connecting);
      await _engine!.join(joinInfo, _createEngineEvents());
      if (_disposed) return;
      final local = MediaParticipant(
        id: joinInfo.userId,
        displayName: joinInfo.displayName.isEmpty
            ? joinInfo.userId
            : joinInfo.displayName,
        isLocal: true,
        isMuted: role != MediaRole.viewer,
      );
      _setSnapshot(
        _snapshot.copyWith(
          participants: [local],
          localParticipantId: joinInfo.userId,
          localMuted: role != MediaRole.viewer,
          localVideoEnabled: false,
          capabilities: _capabilities,
          clearLastError: true,
        ),
      );
      _setState(MediaSessionState.connected);
      _scheduleCredentialRefresh();
    } catch (error) {
      final mapped = _mapError(error, 'Unable to join the ARTC channel.');
      await _releaseEngine(leave: true);
      _activeSession = null;
      _setState(MediaSessionState.failed, error: mapped);
      throw mapped;
    }
  }

  @override
  Future<void> leave() async {
    if (_disposed ||
        _state == MediaSessionState.ended ||
        _state == MediaSessionState.idle)
      return;
    _refreshTimer?.cancel();
    _refreshTimer = null;
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
    _refreshCallback = null;
    _refreshTimer?.cancel();
    await _releaseEngine(leave: false);
    if (identical(_activeSession, this)) _activeSession = null;
    _setState(MediaSessionState.disposed);
    await _states.close();
    await _snapshots.close();
    await _events.close();
  }

  Future<void> _releaseEngine({required bool leave}) async {
    final engine = _engine;
    if (engine == null) return;
    if (leave) {
      try {
        await engine.leave();
      } catch (_) {
        // Always release the provider even when its leave callback fails.
      }
    } else {
      await engine.dispose();
      _engine = null;
    }
  }

  ArtcEngineEvents _createEngineEvents() => ArtcEngineEvents(
    onError: _onNativeError,
    onParticipantJoined: _participantJoined,
    onParticipantLeft: _participantLeft,
    onRemoteVideoChanged: _remoteVideoChanged,
    onRemoteAudioChanged: _remoteAudioChanged,
    onMessage: _receiveMessage,
    onReconnecting: () => _setState(MediaSessionState.reconnecting),
    onRecovered: () {
      if (_state == MediaSessionState.reconnecting)
        _setState(MediaSessionState.connected);
    },
    onAuthWillExpire: () => unawaited(_refreshAndRejoin()),
  );

  void _participantJoined(String userId) {
    if (userId.isEmpty || userId == _joinInfo?.userId) return;
    final existing = _snapshot.participants.where((item) => item.id == userId);
    if (existing.isNotEmpty) return;
    final participant = MediaParticipant(id: userId, displayName: userId);
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
    if (userId == _joinInfo?.userId) return;
    _ensureRemoteParticipant(userId);
    final participants = _snapshot.participants.map((item) {
      if (item.id != userId) return item;
      final track = available
          ? ArtcMediaVideoTrack(
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
      final track = participants
          .firstWhere((item) => item.id == userId)
          .videoTrack!;
      _events.add(MediaTrackPublished(track));
    } else {
      _events.add(
        MediaTrackUnpublished(
          trackId: 'artc:$userId:camera:$_trackGeneration',
          participantId: userId,
        ),
      );
    }
  }

  void _remoteAudioChanged(String userId, bool available) {
    if (userId == _joinInfo?.userId) return;
    _ensureRemoteParticipant(userId);
    final participants = _snapshot.participants
        .map(
          (item) =>
              item.id == userId ? item.copyWith(isMuted: !available) : item,
        )
        .toList();
    _setSnapshot(_snapshot.copyWith(participants: participants));
    _events.add(
      MediaTrackMutedChanged(
        participantId: userId,
        muted: !available,
        kind: MediaTrackKind.audio,
      ),
    );
  }

  void _ensureRemoteParticipant(String userId) {
    if (_snapshot.participants.any((item) => item.id == userId)) return;
    final participant = MediaParticipant(id: userId, displayName: userId);
    _setSnapshot(
      _snapshot.copyWith(
        participants: [..._snapshot.participants, participant],
      ),
    );
    _events.add(MediaParticipantJoined(participant));
  }

  void _receiveMessage(String userId, String rawData) {
    if (rawData.isEmpty) return;
    var message = rawData;
    var topic = 'chat';
    try {
      final decoded = jsonDecode(rawData);
      if (decoded is Map) {
        message = decoded['message']?.toString() ?? rawData;
        topic = decoded['topic']?.toString() ?? 'chat';
      }
    } on FormatException {
      // Preserve raw messages sent by non-SDK clients.
    }
    final item = MediaMessage(
      participantId: userId,
      displayName: _participantById(userId)?.displayName ?? userId,
      message: message,
      topic: topic,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );
    _appendMessage(item);
    _events.add(MediaMessageReceived(item));
  }

  void _onNativeError(int code, String message) {
    final error = MediaError(
      code: MediaErrorCode.nativeError,
      message: 'ARTC reported an error: $message',
      details: {'code': code, 'message': message},
      providerId: providerId,
    );
    _setSnapshot(_snapshot.copyWith(lastError: error));
    _events.add(MediaFailureEvent(error));
  }

  MediaParticipant? _participantById(String userId) {
    for (final participant in _snapshot.participants) {
      if (participant.id == userId) return participant;
    }
    return null;
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
    final callback = _refreshCallback;
    final current = _joinInfo;
    if (_disposed || current == null || callback == null) {
      _onNativeError(
        -2,
        'ARTC credentials are expiring and no refresh callback is configured.',
      );
      return;
    }
    _refreshTimer?.cancel();
    _setState(MediaSessionState.reconnecting);
    try {
      final rawRefreshed = await callback(current);
      final refreshed = _validateRefreshedInfo(current, rawRefreshed);
      await _engine!.leave();
      _joinInfo = refreshed;
      _trackGeneration++;
      await _engine!.join(refreshed, _createEngineEvents());
      _setSnapshot(_snapshot.copyWith(clearLastError: true));
      _setState(MediaSessionState.connected);
      _scheduleCredentialRefresh();
    } catch (error) {
      final mapped = _mapError(error, 'Unable to renew ARTC credentials.');
      _setSnapshot(_snapshot.copyWith(lastError: mapped));
      _events.add(MediaFailureEvent(mapped));
      _setState(MediaSessionState.failed, error: mapped);
      await _releaseEngine(leave: true);
      _activeSession = null;
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
      throw _error(
        MediaErrorCode.invalidJoinInfo,
        'ARTC refresh credentials changed the active room or identity.',
      );
    }
    return refreshed;
  }

  void _scheduleCredentialRefresh() {
    _refreshTimer?.cancel();
    final info = _joinInfo;
    if (info == null ||
        _refreshCallback == null ||
        _state != MediaSessionState.connected)
      return;
    final delayMs =
        info.expiresAtMs - 30000 - DateTime.now().millisecondsSinceEpoch;
    _refreshTimer = Timer(
      Duration(milliseconds: delayMs > 0 ? delayMs : 0),
      () => unawaited(_refreshAndRejoin()),
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

  void _appendMessage(MediaMessage message) {
    _setSnapshot(
      _snapshot.copyWith(messages: [..._snapshot.messages, message]),
    );
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

  void _requireActive() {
    if (!_state.isActive || _engine == null) {
      throw _error(
        MediaErrorCode.invalidState,
        'ARTC media controls require an active session.',
      );
    }
  }

  void _requireCapability(bool allowed, String feature) {
    if (!allowed) {
      throw _error(
        MediaErrorCode.unsupportedFeature,
        'ARTC $role sessions do not support $feature.',
      );
    }
  }

  Future<void> _sendMessage(String message, {String topic = 'chat'}) async {
    _requireActive();
    _requireCapability(_capabilities.canSendData, 'sending data messages');
    if (_snapshot.localMuted && !_snapshot.localVideoEnabled) {
      throw _error(
        MediaErrorCode.invalidState,
        'ARTC data messages require an active local audio or video stream. Enable the microphone or camera first.',
      );
    }
    final content = message.trim();
    final normalizedTopic = topic.trim();
    if (content.isEmpty || normalizedTopic.isEmpty) {
      throw _error(
        MediaErrorCode.invalidArgument,
        'ARTC messages and topics must not be empty.',
      );
    }
    final envelope = jsonEncode({'message': content, 'topic': normalizedTopic});
    if (utf8.encode(envelope).length > 1000) {
      throw _error(
        MediaErrorCode.invalidArgument,
        'ARTC data messages must be at most 1000 UTF-8 bytes.',
      );
    }
    await _engine!.sendMessage(content, normalizedTopic);
    final info = _joinInfo!;
    final item = MediaMessage(
      participantId: info.userId,
      displayName: info.displayName,
      message: content,
      topic: normalizedTopic,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );
    _appendMessage(item);
  }

  Future<void> _setMuted(bool muted) async {
    _requireActive();
    _requireCapability(_capabilities.canPublishAudio, 'publishing audio');
    await _engine!.setMuted(muted);
    _setSnapshot(_snapshot.copyWith(localMuted: muted));
    _events.add(MediaLocalMediaChanged(muted: muted));
  }

  Future<void> _setVideoEnabled(bool enabled) async {
    _requireActive();
    _requireCapability(_capabilities.canPublishVideo, 'publishing video');
    await _engine!.setVideoEnabled(enabled);
    if (_joinInfo case final info?) {
      final localTrack = enabled
          ? ArtcMediaVideoTrack(
              userId: info.userId,
              local: true,
              generation: _trackGeneration,
            )
          : null;
      final participants = _snapshot.participants
          .map(
            (item) => item.isLocal
                ? item.copyWith(
                    isVideoEnabled: enabled,
                    videoTrack: localTrack,
                    clearVideoTrack: !enabled,
                  )
                : item,
          )
          .toList();
      _setSnapshot(
        _snapshot.copyWith(
          participants: participants,
          localVideoEnabled: enabled,
        ),
      );
      if (enabled) {
        _events.add(MediaTrackPublished(localTrack!));
      } else {
        _events.add(
          MediaTrackUnpublished(
            trackId: 'artc:${info.userId}:camera:$_trackGeneration',
            participantId: info.userId,
          ),
        );
      }
    }
    _events.add(MediaLocalMediaChanged(videoEnabled: enabled));
  }

  Future<void> _switchCamera(MediaCameraPosition position) async {
    _requireActive();
    _requireCapability(_capabilities.canSwitchCamera, 'switching cameras');
    if (_cameraPosition == position) return;
    await _engine!.switchCamera(position);
    _cameraPosition = position;
  }

  Future<void> _setScreenShareEnabled(bool enabled) async {
    _requireActive();
    _requireCapability(false, 'screen sharing');
  }

  Future<List<MediaAudioDevice>> _listAudioDevices() async {
    _requireActive();
    _requireCapability(
      _capabilities.canEnumerateAudioDevices,
      'audio device enumeration',
    );
    return const [];
  }

  Future<void> _selectAudioDevice(MediaAudioDevice device) async {
    _requireActive();
    _requireCapability(
      _capabilities.canEnumerateAudioDevices,
      'audio device selection',
    );
  }
}

class ArtcParticipantSession extends _ArtcMediaSession
    implements InteractiveMediaSession {
  ArtcParticipantSession({required ArtcSessionEngineFactory engineFactory})
    : super(role: MediaRole.participant, engineFactory: engineFactory);

  @override
  Future<void> setMuted(bool muted) => _setMuted(muted);

  @override
  Future<void> toggleMute() => setMuted(!snapshot.localMuted);

  @override
  Future<void> setVideoEnabled(bool enabled) => _setVideoEnabled(enabled);

  @override
  Future<void> setScreenShareEnabled(bool enabled) =>
      _setScreenShareEnabled(enabled);

  @override
  Future<void> switchCamera(MediaCameraPosition position) =>
      _switchCamera(position);

  @override
  Future<List<MediaAudioDevice>> listAudioDevices() => _listAudioDevices();

  @override
  Future<void> selectAudioDevice(MediaAudioDevice device) =>
      _selectAudioDevice(device);

  @override
  Future<void> sendMessage(String message, {String topic = 'chat'}) =>
      _sendMessage(message, topic: topic);
}

class ArtcBroadcastHostSession extends _ArtcMediaSession
    implements BroadcastHostSession {
  ArtcBroadcastHostSession({required ArtcSessionEngineFactory engineFactory})
    : super(role: MediaRole.host, engineFactory: engineFactory);

  @override
  Future<void> setMuted(bool muted) => _setMuted(muted);

  @override
  Future<void> toggleMute() => setMuted(!snapshot.localMuted);

  @override
  Future<void> setVideoEnabled(bool enabled) => _setVideoEnabled(enabled);

  @override
  Future<void> setScreenShareEnabled(bool enabled) =>
      _setScreenShareEnabled(enabled);

  @override
  Future<void> switchCamera(MediaCameraPosition position) =>
      _switchCamera(position);

  @override
  Future<List<MediaAudioDevice>> listAudioDevices() => _listAudioDevices();

  @override
  Future<void> selectAudioDevice(MediaAudioDevice device) =>
      _selectAudioDevice(device);

  @override
  Future<void> sendMessage(String message, {String topic = 'chat'}) =>
      _sendMessage(message, topic: topic);
}

class ArtcBroadcastViewerSession extends _ArtcMediaSession
    implements BroadcastViewerSession {
  ArtcBroadcastViewerSession({required ArtcSessionEngineFactory engineFactory})
    : super(role: MediaRole.viewer, engineFactory: engineFactory);

  @override
  Future<void> sendMessage(String message, {String topic = 'chat'}) =>
      _sendMessage(message, topic: topic);
}
