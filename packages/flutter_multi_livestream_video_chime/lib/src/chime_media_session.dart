import 'dart:async';

import 'package:flutter_aws_chime/flutter_aws_chime.dart' as chime;
import 'package:flutter_multi_livestream_video_core/flutter_multi_livestream_video_core.dart';

import 'chime_join_info.dart';
import 'chime_media_track.dart';

/// Adapts the existing [chime.ChimeMeetingSession] without changing its native bridge.
class ChimeMediaSession implements InteractiveMediaSession {
  ChimeMediaSession({chime.ChimeMeetingSession? session})
    : _session = session ?? chime.ChimeMeetingSession();

  final chime.ChimeMeetingSession _session;
  final _stateController = StreamController<MediaSessionState>.broadcast();
  final _snapshotController = StreamController<MediaSnapshot>.broadcast();
  final _eventController = StreamController<MediaEvent>.broadcast();
  final Set<String> _speakingParticipantIds = <String>{};

  StreamSubscription<chime.MeetingSnapshot>? _snapshotSubscription;
  StreamSubscription<chime.ChimeEvent>? _eventSubscription;
  MediaSnapshot _snapshot = MediaSnapshot(
    role: MediaRole.participant,
    capabilities: const MediaCapabilities.meeting(),
  );
  bool _disposed = false;
  Future<void>? _joinFuture;
  Future<void>? _leaveFuture;
  Future<void>? _disposeFuture;

  /// Existing provider session for advanced Chime-specific integrations.
  chime.ChimeMeetingSession get chimeSession => _session;

  @override
  String get providerId => ChimeJoinInfo.providerIdValue;

  @override
  MediaRole get role => MediaRole.participant;

  @override
  MediaCapabilities get capabilities => const MediaCapabilities.meeting();

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
    if (rawJoinInfo is! ChimeJoinInfo || rawJoinInfo.role != role) {
      throw const MediaError(
        code: MediaErrorCode.invalidJoinInfo,
        message: 'Join information does not match this Chime session.',
        providerId: ChimeJoinInfo.providerIdValue,
      );
    }
    if (state != MediaSessionState.idle &&
        state != MediaSessionState.ended &&
        state != MediaSessionState.failed) {
      throw const MediaError(
        code: MediaErrorCode.invalidState,
        message: 'This Chime session is already joining or active.',
        providerId: ChimeJoinInfo.providerIdValue,
      );
    }

