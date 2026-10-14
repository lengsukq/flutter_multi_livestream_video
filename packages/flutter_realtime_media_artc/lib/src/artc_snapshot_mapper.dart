part of 'artc_media_session.dart';

class _ArtcSnapshotMapper {
  _ArtcSnapshotMapper(this._session);
  final _ArtcMediaSession _session;
  String get providerId => _session.providerId;
  MediaCapabilities get capabilities => _session.capabilities;
  MediaRole get role => _session.role;
  MediaSessionState get state => _session.state;
  MediaSnapshot get snapshot => _session.snapshot;
  Duration get cleanupTimeout => _session.cleanupTimeout;

  int _trackGeneration = 0;
  final Map<String, ArtcMediaVideoTrack> _remoteScreens = {};
  void _remoteScreenChanged(String userId, bool available) {
    if (userId == _session._joinInfo?.userId) return;
    _ensureRemoteParticipant(userId);
    final previous = _remoteScreens[userId];
    if (available) {
      if (previous != null) return;
      final next = ArtcMediaVideoTrack(
        userId: userId,
        local: false,
        screenShare: true,
        generation: _trackGeneration,
      );
      _remoteScreens[userId] = next;
      _session._emit(MediaTrackPublished(next));
    } else {
      if (previous == null) return;
      _remoteScreens.remove(userId);
      _session._emit(
        MediaTrackUnpublished(
          trackId: previous.id,
          participantId: userId,
          wasScreenShare: true,
        ),
      );
    }
    _session._setSnapshot(
      _session._snapshot.copyWith(
        contentShareTrack:
            _remoteScreens.values.lastOrNull ??
            _session._publishing._localScreenTrack,
        clearContentShareTrack:
            _remoteScreens.isEmpty &&
            _session._publishing._localScreenTrack == null,
      ),
    );
  }

  ArtcEngineEvents _createEngineEvents() {
    final generation = _session._connectionGeneration;
    final engine = _session._engine;
    bool currentLease() =>
        generation == _session._connectionGeneration &&
        identical(engine, _session._engine) &&
        !_session._disposed &&
        !state.isTerminal &&
        state != MediaSessionState.leaving;
    return ArtcEngineEvents(
      onError: (code, message) {
        if (currentLease()) _session._onNativeError(code, message);
      },
      onParticipantJoined: (id) {
        if (currentLease()) _participantJoined(id);
      },
      onParticipantLeft: (id) {
        if (currentLease()) _participantLeft(id);
      },
      onRemoteVideoChanged: (id, available) {
        if (currentLease()) _remoteVideoChanged(id, available);
      },
      onRemoteScreenChanged: (id, available) {
        if (currentLease()) _remoteScreenChanged(id, available);
      },
      onLocalScreenShareChanged: (available) {
        if (!currentLease()) return;
        if (_session._state.isActive && !_session._disposed) {
          _session._publishing._syncLocalScreenShare(available);
        }
      },
      onRemoteAudioChanged: (id, available) {
        if (currentLease()) _remoteAudioChanged(id, available);
      },
      onMessage: (id, message) {
        if (currentLease()) _session._data._receiveMessage(id, message);
      },
      onReconnecting: () {
        if (currentLease()) _session._setState(MediaSessionState.reconnecting);
      },
      onRecovered: () {
        if (!currentLease()) return;
        if (_session._state == MediaSessionState.reconnecting) {
          _session._setState(MediaSessionState.connected);
        }
      },
      onAuthWillExpire: () {
        if (currentLease()) {
          unawaited(_session._credentials._refreshAndRejoin());
        }
      },
    );
  }

  void _participantJoined(String userId) {
    if (userId.isEmpty || userId == _session._joinInfo?.userId) return;
    final existing = _session._snapshot.participants.where(
      (item) => item.id == userId,
    );
    if (existing.isNotEmpty) return;
    final participant = MediaParticipant(id: userId, displayName: userId);
    _session._setSnapshot(
      _session._snapshot.copyWith(
        participants: [..._session._snapshot.participants, participant],
      ),
    );
    _session._emit(MediaParticipantJoined(participant));
  }

  void _participantLeft(String userId) {
    final existing = _participantById(userId);
    if (existing == null || existing.isLocal) return;
    final shared = _remoteScreens.remove(userId);
    if (shared != null) {
      _session._emit(
        MediaTrackUnpublished(
          trackId: shared.id,
          participantId: userId,
          wasScreenShare: true,
        ),
      );
    }
    _session._setSnapshot(
      _session._snapshot.copyWith(
        participants: _session._snapshot.participants
            .where((item) => item.id != userId)
            .toList(),
        contentShareTrack:
            _remoteScreens.values.lastOrNull ??
            _session._publishing._localScreenTrack,
        clearContentShareTrack:
            _remoteScreens.isEmpty &&
            _session._publishing._localScreenTrack == null,
      ),
    );
    _session._emit(
      MediaParticipantLeft(
        participantId: userId,
        displayName: existing.displayName,
      ),
    );
  }

  void _remoteVideoChanged(String userId, bool available) {
    if (userId == _session._joinInfo?.userId) return;
    _ensureRemoteParticipant(userId);
    final participants = _session._snapshot.participants.map((item) {
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
    _session._setSnapshot(
      _session._snapshot.copyWith(participants: participants),
    );
    if (available) {
      final track = participants
          .firstWhere((item) => item.id == userId)
          .videoTrack!;
      _session._emit(MediaTrackPublished(track));
    } else {
      _session._emit(
        MediaTrackUnpublished(
          trackId: 'artc:$userId:camera:$_trackGeneration',
          participantId: userId,
        ),
      );
    }
  }

  void _remoteAudioChanged(String userId, bool available) {
    if (userId == _session._joinInfo?.userId) return;
    _ensureRemoteParticipant(userId);
    final participants = _session._snapshot.participants
        .map(
          (item) =>
              item.id == userId ? item.copyWith(isMuted: !available) : item,
        )
        .toList();
    _session._setSnapshot(
      _session._snapshot.copyWith(participants: participants),
    );
    _session._emit(
      MediaTrackMutedChanged(
        participantId: userId,
        muted: !available,
        kind: MediaTrackKind.audio,
      ),
    );
  }

  void _ensureRemoteParticipant(String userId) {
    if (_session._snapshot.participants.any((item) => item.id == userId)) {
      return;
    }
    final participant = MediaParticipant(id: userId, displayName: userId);
    _session._setSnapshot(
      _session._snapshot.copyWith(
        participants: [..._session._snapshot.participants, participant],
      ),
    );
    _session._emit(MediaParticipantJoined(participant));
  }

  MediaParticipant? _participantById(String userId) {
    for (final participant in _session._snapshot.participants) {
      if (participant.id == userId) return participant;
    }
    return null;
  }
}
