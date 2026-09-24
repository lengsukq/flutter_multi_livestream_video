import 'dart:async';
import 'dart:convert';

import 'package:flutter_multi_livestream_video_core/flutter_multi_livestream_video_core.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import 'livekit_join_info.dart';
import 'livekit_media_track.dart';

const _interactiveCapabilities = MediaCapabilities(
  canPublishAudio: true,
  canPublishVideo: true,
  canSwitchCamera: true,
  canScreenShare: true,
  canSendData: true,
  canSubscribeVideo: true,
  canEnumerateAudioDevices: true,
);

/// Shared LiveKit lifecycle and event translation.
abstract class LiveKitMediaSessionBase
    implements MediaSession, MediaDataMessenger {
  LiveKitMediaSessionBase({
    required this.role,
    required MediaCapabilities capabilities,
  }) : _capabilities = capabilities,
       _snapshot = MediaSnapshot(role: role, capabilities: capabilities);

  @override
  String get providerId => LiveKitJoinInfo.providerIdValue;

  @override
  final MediaRole role;

  MediaCapabilities _capabilities;
  MediaSnapshot _snapshot;
  lk.Room? _room;
  lk.EventsListener<lk.RoomEvent>? _listener;
  LiveKitJoinInfo? _joinInfo;
  bool _disposed = false;
  Future<void>? _joinFuture;
  Future<void>? _leaveFuture;
  Future<void>? _disposeFuture;

  final StreamController<MediaSessionState> _stateController =
      StreamController<MediaSessionState>.broadcast();
  final StreamController<MediaSnapshot> _snapshotController =
      StreamController<MediaSnapshot>.broadcast();
  final StreamController<MediaEvent> _eventController =
      StreamController<MediaEvent>.broadcast();

  /// Underlying LiveKit room for provider-specific advanced integrations.
  lk.Room? get liveKitRoom => _room;

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

  Future<void> _join(MediaJoinInfo rawJoinInfo) async {
    _ensureNotDisposed();
    if (state != MediaSessionState.idle &&
        state != MediaSessionState.ended &&
        state != MediaSessionState.failed) {
      throw const MediaError(
        code: MediaErrorCode.invalidState,
        message: 'This LiveKit session is already joining or active.',
        providerId: LiveKitJoinInfo.providerIdValue,
      );
    }
    if (rawJoinInfo is! LiveKitJoinInfo ||
        rawJoinInfo.providerId != providerId ||
        rawJoinInfo.role != role) {
      throw const MediaError(
        code: MediaErrorCode.invalidJoinInfo,
        message: 'Join information does not match this LiveKit session.',
        providerId: LiveKitJoinInfo.providerIdValue,
      );
    }

    _joinInfo = rawJoinInfo;
    _setState(MediaSessionState.joining);
    final room = lk.Room();
    _room = room;
    _attachRoomEvents(room);
    _setState(MediaSessionState.connecting);
    try {
      await room.connect(
        rawJoinInfo.url,
        rawJoinInfo.token,
        connectOptions: const lk.ConnectOptions(autoSubscribe: true),
      );
      final local = room.localParticipant;
      if (local == null) {
        throw const MediaError(
          code: MediaErrorCode.nativeError,
          message: 'LiveKit connected without a local participant.',
          providerId: LiveKitJoinInfo.providerIdValue,
        );
      }
      if (local.identity != rawJoinInfo.identity) {
        throw MediaError(
          code: MediaErrorCode.invalidJoinInfo,
          message:
              'LiveKit token identity "${local.identity}" does not match '
              'participantId "${rawJoinInfo.identity}".',
          providerId: providerId,
        );
      }
      _validatePermissions(local.permissions);
      _capabilities = _capabilitiesWithDataPermission(
        _capabilities,
        local.permissions.canPublishData,
      );
      _refreshSnapshot(clearLastError: true);
      _setState(MediaSessionState.connected);
    } on MediaError {
      await _tearDownRoom();
      _setState(MediaSessionState.failed);
      rethrow;
    } catch (error) {
      final mapped = _mapError(error, 'Unable to connect to the LiveKit room.');
      await _tearDownRoom();
      _setState(MediaSessionState.failed, error: mapped);
      throw mapped;
    }
  }

  void _validatePermissions(lk.ParticipantPermissions permissions) {
    if (!permissions.canSubscribe) {
      throw MediaError(
        code: MediaErrorCode.invalidJoinInfo,
        message: 'LiveKit credentials do not allow subscribing to media.',
        providerId: providerId,
      );
    }
    if (role == MediaRole.viewer && permissions.canPublish) {
      throw MediaError(
        code: MediaErrorCode.invalidJoinInfo,
        message: 'Viewer credentials must not grant media publish permission.',
        providerId: providerId,
      );
    }
    if (role.canPublishMedia && !permissions.canPublish) {
      throw MediaError(
        code: MediaErrorCode.invalidJoinInfo,
        message: 'Publisher credentials do not grant media publish permission.',
        providerId: providerId,
      );
    }
  }

  @override
  Future<void> leave() => _leaveFuture ??= _leave().whenComplete(() {
    _leaveFuture = null;
  });

  Future<void> _leave() async {
    if (_disposed) return;
    if (state == MediaSessionState.joining ||
        state == MediaSessionState.connecting) {
      await _joinFuture;
    }
    if (state == MediaSessionState.idle ||
        state == MediaSessionState.ended ||
        state == MediaSessionState.failed) {
      if (state != MediaSessionState.ended) {
        _setState(MediaSessionState.ended);
      }
      return;
    }
    if (state == MediaSessionState.disposed) return;
    _setState(MediaSessionState.leaving);
    try {
      await _room?.disconnect();
    } catch (error) {
      final mapped = _mapError(error, 'Unable to disconnect from LiveKit.');
      _reportFailure(mapped);
    }
    await _tearDownRoom();
    _setState(MediaSessionState.ended);
  }

  @override
  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    if (_disposed) return;
    if (_joinFuture != null) await _joinFuture;
    if (state.isActive || state == MediaSessionState.connecting) {
      await leave();
    } else {
      await _tearDownRoom();
    }
    _disposed = true;
    _setState(MediaSessionState.disposed);
    await _stateController.close();
    await _snapshotController.close();
    await _eventController.close();
  }

  @override
  Future<void> sendMessage(String message, {String topic = 'chat'}) async {
    _ensureActive();
    if (!capabilities.canSendData) {
      throw MediaError(
        code: MediaErrorCode.unsupportedFeature,
        message: 'This LiveKit token does not allow sending data.',
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
    if (topic.trim().isEmpty) {
      throw MediaError(
        code: MediaErrorCode.invalidArgument,
        message: 'Message topic must not be empty.',
        providerId: providerId,
      );
    }
    try {
      await _requireLocalParticipant().publishData(
        utf8.encode(message),
        reliable: true,
        topic: topic,
      );
    } catch (error) {
      throw _mapError(error, 'Unable to send LiveKit data.');
    }
  }

  lk.LocalParticipant _requireLocalParticipant() {
    final local = _room?.localParticipant;
    if (local == null) {
      throw MediaError(
        code: MediaErrorCode.sessionNotFound,
        message: 'The LiveKit local participant is unavailable.',
        providerId: providerId,
      );
    }
    return local;
  }

  lk.Room _requireRoom() {
    final room = _room;
    if (room == null) {
      throw MediaError(
        code: MediaErrorCode.sessionNotFound,
        message: 'The LiveKit room is unavailable.',
        providerId: providerId,
      );
    }
    return room;
  }

  void _ensureActive() {
    _ensureNotDisposed();
    if (!state.isActive) {
      throw MediaError(
        code: MediaErrorCode.invalidState,
        message: 'The LiveKit session is not active.',
        providerId: providerId,
      );
    }
  }

  void _ensureNotDisposed() {
    if (_disposed || state == MediaSessionState.disposed) {
      throw MediaError(
        code: MediaErrorCode.invalidState,
        message: 'The LiveKit session has been disposed.',
        providerId: providerId,
      );
    }
  }

  void _attachRoomEvents(lk.Room room) {
    final listener = room.createListener();
    _listener = listener;
    listener.on<lk.RoomReconnectingEvent>((_) {
      _setState(MediaSessionState.reconnecting);
    });
    listener.on<lk.RoomResumingEvent>((_) {
      _setState(MediaSessionState.reconnecting);
    });
    listener.on<lk.RoomReconnectedEvent>((_) {
      _refreshSnapshot();
      _setState(MediaSessionState.connected);
    });
    listener.on<lk.RoomDisconnectedEvent>((event) {
      if (state == MediaSessionState.leaving ||
          state == MediaSessionState.disposed) {
        return;
      }
      _setState(MediaSessionState.ended, reason: event.reason?.toString());
    });
    listener.on<lk.ParticipantConnectedEvent>((event) {
      final participant = _mapRemoteParticipant(event.participant);
      _refreshSnapshot();
      _emit(MediaParticipantJoined(participant));
    });
    listener.on<lk.ParticipantDisconnectedEvent>((event) {
      final participant = event.participant;
      _refreshSnapshot();
      _emit(
        MediaParticipantLeft(
          participantId: participant.identity,
          displayName: participant.name.isEmpty ? null : participant.name,
        ),
      );
    });
    listener.on<lk.TrackSubscribedEvent>((event) {
      _refreshSnapshot();
      final track = _videoTrack(
        event.publication,
        event.track,
        event.participant.identity,
        isLocal: false,
      );
      if (track != null) _emit(MediaTrackPublished(track));
    });
    listener.on<lk.TrackUnsubscribedEvent>((event) {
      _refreshSnapshot();
      if (event.publication.kind == lk.TrackType.VIDEO) {
        _emit(
          MediaTrackUnpublished(
            trackId: event.publication.sid,
            participantId: event.participant.identity,
            wasScreenShare: event.publication.isScreenShare,
          ),
        );
      }
    });
    listener.on<lk.LocalTrackPublishedEvent>((event) {
      _refreshSnapshot();
      final track = event.publication.track;
      if (track != null) {
        final mapped = _videoTrack(
          event.publication,
          track,
          event.participant.identity,
          isLocal: true,
        );
        if (mapped != null) _emit(MediaTrackPublished(mapped));
      }
    });
    listener.on<lk.LocalTrackUnpublishedEvent>((event) {
      _refreshSnapshot();
      if (event.publication.kind == lk.TrackType.VIDEO) {
        _emit(
          MediaTrackUnpublished(
            trackId: event.publication.sid,
            participantId: event.participant.identity,
            wasScreenShare: event.publication.isScreenShare,
          ),
        );
      }
    });
    listener.on<lk.TrackMutedEvent>((event) {
      _refreshSnapshot();
      _emitTrackMute(event.participant, event.publication, true);
    });
    listener.on<lk.TrackUnmutedEvent>((event) {
      _refreshSnapshot();
      _emitTrackMute(event.participant, event.publication, false);
    });
    listener.on<lk.ActiveSpeakersChangedEvent>((event) {
      final before = <String, bool>{
        for (final participant in _snapshot.participants)
          participant.id: participant.isSpeaking,
      };
      _refreshSnapshot();
      final speakerIds = event.speakers.map((item) => item.identity).toSet();
      for (final participant in _snapshot.participants) {
        final speaking = speakerIds.contains(participant.id);
        if ((before[participant.id] ?? false) != speaking) {
          _emit(
            MediaSpeakingChanged(
              participantId: participant.id,
              isSpeaking: speaking,
            ),
          );
        }
      }
    });
    listener.on<lk.DataReceivedEvent>((event) {
      final sender = event.participant;
      final message = MediaMessage(
        participantId: sender?.identity ?? 'server',
        displayName: sender == null || sender.name.isEmpty ? '' : sender.name,
        message: utf8.decode(event.data, allowMalformed: true),
        topic: event.topic?.trim().isNotEmpty == true ? event.topic! : 'data',
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      );
      _replaceSnapshot(
        _snapshot.copyWith(messages: [..._snapshot.messages, message]),
      );
      _emit(MediaMessageReceived(message));
    });
  }

  void _emitTrackMute(
    lk.Participant<lk.TrackPublication<lk.Track>> participant,
    lk.TrackPublication<lk.Track> publication,
    bool muted,
  ) {
    final kind = publication.source == lk.TrackSource.screenShareVideo
        ? MediaTrackKind.screenShare
        : publication.kind == lk.TrackType.AUDIO
        ? MediaTrackKind.audio
        : MediaTrackKind.video;
    _emit(
      MediaTrackMutedChanged(
        participantId: participant.identity,
        trackId: publication.sid,
        muted: muted,
        kind: kind,
      ),
    );
  }

  void _refreshSnapshot({bool clearLastError = false}) {
    final room = _room;
    if (room == null) return;
    final participants = <MediaParticipant>[];
    final local = room.localParticipant;
    if (local != null) participants.add(_mapLocalParticipant(local));
    participants.addAll(
      room.remoteParticipants.values.map(_mapRemoteParticipant),
    );
    final screenShare = _findScreenShare(room);
    _replaceSnapshot(
      MediaSnapshot(
        state: _snapshot.state,
        role: role,
        participants: participants,
        messages: _snapshot.messages,
        localParticipantId: local?.identity ?? _joinInfo?.participantId,
        localMuted: local?.isMuted ?? true,
        localVideoEnabled: local?.isCameraEnabled() ?? false,
        contentShareTrack: screenShare,
        capabilities: _capabilities,
        lastError: clearLastError ? null : _snapshot.lastError,
      ),
    );
  }

  MediaParticipant _mapLocalParticipant(lk.LocalParticipant participant) {
    final fallbackName = _joinInfo?.displayName ?? '';
    return MediaParticipant(
      id: participant.identity,
      displayName: participant.name.isNotEmpty
          ? participant.name
          : fallbackName.isNotEmpty
          ? fallbackName
          : participant.identity,
      isLocal: true,
      isMuted: participant.isMuted,
      isVideoEnabled: participant.isCameraEnabled(),
      isSpeaking: participant.isSpeaking,
      videoTrack: _cameraTrackLocal(participant),
      joinedAt: participant.joinedAt,
    );
  }

  MediaParticipant _mapRemoteParticipant(lk.RemoteParticipant participant) =>
      MediaParticipant(
        id: participant.identity,
        displayName: participant.name.isEmpty
            ? participant.identity
            : participant.name,
        isMuted: participant.isMuted,
        isVideoEnabled: participant.isCameraEnabled(),
        isSpeaking: participant.isSpeaking,
        videoTrack: _cameraTrackRemote(participant),
        joinedAt: participant.joinedAt,
      );

  LiveKitMediaVideoTrack? _cameraTrackLocal(lk.LocalParticipant participant) {
    final publication = participant.getTrackPublicationBySource(
      lk.TrackSource.camera,
    );
    final track = publication?.track;
    if (publication == null || track == null) return null;
    return _videoTrack(publication, track, participant.identity, isLocal: true);
  }

  LiveKitMediaVideoTrack? _cameraTrackRemote(lk.RemoteParticipant participant) {
    final publication = participant.getTrackPublicationBySource(
      lk.TrackSource.camera,
    );
    final track = publication?.track;
    if (publication == null || track == null) return null;
    return _videoTrack(
      publication,
      track,
      participant.identity,
      isLocal: false,
    );
  }

  LiveKitMediaVideoTrack? _findScreenShare(lk.Room room) {
    final local = room.localParticipant;
    if (local != null) {
      final publication = local.getTrackPublicationBySource(
        lk.TrackSource.screenShareVideo,
      );
      final track = publication?.track;
      if (publication != null && track != null) {
        final mapped = _videoTrack(
          publication,
          track,
          local.identity,
          isLocal: true,
        );
        if (mapped != null) return mapped;
      }
    }
    for (final participant in room.remoteParticipants.values) {
      final publication = participant.getTrackPublicationBySource(
        lk.TrackSource.screenShareVideo,
      );
      final track = publication?.track;
      if (publication != null && track != null) {
        final mapped = _videoTrack(
          publication,
          track,
          participant.identity,
          isLocal: false,
        );
        if (mapped != null) return mapped;
      }
    }
    return null;
  }

  LiveKitMediaVideoTrack? _videoTrack(
    lk.TrackPublication<lk.Track> publication,
    lk.Track track,
    String participantId, {
    required bool isLocal,
  }) {
    if (track is! lk.VideoTrack || publication.kind != lk.TrackType.VIDEO) {
      return null;
    }
    final dimensions = publication.dimensions;
    return LiveKitMediaVideoTrack(
      liveKitTrack: track,
      id: publication.sid,
      participantId: participantId,
      isLocal: isLocal,
      isScreenShare: publication.isScreenShare,
      width: dimensions?.width ?? 0,
      height: dimensions?.height ?? 0,
    );
  }

  void _setState(MediaSessionState next, {MediaError? error, String? reason}) {
    if (_snapshot.state == next && error == null) return;
    final previous = _snapshot.state;
    _replaceSnapshot(
      error == null
          ? _snapshot.copyWith(state: next)
          : _snapshot.copyWith(state: next, lastError: error),
    );
    if (!_stateController.isClosed) _stateController.add(next);
    _emit(
      MediaConnectionStateChanged(
        previous: previous,
        current: next,
        reason: reason,
      ),
    );
    if (error != null) _emit(MediaFailureEvent(error));
  }

  void _reportFailure(MediaError error) {
    _replaceSnapshot(_snapshot.copyWith(lastError: error));
    _emit(MediaFailureEvent(error));
  }

  void _replaceSnapshot(MediaSnapshot next) {
    _snapshot = next;
    if (!_snapshotController.isClosed) _snapshotController.add(next);
  }

  void _emit(MediaEvent event) {
    if (!_eventController.isClosed) _eventController.add(event);
  }

  Future<void> _tearDownRoom() async {
    final listener = _listener;
    _listener = null;
    if (listener != null) await listener.dispose();
    final room = _room;
    _room = null;
    if (room != null && !room.isDisposed) await room.dispose();
  }

  MediaError _mapError(Object error, String fallbackMessage) {
    if (error is MediaError) return error.withProvider(providerId);
    final text = error.toString().toLowerCase();
    final code = text.contains('permission') || text.contains('denied')
        ? MediaErrorCode.permissionDenied
        : text.contains('disposed') || text.contains('not connected')
        ? MediaErrorCode.sessionNotFound
        : MediaErrorCode.nativeError;
    return MediaError(
      code: code,
      message: fallbackMessage,
      details: error,
      providerId: providerId,
    );
  }
}

/// LiveKit session for a symmetric meeting participant.
class LiveKitInteractiveSession extends LiveKitMediaSessionBase
    implements InteractiveMediaSession {
  LiveKitInteractiveSession({super.role = MediaRole.participant})
    : assert(role != MediaRole.viewer),
      super(
        capabilities: role == MediaRole.host
            ? const MediaCapabilities.broadcastHost()
            : _interactiveCapabilities,
      );

  @override
  Future<void> setMuted(bool muted) async {
    _ensureActive();
    if (!capabilities.canPublishAudio) _unsupported('microphone publishing');
    try {
      await _requireLocalParticipant().setMicrophoneEnabled(!muted);
      _refreshSnapshot();
      _emit(MediaLocalMediaChanged(muted: muted));
    } catch (error) {
      throw _mapError(error, 'Unable to change LiveKit microphone state.');
    }
  }

  @override
  Future<void> toggleMute() => setMuted(!snapshot.localMuted);

  @override
  Future<void> setVideoEnabled(bool enabled) async {
    _ensureActive();
    if (!capabilities.canPublishVideo) _unsupported('camera publishing');
    try {
      await _requireLocalParticipant().setCameraEnabled(enabled);
      _refreshSnapshot();
      _emit(MediaLocalMediaChanged(videoEnabled: enabled));
    } catch (error) {
      throw _mapError(error, 'Unable to change LiveKit camera state.');
    }
  }

  @override
  Future<void> setScreenShareEnabled(bool enabled) async {
    _ensureActive();
    if (!capabilities.canScreenShare) _unsupported('screen sharing');
    try {
      await _requireLocalParticipant().setScreenShareEnabled(enabled);
      _refreshSnapshot();
    } catch (error) {
      throw _mapError(error, 'Unable to change LiveKit screen-share state.');
    }
  }

  @override
  Future<void> switchCamera(MediaCameraPosition position) async {
    _ensureActive();
    if (!capabilities.canSwitchCamera) _unsupported('camera switching');
    final publication = _requireLocalParticipant().getTrackPublicationBySource(
      lk.TrackSource.camera,
    );
    final track = publication?.track;
    if (track is! lk.LocalVideoTrack) {
      throw MediaError(
        code: MediaErrorCode.invalidState,
        message: 'Enable the local camera before switching it.',
        providerId: providerId,
      );
    }
    try {
      await track.setCameraPosition(
        position == MediaCameraPosition.front
            ? lk.CameraPosition.front
            : lk.CameraPosition.back,
      );
      _refreshSnapshot();
    } catch (error) {
      throw _mapError(error, 'Unable to switch the LiveKit camera.');
    }
  }

  @override
  Future<List<MediaAudioDevice>> listAudioDevices() async {
    _ensureActive();
    if (!capabilities.canEnumerateAudioDevices) {
      _unsupported('audio device enumeration');
    }
    try {
      final devices = await lk.Hardware.instance.audioOutputs();
      return devices
          .map(
            (device) => MediaAudioDevice(
              id: device.deviceId,
              label: device.label,
              type: MediaAudioDevice.fromLabel(device.label).type,
            ),
          )
          .toList(growable: false);
    } catch (error) {
      throw _mapError(error, 'Unable to enumerate LiveKit audio outputs.');
    }
  }

  @override
  Future<void> selectAudioDevice(MediaAudioDevice device) async {
    _ensureActive();
    final id = device.id?.trim();
    final outputs = await lk.Hardware.instance.audioOutputs();
    lk.MediaDevice? selected;
    for (final candidate in outputs) {
      if ((id != null && id.isNotEmpty && candidate.deviceId == id) ||
          candidate.label == device.label) {
        selected = candidate;
        break;
      }
    }
    if (selected == null) {
      throw MediaError(
        code: MediaErrorCode.invalidArgument,
        message: 'The requested audio output is no longer available.',
        providerId: providerId,
      );
    }
    try {
      await _requireRoom().setAudioOutputDevice(selected);
    } catch (error) {
      throw _mapError(error, 'Unable to select the LiveKit audio output.');
    }
  }

  Never _unsupported(String feature) => throw MediaError(
    code: MediaErrorCode.unsupportedFeature,
    message: 'LiveKit $feature is not supported for this session.',
    providerId: providerId,
  );
}

/// LiveKit one-to-many broadcast host.
class LiveKitHostSession extends LiveKitInteractiveSession
    implements BroadcastHostSession {
  LiveKitHostSession() : super(role: MediaRole.host);
}

/// LiveKit subscribe-only broadcast viewer.
class LiveKitViewerSession extends LiveKitMediaSessionBase
    implements BroadcastViewerSession {
  LiveKitViewerSession()
    : super(
        role: MediaRole.viewer,
        capabilities: const MediaCapabilities.broadcastViewer(),
      );
}

MediaCapabilities _capabilitiesWithDataPermission(
  MediaCapabilities current,
  bool canSendData,
) => MediaCapabilities(
  canPublishAudio: current.canPublishAudio,
  canPublishVideo: current.canPublishVideo,
  canSwitchCamera: current.canSwitchCamera,
  canScreenShare: current.canScreenShare,
  canSendData: canSendData,
  canSubscribeVideo: current.canSubscribeVideo,
  canEnumerateAudioDevices: current.canEnumerateAudioDevices,
  maxVideoSubscriptions: current.maxVideoSubscriptions,
);