    _attachProviderStreams();
    try {
      await _session.join(rawJoinInfo.chimeJoinInfo);
      _onProviderSnapshot(_session.snapshot, clearLastError: true);
    } on chime.ChimeException catch (error) {
      final mapped = _mapError(error);
      _replaceSnapshot(_snapshot.copyWith(lastError: mapped));
      _emit(MediaFailureEvent(mapped));
      throw mapped;
    } catch (error) {
      final mapped = MediaError(
        code: MediaErrorCode.unknown,
        message: 'Unable to join the Chime meeting.',
        details: error,
        providerId: providerId,
      );
      _replaceSnapshot(_snapshot.copyWith(lastError: mapped));
      _emit(MediaFailureEvent(mapped));
      throw mapped;
    }
  }

  void _attachProviderStreams() {
    _snapshotSubscription ??= _session.snapshots.listen(_onProviderSnapshot);
    _eventSubscription ??= _session.events.listen(_onProviderEvent);
    _onProviderSnapshot(_session.snapshot);
  }

  @override
  Future<void> leave() => _leaveFuture ??= _leave().whenComplete(() {
    _leaveFuture = null;
  });

  Future<void> _leave() async {
    if (_disposed || state == MediaSessionState.disposed) return;
    try {
      await _session.leave();
      _onProviderSnapshot(_session.snapshot);
    } on chime.ChimeException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    if (_disposed) return;
    try {
      await _session.dispose();
      _onProviderSnapshot(_session.snapshot);
    } on chime.ChimeException catch (error) {
      throw _mapError(error);
    } finally {
      _disposed = true;
      await _snapshotSubscription?.cancel();
      await _eventSubscription?.cancel();
      _snapshotSubscription = null;
      _eventSubscription = null;
      if (_snapshot.state != MediaSessionState.disposed) {
        _transition(MediaSessionState.disposed);
      }
      await _stateController.close();
      await _snapshotController.close();
      await _eventController.close();
    }
  }

  @override
  Future<void> setMuted(bool muted) async {
    _ensureActive();
    try {
      await _session.setMuted(muted);
      _onProviderSnapshot(_session.snapshot);
    } on chime.ChimeException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<void> toggleMute() async {
    _ensureActive();
    try {
      await _session.toggleMute();
      _onProviderSnapshot(_session.snapshot);
    } on chime.ChimeException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<void> setVideoEnabled(bool enabled) async {
    _ensureActive();
    try {
      await _session.setVideoEnabled(enabled);
      _onProviderSnapshot(_session.snapshot);
    } on chime.ChimeException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<void> setScreenShareEnabled(bool enabled) async {
    throw MediaError(
      code: MediaErrorCode.unsupportedFeature,
      message: 'Outgoing screen share is not implemented by flutter_aws_chime.',
      providerId: providerId,
    );
  }

  @override
  Future<void> switchCamera(MediaCameraPosition position) async {
    _ensureActive();
    try {
      await _session.switchCamera(
        position == MediaCameraPosition.front
            ? chime.CameraPosition.front
            : chime.CameraPosition.back,
      );
    } on chime.ChimeException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<List<MediaAudioDevice>> listAudioDevices() async {
    _ensureActive();
    try {
      final devices = await _session.listAudioDevices();
      return devices.map(_mapAudioDevice).toList(growable: false);
    } on chime.ChimeException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<void> selectAudioDevice(MediaAudioDevice device) async {
    _ensureActive();
    try {
      await _session.selectAudioDevice(
        chime.ChimeAudioDevice.fromLabel(device.label),
      );
    } on chime.ChimeException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<void> sendMessage(String message, {String topic = 'chat'}) async {
    _ensureActive();
    try {
      await _session.sendMessage(message, topic: topic);
      _onProviderSnapshot(_session.snapshot);
    } on chime.ChimeException catch (error) {
      throw _mapError(error);
    }
  }

  void _onProviderSnapshot(
    chime.MeetingSnapshot providerSnapshot, {
    bool clearLastError = false,
  }) {
    if (_disposed && _snapshotController.isClosed) return;
    final previous = _snapshot;
    final next = _mapSnapshot(providerSnapshot, clearLastError: clearLastError);
    _replaceSnapshot(next);
    _emitSnapshotDiff(previous, next);
  }

  MediaSnapshot _mapSnapshot(
    chime.MeetingSnapshot providerSnapshot, {
    required bool clearLastError,
  }) {
    final participants = providerSnapshot.attendees
        .map(
          (attendee) => MediaParticipant(
            id: attendee.attendeeId,
            displayName: attendee.externalUserId.isEmpty
                ? attendee.attendeeId
                : attendee.externalUserId,
            isLocal: attendee.isLocal,
            isMuted: attendee.isMuted,
            isVideoEnabled: attendee.isVideoEnabled,
            isSpeaking: _speakingParticipantIds.contains(attendee.attendeeId),
            videoTrack: attendee.videoTile == null
                ? null
                : ChimeMediaVideoTrack(attendee.videoTile!),
            joinedAt: attendee.joinedAt,
          ),
        )
        .toList(growable: false);
    final messages = providerSnapshot.messages
        .map(
          (message) => MediaMessage(
            participantId: message.attendeeId,
            displayName: message.externalUserId,
            message: message.message,
            topic: message.topic,
            timestampMs: message.timestampMs,
          ),
        )
        .toList(growable: false);
    return MediaSnapshot(
      state: _mapState(providerSnapshot.state),
      role: role,
      participants: participants,
      messages: messages,
      localParticipantId: providerSnapshot.localAttendeeId,
      localMuted: providerSnapshot.localMuted,
      localVideoEnabled: providerSnapshot.localVideoEnabled,
      contentShareTrack: providerSnapshot.contentShareTile == null
          ? null
          : ChimeMediaVideoTrack(providerSnapshot.contentShareTile!),
      capabilities: capabilities,
      lastError: clearLastError ? null : _snapshot.lastError,
    );
  }

  void _emitSnapshotDiff(MediaSnapshot previous, MediaSnapshot next) {
    if (previous.state != next.state) {
      if (!_stateController.isClosed) _stateController.add(next.state);
      _emit(
        MediaConnectionStateChanged(
          previous: previous.state,
          current: next.state,
        ),
      );
    }

    final oldParticipants = {
      for (final item in previous.participants) item.id: item,
    };
    final newParticipants = {
      for (final item in next.participants) item.id: item,
    };
    for (final participant in next.participants) {
      final old = oldParticipants[participant.id];
      if (old == null && !participant.isLocal) {
        _emit(MediaParticipantJoined(participant));
      }
      final oldTrack = old?.videoTrack;
      final newTrack = participant.videoTrack;
      if (oldTrack == null && newTrack != null) {
        _emit(MediaTrackPublished(newTrack));
      } else if (oldTrack != null && newTrack == null) {
        _emit(
          MediaTrackUnpublished(
            trackId: oldTrack.id,
            participantId: participant.id,
          ),
        );
      } else if (oldTrack != null &&
          newTrack != null &&
          oldTrack.id != newTrack.id) {
        _emit(
          MediaTrackUnpublished(
            trackId: oldTrack.id,
            participantId: participant.id,
          ),
        );
        _emit(MediaTrackPublished(newTrack));
      }
      if (old != null && old.isMuted != participant.isMuted) {
        _emit(
          MediaTrackMutedChanged(
            participantId: participant.id,
            muted: participant.isMuted,
            kind: MediaTrackKind.audio,
          ),
        );
      }
    }
    for (final participant in previous.participants) {
      if (!participant.isLocal &&
          !newParticipants.containsKey(participant.id)) {
        _emit(
          MediaParticipantLeft(
            participantId: participant.id,
            displayName: participant.displayName,
          ),
        );
      }
    }

    if (previous.localMuted != next.localMuted ||
        previous.localVideoEnabled != next.localVideoEnabled) {
      _emit(
        MediaLocalMediaChanged(
          muted: previous.localMuted == next.localMuted
              ? null
              : next.localMuted,
          videoEnabled: previous.localVideoEnabled == next.localVideoEnabled
              ? null
              : next.localVideoEnabled,
        ),
      );
    }

    if (next.messages.length > previous.messages.length) {
      for (final message in next.messages.skip(previous.messages.length)) {
        _emit(MediaMessageReceived(message));
      }
    }

    final oldContent = previous.contentShareTrack;
    final newContent = next.contentShareTrack;
    if (oldContent == null && newContent != null) {
      _emit(MediaTrackPublished(newContent));
    } else if (oldContent != null && newContent == null) {
      _emit(
        MediaTrackUnpublished(
          trackId: oldContent.id,
          participantId: oldContent.participantId,
          wasScreenShare: true,
        ),
      );
    }
  }

  void _onProviderEvent(chime.ChimeEvent event) {
    if (event is chime.AttendeeVolumeEvent) {
      final speaking = switch (event.volumeLevel) {
        chime.MeetingVolumeLevel.low ||
        chime.MeetingVolumeLevel.medium ||
        chime.MeetingVolumeLevel.high => true,
        chime.MeetingVolumeLevel.muted ||
        chime.MeetingVolumeLevel.notSpeaking => false,
        chime.MeetingVolumeLevel.unknown => _speakingParticipantIds.contains(
          event.attendeeId,
        ),
      };
      final wasSpeaking = _speakingParticipantIds.contains(event.attendeeId);
      if (speaking) {
        _speakingParticipantIds.add(event.attendeeId);
      } else {
        _speakingParticipantIds.remove(event.attendeeId);
      }
      if (speaking != wasSpeaking) {
        _onProviderSnapshot(_session.snapshot);
        _emit(
          MediaSpeakingChanged(
            participantId: event.attendeeId,
            isSpeaking: speaking,
          ),
        );
      }
      return;
    }

    if (event is chime.VideoTileEvent &&
        (event.kind == chime.VideoTileEventKind.paused ||
            event.kind == chime.VideoTileEventKind.resumed)) {
      final tile = event.videoTile;
      _emit(
        MediaTrackMutedChanged(
          participantId: tile.attendeeId,
          trackId: ChimeMediaVideoTrack(tile).id,
          muted: event.kind == chime.VideoTileEventKind.paused,
          kind: tile.isContentShare
              ? MediaTrackKind.screenShare
              : MediaTrackKind.video,
        ),
      );
    }
  }

  void _transition(MediaSessionState next) {
    if (_snapshot.state == next) return;
    final previous = _snapshot.state;
    _replaceSnapshot(_snapshot.copyWith(state: next));
    if (!_stateController.isClosed) _stateController.add(next);
    _emit(MediaConnectionStateChanged(previous: previous, current: next));
  }

  void _replaceSnapshot(MediaSnapshot snapshot) {
    _snapshot = snapshot;
    if (!_snapshotController.isClosed) _snapshotController.add(snapshot);
  }

  void _emit(MediaEvent event) {
    if (!_eventController.isClosed) _eventController.add(event);
  }

  void _ensureNotDisposed() {
    if (_disposed || state == MediaSessionState.disposed) {
      throw MediaError(
        code: MediaErrorCode.invalidState,
        message: 'This Chime adapter session has been disposed.',
        providerId: providerId,
      );
    }
  }

  void _ensureActive() {
    _ensureNotDisposed();
    if (!state.isActive) {
      throw MediaError(
        code: MediaErrorCode.invalidState,
        message: 'The Chime session is not active.',
        providerId: providerId,
      );
    }
  }
}

MediaSessionState _mapState(chime.MeetingState state) => switch (state) {
  chime.MeetingState.idle => MediaSessionState.idle,
  chime.MeetingState.joining => MediaSessionState.joining,
  chime.MeetingState.connecting => MediaSessionState.connecting,
  chime.MeetingState.connected => MediaSessionState.connected,
  chime.MeetingState.reconnecting => MediaSessionState.reconnecting,
  chime.MeetingState.leaving => MediaSessionState.leaving,
  chime.MeetingState.ended => MediaSessionState.ended,
  chime.MeetingState.failed => MediaSessionState.failed,
  chime.MeetingState.disposed => MediaSessionState.disposed,
};

MediaAudioDevice _mapAudioDevice(chime.ChimeAudioDevice device) =>
    MediaAudioDevice(
      label: device.label,
      type: switch (device.type) {
        chime.ChimeAudioDeviceType.bluetooth => MediaAudioDeviceType.bluetooth,
        chime.ChimeAudioDeviceType.wiredHeadset =>
          MediaAudioDeviceType.wiredHeadset,
        chime.ChimeAudioDeviceType.speaker => MediaAudioDeviceType.speaker,
        chime.ChimeAudioDeviceType.earpiece => MediaAudioDeviceType.earpiece,
        chime.ChimeAudioDeviceType.other => MediaAudioDeviceType.other,
      },
    );

MediaError _mapError(chime.ChimeException error) => MediaError(
  code: switch (error.code) {
    chime.ChimeErrorCode.invalidJoinInfo => MediaErrorCode.invalidJoinInfo,
    chime.ChimeErrorCode.invalidArgument => MediaErrorCode.invalidArgument,
    chime.ChimeErrorCode.invalidState => MediaErrorCode.invalidState,
    chime.ChimeErrorCode.meetingAlreadyActive =>
      MediaErrorCode.sessionAlreadyActive,
    chime.ChimeErrorCode.permissionDenied => MediaErrorCode.permissionDenied,
    chime.ChimeErrorCode.unsupportedPlatform =>
      MediaErrorCode.unsupportedPlatform,
    chime.ChimeErrorCode.sessionNotFound => MediaErrorCode.sessionNotFound,
    chime.ChimeErrorCode.methodNotImplemented =>
      MediaErrorCode.unsupportedFeature,
    chime.ChimeErrorCode.nativeError => MediaErrorCode.nativeError,
    chime.ChimeErrorCode.unknown => MediaErrorCode.unknown,
  },
  message: error.message,
  details: error.details,
  providerId: ChimeJoinInfo.providerIdValue,
);
