import 'livekit_device_controller.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart' as lk;

import 'livekit_join_info.dart';
import 'livekit_media_track.dart';
import 'livekit_processed_video.dart';
import 'package:flutter_realtime_video_effects/flutter_realtime_video_effects.dart';

const _androidScreenShareChannel = MethodChannel(
  'flutter_realtime_media_livekit/screen_share',
);

MediaCapabilities _capabilitiesForRole(MediaRole role) {
  final canSelectAudioInput =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows);
  final canSelectAudioOutput =
      !kIsWeb && defaultTargetPlatform != TargetPlatform.iOS;
  final isViewer = role == MediaRole.viewer;
  final isHost = role == MediaRole.host;
  return MediaCapabilities(
    canPublishAudio: !isViewer,
    canPublishVideo: !isViewer,
    canBlurBackground:
        !isViewer &&
        (kIsWeb ||
            defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.macOS),
    canReplaceBackgroundImage:
        !isViewer &&
        (kIsWeb ||
            defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.macOS),
    canSwitchCamera:
        !isViewer &&
        (kIsWeb ||
            defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS),
    // LiveKit's Flutter Web SDK does not support screen capture on mobile
    // browsers, even though desktop browsers support getDisplayMedia.
    canScreenShare: !isViewer && (!kIsWeb || !lk.lkPlatformIsWebMobile()),
    canSendData: true,
    canReceiveData: true,
    canSubscribeVideo: true,
    canEnumerateAudioDevices: true,
    canEnumerateMicrophones: !isViewer,
    canEnumerateCameras: !isViewer,
    canSelectMicrophone: !isViewer && (kIsWeb || canSelectAudioInput),
    canSelectCamera: !isViewer,
    canSelectAudioOutput: canSelectAudioOutput,
    canTargetData: true,
    canSendUnreliableData: true,
    canReportNetworkStats: true,
    maxDataMessageBytes: 15 * 1024,
    canListParticipants: isHost,
    canRemoveParticipants: isHost,
    canCloseRoom: isHost,
  );
}

