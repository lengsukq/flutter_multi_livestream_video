part of 'agora_media_session.dart';

class _AgoraSnapshotMapper {
  _AgoraSnapshotMapper(this._session);
  final _AgoraMediaSession _session;
  String get providerId => _session.providerId;
  MediaCapabilities get capabilities => _session.capabilities;
  MediaRole get role => _session.role;
  MediaSessionState get state => _session.state;
  MediaSnapshot get snapshot => _session.snapshot;
  Duration get cleanupTimeout => _session.cleanupTimeout;

  int? _activeSpeakerUid;
  final Map<int, AgoraMediaVideoTrack> _remoteScreenTracks = {};
  final AgoraRemoteScreenState _remoteScreenState = AgoraRemoteScreenState();
  final Map<String, MediaParticipant> _participants = {};
  void _setRemoteVideoState(int uid, {required bool enabled}) {
    _remoteScreenState.onVideo(uid, available: enabled);
    final id = uid.toString();
    final before = _participants[id];
    final previousCamera = before?.videoTrack;
    final previousScreen = _remoteScreenTracks[uid];
    final sharing = _remoteScreenState.showsScreen(uid);
    final track = enabled && !sharing ? _videoTrack(uid, local: false) : null;
    final screen = sharing
        ? _videoTrack(uid, local: false, screenShare: true)
        : null;
    if (screen == null) {
      _remoteScreenTracks.remove(uid);
    } else {
      _remoteScreenTracks[uid] = screen;
    }
    final participant =
        (before ??
                MediaParticipant(
                  id: id,
                  displayName: id,
                  joinedAt: DateTime.now(),
                ))
            .copyWith(
              isVideoEnabled: track != null,
              videoTrack: track,
              clearVideoTrack: track == null,
            );
    _participants[id] = participant;
    _session._refreshSnapshot();
    if (previousCamera != null && track == null) {
      _session._emit(
        MediaTrackUnpublished(trackId: previousCamera.id, participantId: id),
      );
    }
    if (track != null && previousCamera == null) {
      _session._emit(MediaTrackPublished(track));
    }
    if (previousScreen != null && screen == null) {
      _session._emit(
        MediaTrackUnpublished(
          trackId: previousScreen.id,
          participantId: id,
          wasScreenShare: true,
        ),
      );
    }
    if (previousScreen == null && screen != null) {
      _session._emit(MediaTrackPublished(screen));
    }
  }

  void _setRemoteScreenPublisher(int uid, AgoraScreenShareSignal signal) {
    _remoteScreenState.onSignal(uid, signal);
    // An announcement may arrive before the first remote video frame.
    _setRemoteVideoState(uid, enabled: _remoteScreenState.videoAvailable(uid));
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
    if (emitSnapshot) _session._refreshSnapshot();
  }

  AgoraMediaVideoTrack? _videoTrack(
    int uid, {
    required bool local,
    bool screenShare = false,
  }) {
    final engine = _session._engine;
    final channel = _session._joinInfo?.channelName;
    if (engine == null || channel == null) return null;
    return AgoraMediaVideoTrack(
      engine: engine,
      channelId: channel,
      uid: uid,
      local: local,
      screenShare: screenShare,
      processedSource: local
          ? _session._publishing._processedSink.source
          : null,
    );
  }

  void _updateLocalParticipant() {
    final uid = _session._localUid;
    if (uid == null) return;
    final id = uid.toString();
    final current = _participants[id];
    final info = _session._joinInfo;
    _participants[id] = MediaParticipant(
      id: id,
      displayName:
          current?.displayName ??
          ((info?.displayName.isNotEmpty ?? false) ? info!.displayName : id),
      isLocal: true,
      isMuted: _session._publishing._localMuted,
      isVideoEnabled: _session._publishing._localVideoEnabled,
      isSpeaking: current?.isSpeaking ?? false,
      videoTrack: _session._publishing._localVideoEnabled
          ? _videoTrack(uid, local: true)
          : null,
      joinedAt: current?.joinedAt ?? DateTime.now(),
    );
  }
}
