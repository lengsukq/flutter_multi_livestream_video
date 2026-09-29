import 'dart:async';

import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

/// Minimal provider adapter used to exercise the core layer without any SDK.
///
/// `providerId` defaults to `fake`; tests can register it in a
/// [MediaRegistry] and drive a full join/leave/dispose cycle.
class FakeMediaSessionFactory implements MediaSessionFactory {
  FakeMediaSessionFactory({
    this.providerId = 'fake',
    this.supportedRoles = const {
      MediaRole.participant,
      MediaRole.host,
      MediaRole.viewer,
    },
    this.joinError,
  });

  @override
  final String providerId;

  @override
  final Set<MediaRole> supportedRoles;

  /// When set, `join` fails with this error instead of connecting.
  final MediaError? joinError;

  /// Sessions created through this factory, in creation order.
  final List<FakeMediaSession> createdSessions = [];

  /// Payloads passed to [parseJoinInfo].
  final List<Map<String, dynamic>> parsedPayloads = [];

  @override
  MediaJoinInfo parseJoinInfo(Map<String, dynamic> json) {
    parsedPayloads.add(json);
    final payload = json['payload'];
    return MediaJoinInfo(
      providerId: providerId,
      roomCode: MediaJoinInfo.requireStringIn(
        json,
        'roomCode',
        providerId: providerId,
      ),
      participantId: MediaJoinInfo.requireStringIn(
        json,
        'participantId',
        providerId: providerId,
      ),
      role: MediaRole.tryParse(json['role']) ?? MediaRole.participant,
      payload: payload is Map
          ? Map<String, Object?>.from(payload)
          : const <String, Object?>{},
    );
  }

  @override
  FakeMediaSession createSession(MediaJoinInfo joinInfo) {
    final session = FakeMediaSession(
      providerId: providerId,
      role: joinInfo.role,
      joinError: joinError,
    );
    createdSessions.add(session);
    return session;
  }
}