/// Shared LiveKit lifecycle and event translation.
abstract class LiveKitMediaSessionBase
    implements
        MediaSession,
        MediaDataMessenger,
        MediaAdvancedDataMessenger,
        MediaDeviceController,
        MediaStatsProvider {
  LiveKitMediaSessionBase({
    required this.role,
    required MediaCapabilities capabilities,
    lk.Room Function()? roomFactory,
  }) : _roomFactory = roomFactory ?? lk.Room.new,
       _capabilities = capabilities,
       _snapshot = MediaSnapshot(role: role, capabilities: capabilities);

  @override
  String get providerId => LiveKitJoinInfo.providerIdValue;

  @override
  final MediaRole role;

  MediaCapabilities _capabilities;
  MediaSnapshot _snapshot;
  final lk.Room Function() _roomFactory;
  lk.Room? _room;
  lk.EventsListener<lk.RoomEvent>? _listener;
  LiveKitJoinInfo? _joinInfo;
  bool _disposed = false;
  bool _leaveRequestedDuringJoin = false;
  Duration cleanupTimeout = const Duration(seconds: 10);
  Future<void>? _joinFuture;
  Future<void>? _leaveFuture;
  Future<void>? _disposeFuture;
  bool _androidScreenShareServiceStarted = false;

  final StreamController<MediaSessionState> _stateController =
      StreamController<MediaSessionState>.broadcast();
  final StreamController<MediaSnapshot> _snapshotController =
      StreamController<MediaSnapshot>.broadcast();
  final StreamController<MediaEvent> _eventController =
      StreamController<MediaEvent>.broadcast();
  final StreamController<MediaConnectionStats> _statsController =
      StreamController<MediaConnectionStats>.broadcast();
  MediaConnectionStats? _connectionStats;

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
  MediaConnectionStats? get connectionStats => _connectionStats;

  @override
  Stream<MediaConnectionStats> get stats => _statsController.stream;

  @override
  Future<void> join(MediaJoinInfo joinInfo) {
    final current = _joinFuture;
    if (current != null) {
      if (_leaveRequestedDuringJoin) {
        return Future.error(
          const RealtimeException(
            code: RealtimeErrorCode.cancelled,
            message: 'The previous LiveKit join is still being cancelled.',
            providerId: LiveKitJoinInfo.providerIdValue,
          ),
        );
      }
      return current;
    }
    _leaveRequestedDuringJoin = false;
    late final Future<void> future;
    future = _join(joinInfo).whenComplete(() {
      if (identical(_joinFuture, future)) _joinFuture = null;
    });
    _joinFuture = future;
    return future;
  }

  late final _devices = LiveKitDeviceController(
    capabilities: () => capabilities,
    requireRoom: _requireRoom,
    ensureActive: _ensureActive,
  );
  @override
  Future<List<MediaDevice>> listMediaDevices({Set<MediaDeviceKind>? kinds}) =>
      _devices.listMediaDevices(kinds: kinds);
  @override
  Future<void> selectMediaDevice(MediaDevice device) =>
      _devices.selectMediaDevice(device);

  Future<void> _join(MediaJoinInfo rawJoinInfo) async {
    _ensureNotDisposed();
    if (state != MediaSessionState.idle &&
        state != MediaSessionState.ended &&
        state != MediaSessionState.failed) {
      throw const RealtimeException(
        code: RealtimeErrorCode.invalidState,
        message: 'This LiveKit session is already joining or active.',
        providerId: LiveKitJoinInfo.providerIdValue,
      );
    }
    if (rawJoinInfo is! LiveKitJoinInfo ||
        rawJoinInfo.providerId != providerId ||
        rawJoinInfo.role != role) {
      throw const RealtimeException(
        code: RealtimeErrorCode.invalidArgument,
        message: 'Join information does not match this LiveKit session.',
        providerId: LiveKitJoinInfo.providerIdValue,
      );
    }

    _joinInfo = rawJoinInfo;
    _setState(MediaSessionState.joining);
    final room = _roomFactory();
    _room = room;
    _attachRoomEvents(room);
    _setState(MediaSessionState.connecting);
    try {
      await room.connect(
        rawJoinInfo.url,
        rawJoinInfo.token,
        connectOptions: const lk.ConnectOptions(autoSubscribe: true),
      );
      if (_disposed || _leaveRequestedDuringJoin) {
        throw const RealtimeException(
          code: RealtimeErrorCode.cancelled,
          message: 'Session is closing.',
        );
      }
      final local = room.localParticipant;
      if (local == null) {
        throw const RealtimeException(
          code: RealtimeErrorCode.providerError,
          message: 'LiveKit connected without a local participant.',
          providerId: LiveKitJoinInfo.providerIdValue,
        );
      }
      if (local.identity != rawJoinInfo.identity) {
        throw RealtimeException(
          code: RealtimeErrorCode.invalidArgument,
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
    } on RealtimeException catch (error, stack) {
      await _rollbackJoin(error, stack);
    } catch (error, stack) {
      final mapped = _mapError(
        error,
        'Unable to connect to the LiveKit room.',
        operation: 'join',
        stackTrace: stack,
      );
      await _rollbackJoin(mapped, stack);
    }
  }

  void _validatePermissions(lk.ParticipantPermissions permissions) {
    if (!permissions.canSubscribe) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidArgument,
        message: 'LiveKit credentials do not allow subscribing to media.',
        providerId: providerId,
      );
    }
    if (role == MediaRole.viewer && permissions.canPublish) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidArgument,
        message: 'Viewer credentials must not grant media publish permission.',
        providerId: providerId,
      );
    }
    if (role.canPublishMedia && !permissions.canPublish) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidArgument,
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
      _leaveRequestedDuringJoin = true;
      // Do not await the pending connect: some native SDK transports do not
      // complete that future when the user leaves. Tear down the room now;
      // a late connect result is rejected by _join's cancellation guard.
      await _tearDownRoom();
      if (!_disposed) _setState(MediaSessionState.ended);
      return;
    }
    if (_disposed) return;
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
      await _detachProcessedVideoBeforeRoomTeardown();
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
    _disposed = true;
    final cleanup = Cleanup(timeout: cleanupTimeout);
    await cleanup.run('join.pending', () async {
      try {
        await _joinFuture;
      } catch (_) {
        /* The join caller receives its failure. */
      }
    });
    await cleanup.run('engine', () async {
      await _tearDownRoom();
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

  @override
  Future<void> sendMessage(String message, {String topic = 'chat'}) =>
      sendDataMessage(message, options: MediaSendOptions(topic: topic));

  @override
  Future<void> sendDataMessage(
    String message, {
    MediaSendOptions options = const MediaSendOptions(),
  }) async {
    _ensureActive();
    if (!capabilities.canSendData) {
      throw RealtimeException(
        code: RealtimeErrorCode.unsupportedFeature,
        message: 'This LiveKit token does not allow sending data.',
        providerId: providerId,
      );
    }
    if (message.trim().isEmpty) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidArgument,
        message: 'Message must not be empty.',
        providerId: providerId,
      );
    }
    if (options.topic.trim().isEmpty) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidArgument,
        message: 'Message topic must not be empty.',
        providerId: providerId,
      );
    }
    try {
      await _requireLocalParticipant().publishData(
        utf8.encode(message),
        reliable: options.reliability == MediaDataReliability.reliable,
        destinationIdentities: options.targetParticipantIds.isEmpty
            ? null
            : options.targetParticipantIds,
        topic: options.topic,
      );
    } catch (error) {
      throw _mapError(error, 'Unable to send LiveKit data.');
    }
  }

  lk.LocalParticipant _requireLocalParticipant() {
    final local = _room?.localParticipant;
    if (local == null) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidState,
        message: 'The LiveKit local participant is unavailable.',
        providerId: providerId,
      );
    }
    return local;
  }

  lk.Room _requireRoom() {
    final room = _room;
    if (room == null) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidState,
        message: 'The LiveKit room is unavailable.',
        providerId: providerId,
      );
    }
    return room;
  }

  void _ensureActive() {
    _ensureNotDisposed();
    if (!state.isActive) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidState,
        message: 'The LiveKit session is not active.',
        providerId: providerId,
      );
    }
  }

  void _ensureNotDisposed() {
    if (_disposed || state == MediaSessionState.disposed) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidState,
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
    listener.on<lk.ParticipantConnectionQualityUpdatedEvent>((event) {
      final local = room.localParticipant;
      if (local == null || event.participant.identity != local.identity) return;
      final quality = switch (event.connectionQuality) {
        lk.ConnectionQuality.excellent => MediaNetworkQuality.excellent,
        lk.ConnectionQuality.good => MediaNetworkQuality.good,
        lk.ConnectionQuality.poor => MediaNetworkQuality.poor,
        lk.ConnectionQuality.lost => MediaNetworkQuality.down,
        _ => MediaNetworkQuality.unknown,
      };
      final value = MediaConnectionStats(
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        upstreamQuality: quality,
        downstreamQuality: quality,
      );
      _connectionStats = value;
      if (!_statsController.isClosed) _statsController.add(value);
      _emit(MediaNetworkStatsUpdated(value));
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
        providerId: providerId,
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
    final localScreenShareEnabled =
        local?.getTrackPublicationBySource(lk.TrackSource.screenShareVideo) !=
        null;
    _replaceSnapshot(
      MediaSnapshot(
        state: _snapshot.state,
        role: role,
        participants: participants,
        messages: _snapshot.messages,
        localParticipantId: local?.identity ?? _joinInfo?.participantId,
        localMuted: local?.isMuted ?? true,
        localVideoEnabled: local?.isCameraEnabled() ?? false,
        localScreenShareEnabled: localScreenShareEnabled,
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
    if (publication == null || publication.muted || track == null) return null;
    return _videoTrack(publication, track, participant.identity, isLocal: true);
  }

  LiveKitMediaVideoTrack? _cameraTrackRemote(lk.RemoteParticipant participant) {
    final publication = participant.getTrackPublicationBySource(
      lk.TrackSource.camera,
    );
    final track = publication?.track;
    if (publication == null || publication.muted || track == null) return null;
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

  void _setState(
    MediaSessionState next, {
    RealtimeException? error,
    String? reason,
  }) {
    if (_disposed) {
      if (next == MediaSessionState.disposed) {
        _snapshot = _snapshot.copyWith(state: next);
      }
      return;
    }
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

  void _reportFailure(RealtimeException error) {
    _replaceSnapshot(_snapshot.copyWith(lastError: error));
    _emit(MediaFailureEvent(error));
  }

  void _replaceSnapshot(MediaSnapshot next) {
    if (_disposed) return;
    _snapshot = next;
    if (!_snapshotController.isClosed) _snapshotController.add(next);
  }

  void _emit(MediaEvent event) {
    if (!_disposed && !_eventController.isClosed) _eventController.add(event);
  }

  Future<void> _detachProcessedVideoBeforeRoomTeardown() async {}

  Future<Never> _rollbackJoin(
    RealtimeException primary,
    StackTrace stack,
  ) async {
    final cleanup = Cleanup(timeout: cleanupTimeout);
    await cleanup.run('join.rollback', _tearDownRoom);
    if (!_leaveRequestedDuringJoin) {
      _setState(MediaSessionState.failed, error: primary);
    }
    cleanup.finish(domain: providerId, cause: primary);
    Error.throwWithStackTrace(primary, stack);
  }

  Future<void> _tearDownRoom() async {
    final room = _room;
    final listener = _listener;
    _listener = null;
    _room = null;
    final cleanup = Cleanup(timeout: cleanupTimeout);
    await cleanup.run(
      'processed.input',
      _detachProcessedVideoBeforeRoomTeardown,
    );
    await cleanup.run('screenShare.service', _stopAndroidScreenShareService);
    if (listener != null) await cleanup.run('room.listener', listener.dispose);
    if (room != null && !room.isDisposed) {
      await cleanup.run('room.dispose', room.dispose);
    }
    cleanup.finish(domain: providerId);
  }

  Future<void> _prepareAndroidScreenShare() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    // System annotation windows must be visible in the shared display; an
    // Android single-app projection excludes windows belonging to other apps.
    final permissionGranted = await rtc.Helper.requestCapturePermission(
      fullScreenOnly: true,
    );
    if (!permissionGranted) {
      throw RealtimeException(
        code: RealtimeErrorCode.permissionDenied,
        message: 'Screen-capture permission was denied.',
        providerId: providerId,
      );
    }

    await _androidScreenShareChannel.invokeMethod<void>('start');
    _androidScreenShareServiceStarted = true;
  }

  Future<void> _prepareMacOsScreenShare() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return;

    final permissionGranted = await rtc.Helper.requestCapturePermission();
    if (!permissionGranted) {
      throw RealtimeException(
        code: RealtimeErrorCode.permissionDenied,
        message:
            'LiveKit screen sharing needs macOS Screen Recording permission. '
            'Allow it in System Settings > Privacy & Security > Screen Recording, '
            'then restart the app.',
        providerId: providerId,
      );
    }
  }

  Future<void> _stopAndroidScreenShareService() async {
    if (!_androidScreenShareServiceStarted ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    _androidScreenShareServiceStarted = false;
    await _androidScreenShareChannel.invokeMethod<void>('stop');
  }

  RealtimeException _mapError(
    Object error,
    String fallbackMessage, {
    String? operation,
    StackTrace? stackTrace,
  }) {
    if (error is RealtimeException) {
      return normalizeRealtimeException(
        error,
        domain: 'media',
        operation: operation,
        providerId: providerId,
        stackTrace: stackTrace,
      );
    }
    final status = error is lk.ConnectException && error.statusCode != 0
        ? error.statusCode
        : null;
    final code = switch (error) {
      lk.ConnectException(statusCode: 401) =>
        RealtimeErrorCode.invalidCredential,
      lk.ConnectException(statusCode: 403) =>
        RealtimeErrorCode.permissionDenied,
      lk.ConnectException(reason: lk.ConnectionErrorReason.Timeout) ||
      lk.TimeoutException() ||
      TimeoutException() => RealtimeErrorCode.timeout,
      lk.ConnectException() ||
      lk.MediaConnectException() ||
      lk.CertificatePinningException() => RealtimeErrorCode.network,
      MissingPluginException() => RealtimeErrorCode.driverInitializationFailed,
      lk.UnexpectedStateException() ||
      StateError() => RealtimeErrorCode.invalidState,
      _ => RealtimeErrorCode.providerError,
    };
    return normalizeRealtimeException(
      RealtimeException(
        code: code,
        message: fallbackMessage,
        cause: error,
        details: {
          'causeType': error.runtimeType.toString(),
          if (error is lk.ConnectException)
            'connectionReason': error.reason.name,
        },
        statusCode: status,
      ),
      domain: 'media',
      operation: operation,
      providerId: providerId,
      stackTrace: stackTrace,
    );
  }
}

/// LiveKit session for a symmetric meeting participant.
class LiveKitInteractiveSession extends LiveKitMediaSessionBase
    implements InteractiveMediaSession, ProcessedVideoSink {
  LiveKitInteractiveSession({
    super.role = MediaRole.participant,
    super.roomFactory,
  }) : assert(role != MediaRole.viewer),
       super(capabilities: _capabilitiesForRole(role));

  ProcessedVideoSource? _processedSource;
  lk.LocalVideoTrack? _processedTrack;
  bool _processedPublished = false;

  @override
  bool supportsProcessedVideoSource(ProcessedVideoSource source) =>
      capabilities.canBlurBackground &&
      (kIsWeb
          ? source.platform == VideoEffectsPlatform.web &&
                source.kind == ProcessedVideoSourceKind.mediaStreamTrack
          : source.kind == ProcessedVideoSourceKind.nativeFrameHub &&
                ((defaultTargetPlatform == TargetPlatform.android &&
                        source.platform == VideoEffectsPlatform.android) ||
                    (defaultTargetPlatform == TargetPlatform.macOS &&
                        source.platform == VideoEffectsPlatform.macos)));

  @override
  Future<void> attachProcessedVideoSource(ProcessedVideoSource source) async {
    _ensureActive();
    if (!supportsProcessedVideoSource(source)) {
      _unsupported('processed video input');
    }
    await detachProcessedVideoSource();
    await _requireLocalParticipant().setCameraEnabled(false);
    try {
      _processedTrack = await createProcessedLiveKitTrack(source);
      _processedSource = source;
    } catch (_) {
      await disposeProcessedLiveKitTrack(source);
      rethrow;
    }
  }

  @override
  Future<void> detachProcessedVideoSource() async {
    final source = _processedSource;
    final track = _processedTrack;
    final published = _processedPublished;
    _processedSource = null;
    _processedTrack = null;
    _processedPublished = false;
    if (source == null) return;
    try {
      try {
        final sid = track?.sid;
        if (published && sid != null) {
          await _room?.localParticipant?.removePublishedTrack(sid);
        }
      } finally {
        await track?.dispose();
      }
    } finally {
      await disposeProcessedLiveKitTrack(source);
    }
  }

  @override
  Future<void> _detachProcessedVideoBeforeRoomTeardown() =>
      detachProcessedVideoSource();

  @override
  Future<List<MediaDevice>> listMediaDevices({
    Set<MediaDeviceKind>? kinds,
  }) async {
    if (_processedSource == null) return super.listMediaDevices(kinds: kinds);
    final requested = kinds ?? MediaDeviceKind.values.toSet();
    final devices = await super.listMediaDevices(
      kinds: requested.difference({MediaDeviceKind.camera}),
    );
    return List.unmodifiable([
      ...devices,
      if (requested.contains(MediaDeviceKind.camera))
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
    _ensureActive();
    final source = _processedSource;
    if (source != null && device.kind == MediaDeviceKind.camera) {
      await VideoEffectsBridge().selectCamera(source, device.id);
      return;
    }
    await super.selectMediaDevice(device);
  }

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
      final processed = _processedTrack;
      if (processed == null) {
        await _requireLocalParticipant().setCameraEnabled(enabled);
      } else if (enabled) {
        await VideoEffectsBridge().setEnabled(_processedSource!, true);
        if (!_processedPublished) {
          await _requireLocalParticipant().publishVideoTrack(processed);
          _processedPublished = true;
        } else {
          await processed.unmute(stopOnMute: false);
        }
      } else {
        await processed.mute(stopOnMute: false);
        await VideoEffectsBridge().setEnabled(_processedSource!, false);
      }
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
    var androidServicePrepared = false;
    try {
      if (enabled) {
        await _prepareAndroidScreenShare();
        androidServicePrepared = _androidScreenShareServiceStarted;
        await _prepareMacOsScreenShare();
      }
      await _requireLocalParticipant().setScreenShareEnabled(
        enabled,
        screenShareCaptureOptions:
            !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
            ? const lk.ScreenShareCaptureOptions(
                useiOSBroadcastExtension: false,
              )
            : null,
      );
      _refreshSnapshot();
      if (!enabled) await _stopAndroidScreenShareService();
    } catch (error) {
      if (enabled && androidServicePrepared) {
        await _stopAndroidScreenShareService();
      }
      throw _mapError(error, 'Unable to change LiveKit screen-share state.');
    }
  }

  @override
  Future<void> switchCamera(MediaCameraPosition position) async {
    _ensureActive();
    if (!capabilities.canSwitchCamera) _unsupported('camera switching');
    final source = _processedSource;
    if (source != null) {
      await VideoEffectsBridge().selectCamera(
        source,
        position == MediaCameraPosition.front ? 'front' : 'back',
      );
      return;
    }
    final publication = _requireLocalParticipant().getTrackPublicationBySource(
      lk.TrackSource.camera,
    );
    final track = publication?.track;
    if (track is! lk.LocalVideoTrack) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidState,
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
      throw RealtimeException(
        code: RealtimeErrorCode.invalidArgument,
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

  Never _unsupported(String feature) => throw RealtimeException(
    code: RealtimeErrorCode.unsupportedFeature,
    message: 'LiveKit $feature is not supported for this session.',
    providerId: providerId,
  );
}

/// LiveKit one-to-many broadcast host.
class LiveKitHostSession extends LiveKitInteractiveSession
    implements BroadcastHostSession {
  LiveKitHostSession({super.roomFactory}) : super(role: MediaRole.host);
}

/// LiveKit subscribe-only broadcast viewer.
class LiveKitViewerSession extends LiveKitMediaSessionBase
    implements BroadcastViewerSession {
  LiveKitViewerSession({super.roomFactory})
    : super(
        role: MediaRole.viewer,
        capabilities: _capabilitiesForRole(MediaRole.viewer),
      );
}

MediaCapabilities _capabilitiesWithDataPermission(
  MediaCapabilities current,
  bool canSendData,
) => current.copyWith(canSendData: canSendData);