/// In-memory session implementing the publishing role surfaces for core tests.
///
/// A viewer-only surface is intentionally *not* implemented here: the role
/// contract test proves that `BroadcastViewerSession` alone is implementable
/// without any publish method.
class FakeMediaSession
    implements BroadcastHostSession, MediaCredentialRefreshable {
  FakeMediaSession({
    required this.providerId,
    required this.role,
    this.joinError,
  }) : capabilities = switch (role) {
         MediaRole.participant => const MediaCapabilities.meeting(),
         MediaRole.host => const MediaCapabilities.broadcastHost(),
         MediaRole.viewer => const MediaCapabilities.broadcastViewer(),
       };

  @override
  final String providerId;

  @override
  final MediaRole role;

  /// Injected failure for [join].
  final MediaError? joinError;

  @override
  final MediaCapabilities capabilities;

  final _stateController = StreamController<MediaSessionState>.broadcast();
  final _snapshotController = StreamController<MediaSnapshot>.broadcast();
  final _eventController = StreamController<MediaEvent>.broadcast();

  MediaSnapshot _snapshot = MediaSnapshot();
  int joinCount = 0;
  int leaveCount = 0;
  int disposeCount = 0;
  final List<String> actions = [];
  MediaCredentialRefreshCallback? credentialRefreshCallback;

  @override
  void setCredentialRefreshCallback(MediaCredentialRefreshCallback? callback) {
    credentialRefreshCallback = callback;
  }

  Future<MediaJoinInfo> refreshCredentials(MediaJoinInfo current) {
    final callback = credentialRefreshCallback;
    if (callback == null) {
      throw StateError('No refresh callback was installed.');
    }
    return callback(current);
  }

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

  /// Emits a participant join as if the provider reported one.
  void emitRemoteParticipant({required String id, String name = ''}) {
    final participant = MediaParticipant(id: id, displayName: name);
    _replace(
      _snapshot.copyWith(
        participants: [..._snapshot.participants, participant],
      ),
    );
    _eventController.add(MediaParticipantJoined(participant));
  }

  /// Emits a failure event without changing the lifecycle state.
  void emitError(MediaError error) {
    _replace(_snapshot.copyWith(lastError: error));
    _eventController.add(MediaFailureEvent(error));
  }

  @override
  Future<void> join(MediaJoinInfo joinInfo) async {
    joinCount++;
    if (_snapshot.state.isActive) {
      throw MediaError(
        code: MediaErrorCode.invalidState,
        message: 'Already joined.',
        providerId: providerId,
      );
    }
    final error = joinError;
    if (error != null) {
      _setState(MediaSessionState.failed, error: error);
      throw error;
    }
    _replace(
      MediaSnapshot(
        role: role,
        localParticipantId: joinInfo.participantId,
        capabilities: capabilities,
        participants: [
          MediaParticipant(
            id: joinInfo.participantId,
            displayName: joinInfo.displayName,
            isLocal: true,
          ),
        ],
      ),
    );
    _setState(MediaSessionState.connecting);
    _setState(MediaSessionState.connected);
  }

  @override
  Future<void> leave() async {
    leaveCount++;
    if (!_snapshot.state.isActive) {
      _setState(MediaSessionState.ended);
      return;
    }
    _setState(MediaSessionState.leaving);
    _setState(MediaSessionState.ended);
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    if (_snapshot.state == MediaSessionState.disposed) return;
    if (_snapshot.state.isActive) await leave();
    await _stateController.close();
    await _snapshotController.close();
    await _eventController.close();
    _snapshot = _snapshot.copyWith(state: MediaSessionState.disposed);
  }

  @override
  Future<void> setMuted(bool muted) async {
    actions.add('muted:$muted');
    _replace(_snapshot.copyWith(localMuted: muted));
    _eventController.add(MediaLocalMediaChanged(muted: muted));
  }

  @override
  Future<void> toggleMute() => setMuted(!_snapshot.localMuted);

  @override
  Future<void> setVideoEnabled(bool enabled) async {
    actions.add('video:$enabled');
    _replace(_snapshot.copyWith(localVideoEnabled: enabled));
    _eventController.add(MediaLocalMediaChanged(videoEnabled: enabled));
  }

  @override
  Future<void> setScreenShareEnabled(bool enabled) async {
    if (!capabilities.canScreenShare) {
      throw MediaError(
        code: MediaErrorCode.unsupportedFeature,
        message: 'Screen sharing is not supported.',
        providerId: providerId,
      );
    }
    actions.add('screenShare:$enabled');
  }

  @override
  Future<void> switchCamera(MediaCameraPosition position) async {
    if (!capabilities.canSwitchCamera) {
      throw MediaError(
        code: MediaErrorCode.unsupportedFeature,
        message: 'Camera switching is not supported.',
        providerId: providerId,
      );
    }
    actions.add('camera:${position.name}');
  }

  @override
  Future<List<MediaAudioDevice>> listAudioDevices() async {
    if (!capabilities.canEnumerateAudioDevices) {
      throw MediaError(
        code: MediaErrorCode.unsupportedFeature,
        message: 'Audio device enumeration is not supported.',
        providerId: providerId,
      );
    }
    return const [
      MediaAudioDevice(label: 'Speaker', type: MediaAudioDeviceType.speaker),
    ];
  }

  @override
  Future<void> selectAudioDevice(MediaAudioDevice device) async {
    actions.add('audio:${device.label}');
  }

  @override
  Future<void> sendMessage(String message, {String topic = 'chat'}) async {
    if (!capabilities.canSendData) {
      throw MediaError(
        code: MediaErrorCode.unsupportedFeature,
        message: 'Data messages are not supported.',
        providerId: providerId,
      );
    }
    if (message.trim().isEmpty) {
      throw MediaError(
        code: MediaErrorCode.invalidArgument,
        message: 'Message must not be empty.',
        providerId: providerId,
      );
    }
    actions.add('message:$topic:$message');
  }

  void simulateState(MediaSessionState state, {String? reason}) =>
      _setState(state, reason: reason);

  void _setState(MediaSessionState state, {MediaError? error, String? reason}) {
    if (_snapshot.state == state) return;
    final previous = _snapshot.state;
    final next = error == null
        ? _snapshot.copyWith(state: state)
        : _snapshot.copyWith(state: state, lastError: error);
    _replace(next);
    if (!_stateController.isClosed) {
      _stateController.add(state);
      _eventController.add(
        MediaConnectionStateChanged(
          previous: previous,
          current: state,
          reason: reason,
        ),
      );
    }
  }

  void _replace(MediaSnapshot snapshot) {
    _snapshot = snapshot;
    if (!_snapshotController.isClosed) _snapshotController.add(snapshot);
  }
}
