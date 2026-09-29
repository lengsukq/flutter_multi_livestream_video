(function installMediaProviderBridge(global) {
  'use strict';

  const sessions = new Map();
  const StageEvents = {
    CONNECTION: 'stageConnectionStateChanged',
    JOINED: 'stageParticipantJoined',
    LEFT: 'stageParticipantLeft',
    STREAMS_ADDED: 'stageParticipantStreamsAdded',
    STREAMS_REMOVED: 'stageParticipantStreamsRemoved',
    ERROR: 'stageError',
  };

  function parsePayload(value) {
    return typeof value === 'string' ? JSON.parse(value) : value;
  }

  function providerBlock(session, key = session.providerId) {
    const payload = session.payload;
    const block = payload[key];
    return block && typeof block === 'object' ? block : payload;
  }

  function emit(session, event) {
    const callback = global.__flutterMediaProviderOnEvent;
    if (typeof callback === 'function') {
      callback(session.id, JSON.stringify(event));
    }
  }

  function emitState(session, state, reason) {
    emit(session, { type: 'state', state, reason });
  }

  function addParticipant(session, id, displayName, isLocal = false) {
    if (!id) return null;
    const current = session.participants.get(String(id)) || {};
    const participant = {
      ...current,
      id: String(id),
      displayName: displayName || current.displayName || String(id),
      isLocal: Boolean(isLocal || current.isLocal),
      isMuted: Boolean(current.isMuted),
      isVideoEnabled: Boolean(current.isVideoEnabled),
    };
    session.participants.set(participant.id, participant);
    return participant;
  }

  function removeParticipant(session, id) {
    const participantId = String(id || '');
    if (!participantId || participantId === session.localParticipantId) return;
    session.participants.delete(participantId);
    for (const [trackId, track] of session.tracks) {
      if (track.participantId === participantId) session.tracks.delete(trackId);
    }
    publishSnapshot(session);
  }

  function addVideoTrack(session, { id, participantId, isLocal = false, isScreenShare = false, native }) {
    if (!id || !participantId) return null;
    const track = {
      id: String(id),
      participantId: String(participantId),
      isLocal: Boolean(isLocal),
      isScreenShare: Boolean(isScreenShare),
      native,
    };
    session.tracks.set(track.id, track);
    const participant = addParticipant(session, participantId, null, isLocal);
    participant.isVideoEnabled = true;
    if (!isScreenShare) participant.videoTrackId = track.id;
    publishSnapshot(session);
    return track;
  }

  function removeVideoTrack(session, id) {
    const track = session.tracks.get(String(id));
    if (!track) return;
    session.tracks.delete(String(id));
    const participant = session.participants.get(track.participantId);
    if (participant && ![...session.tracks.values()].some((item) => item.participantId === track.participantId)) {
      participant.isVideoEnabled = false;
      delete participant.videoTrackId;
    } else if (participant && participant.videoTrackId === track.id) {
      const replacement = [...session.tracks.values()].find(
        (item) => item.participantId === track.participantId && !item.isScreenShare,
      );
      participant.videoTrackId = replacement?.id;
      if (!replacement) participant.isVideoEnabled = false;
    }
    publishSnapshot(session);
  }

  function emitMessage(session, { participantId, displayName, message, topic = 'chat', timestampMs = Date.now(), throttled = false }) {
    emit(session, {
      type: 'message',
      participantId: String(participantId || ''),
      displayName: String(displayName || participantId || ''),
      message: String(message || ''),
      topic: String(topic || 'chat'),
      timestampMs: Number(timestampMs || Date.now()),
      throttled: Boolean(throttled),
    });
  }

  function publishSnapshot(session) {
    const participants = [...session.participants.values()];
    emit(session, {
      type: 'snapshot',
      localParticipantId: session.localParticipantId,
      localMuted: session.localMuted,
      localVideoEnabled: session.localVideoEnabled,
      participants,
      tracks: [...session.tracks.values()].map(({ native, ...track }) => track),
    });
  }

  function reportError(session, error) {
    emit(session, {
      type: 'error',
      message: error && error.message ? error.message : String(error),
    });
  }

  function createSession(providerId, id, payload) {
    const role = String(payload.role || 'participant').toLowerCase();
    const session = {
      id,
      providerId,
      payload,
      role,
      localParticipantId: String(payload.participantId || ''),
      localMuted: true,
      localVideoEnabled: false,
      joined: false,
      participants: new Map(),
      tracks: new Map(),
      attachments: new Map(),
      timers: new Set(),
      screenTrack: null,
    };
    addParticipant(session, session.localParticipantId, payload.displayName, true);
    switch (providerId) {
      case 'agora': return createAgoraSession(session);
      case 'chime': return createChimeSession(session);
      case 'trtc': return createTrtcSession(session);
      case 'artc': return createArtcSession(session);
      case 'ivs': return createIvsSession(session);
      default:
        throw new Error(`No browser SDK driver is registered for ${providerId}.`);
    }
  }

  async function join(session) {
    emitState(session, 'connecting');
    await session.driver.join();
    session.joined = true;
    emitState(session, 'connected');
    publishSnapshot(session);
    startStats(session);
  }

  async function leave(session) {
    if (!session.joined) return;
    stopStats(session);
    await session.driver.leave();
    session.joined = false;
    session.tracks.clear();
    session.participants.clear();
    session.localParticipantId = '';
    emitState(session, 'ended');
    publishSnapshot(session);
  }

  async function dispose(session) {
    try {
      await leave(session);
    } finally {
      stopStats(session);
      if (session.driver.dispose) await session.driver.dispose();
      sessions.delete(session.id);
    }
  }

  function startStats(session) {
    if (!session.driver.getStats || session.timers.size) return;
    const timer = global.setInterval(async () => {
      try {
        const stats = await session.driver.getStats();
        if (stats) emit(session, { type: 'stats', timestampMs: Date.now(), ...stats });
      } catch (_) {
        // Stats are best-effort and must not affect a live call.
      }
    }, 4000);
    session.timers.add(timer);
  }

  function stopStats(session) {
    for (const timer of session.timers) global.clearInterval(timer);
    session.timers.clear();
  }

  async function command(session, name, args) {
    if (!session.joined && name !== 'listDevices') {
      throw new Error(`Cannot run ${name} while the session is not connected.`);
    }
    const result = await session.driver.command(name, args || {});
    publishSnapshot(session);
    return result === undefined ? '' : JSON.stringify(result);
  }

  async function listDevices(session) {
    if (!global.navigator || !navigator.mediaDevices || !navigator.mediaDevices.enumerateDevices) return [];
    const devices = await navigator.mediaDevices.enumerateDevices();
    return devices.map((device) => ({
      id: device.deviceId,
      label: device.label,
      groupId: device.groupId,
      kind: device.kind === 'audioinput' ? 'microphone' : device.kind === 'audiooutput' ? 'audioOutput' : 'camera',
    }));
  }

  function makeVideoElement(container) {
    const existing = container.querySelector('video');
    if (existing) return existing;
    const video = document.createElement('video');
    video.autoplay = true;
    video.playsInline = true;
    video.muted = false;
    video.style.width = '100%';
    video.style.height = '100%';
    video.style.objectFit = 'contain';
    container.replaceChildren(video);
    return video;
  }

  function attachStreamTrack(track, container) {
    const video = makeVideoElement(container);
    video.srcObject = new MediaStream([track]);
    video.play().catch(() => {});
    return video;
  }

  function getTrackAttachment(session, trackId) {
    return session.attachments.get(String(trackId));
  }

  const bridge = {
    async create(providerId, sessionId, serializedPayload) {
      const payload = parsePayload(serializedPayload);
      const session = createSession(providerId, sessionId, payload);
      session.driver = session.driver || {};
      sessions.set(sessionId, session);
    },

    async join(providerId, sessionId) {
      const session = requireSession(providerId, sessionId);
      await join(session);
    },

    async leave(providerId, sessionId) {
      const session = sessions.get(sessionId);
      if (session && session.providerId === providerId) await leave(session);
    },

    async dispose(providerId, sessionId) {
      const session = sessions.get(sessionId);
      if (session && session.providerId === providerId) await dispose(session);
    },

    async command(providerId, sessionId, name, serializedArgs) {
      const session = requireSession(providerId, sessionId);
      const result = await command(session, name, parsePayload(serializedArgs));
      return typeof result === 'string' ? result : JSON.stringify(result || {});
    },

    async attachVideo(providerId, sessionId, trackId, elementId) {
      const session = requireSession(providerId, sessionId);
      const track = session.tracks.get(String(trackId));
      const container = document.getElementById(elementId);
      if (!track || !container) return;
      session.attachments.set(track.id, { elementId, container });
      await session.driver.attachVideo(track, container);
    },

    detachVideo(providerId, sessionId, trackId, elementId) {
      const session = sessions.get(sessionId);
      if (!session || session.providerId !== providerId) return;
      const track = session.tracks.get(String(trackId));
      const attachment = session.attachments.get(String(trackId));
      if (track && attachment && attachment.elementId === elementId && session.driver.detachVideo) {
        session.driver.detachVideo(track, attachment.container);
      }
      session.attachments.delete(String(trackId));
    },
  };

  function requireSession(providerId, sessionId) {
    const session = sessions.get(sessionId);
    if (!session || session.providerId !== providerId) throw new Error(`Unknown ${providerId} session ${sessionId}.`);
    return session;
  }

  function createAgoraSession(session) {
    const info = providerBlock(session, 'agora');
    const live = session.role !== 'participant';
    const client = AgoraRTC.createClient({ mode: live ? 'live' : 'rtc', codec: 'vp8' });
    const localTracks = { audio: null, video: null, screen: null };
    const remoteUsers = new Map();
    const updateRemote = async (user, mediaType) => {
      const participantId = String(user.uid);
      const participant = addParticipant(session, participantId);
      if (mediaType === 'audio' && user.audioTrack) user.audioTrack.play();
      if (mediaType === 'video' && user.videoTrack) {
        const trackId = `agora:video:${participantId}`;
        const remote = { user, track: user.videoTrack };
        remoteUsers.set(trackId, remote);
        addVideoTrack(session, { id: trackId, participantId, native: remote });
        const attachment = getTrackAttachment(session, trackId);
        if (attachment) user.videoTrack.play(attachment.elementId);
      }
      participant.isMuted = !user.audioTrack;
      publishSnapshot(session);
    };
    client.on('user-joined', (user) => {
      addParticipant(session, user.uid);
      publishSnapshot(session);
    });
    client.on('user-left', (user) => removeParticipant(session, user.uid));
    client.on('user-published', async (user, type) => {
      try {
        await client.subscribe(user, type);
        await updateRemote(user, type);
      } catch (error) { reportError(session, error); }
    });
    client.on('user-unpublished', (user, type) => {
      if (type === 'video') removeVideoTrack(session, `agora:video:${user.uid}`);
      if (type === 'audio') {
        const participant = session.participants.get(String(user.uid));
        if (participant) participant.isMuted = true;
        publishSnapshot(session);
      }
    });
    client.on('connection-state-change', (current) => {
      if (current === 'RECONNECTING') emitState(session, 'reconnecting');
      if (current === 'CONNECTED') emitState(session, 'connected');
    });
    session.driver = {
      async join() {
        if (live) await client.setClientRole(session.role === 'viewer' ? 'audience' : 'host');
        await client.join(info.appId, info.channelName, info.token, Number(info.uid));
        if (session.role !== 'viewer') {
          localTracks.audio = await AgoraRTC.createMicrophoneAudioTrack();
          localTracks.video = await AgoraRTC.createCameraVideoTrack();
          localTracks.videoTrackId = `agora:video:${session.localParticipantId}`;
          localTracks.audio.play();
          await client.publish([localTracks.audio, localTracks.video]);
          session.localMuted = false;
          session.localVideoEnabled = true;
          addVideoTrack(session, {
            id: localTracks.videoTrackId,
            participantId: session.localParticipantId,
            isLocal: true,
            native: { track: localTracks.video },
          });
        }
      },
      async command(name, args) {
        if (name === 'setMuted') {
          if (localTracks.audio) await localTracks.audio.setEnabled(!args.muted);
          session.localMuted = Boolean(args.muted);
          return;
        }
        if (name === 'setVideoEnabled') {
          if (localTracks.video) await localTracks.video.setEnabled(Boolean(args.enabled));
          session.localVideoEnabled = Boolean(args.enabled);
          return;
        }
        if (name === 'setScreenShareEnabled') {
          if (args.enabled && !localTracks.screen) {
            if (localTracks.video) await client.unpublish(localTracks.video);
            localTracks.screen = await AgoraRTC.createScreenVideoTrack({ encoderConfig: '1080p_1' }, 'disable');
            await client.publish(localTracks.screen);
            addVideoTrack(session, { id: 'agora:screen:local', participantId: session.localParticipantId, isLocal: true, isScreenShare: true, native: { track: localTracks.screen } });
            localTracks.screen.on('track-ended', () => this.command('setScreenShareEnabled', { enabled: false }).catch(() => {}));
          } else if (!args.enabled && localTracks.screen) {
            await client.unpublish(localTracks.screen);
            localTracks.screen.close();
            localTracks.screen = null;
            removeVideoTrack(session, 'agora:screen:local');
            if (localTracks.video) await client.publish(localTracks.video);
          }
          return;
        }
        if (name === 'selectDevice' || name === 'selectAudioOutput') {
          const selected = args.device || args;
          if (selected.kind === 'microphone' && localTracks.audio) await localTracks.audio.setDevice(selected.id);
          if (selected.kind === 'camera' && localTracks.video) await localTracks.video.setDevice(selected.id);
          if (selected.kind === 'audioOutput') {
            for (const user of client.remoteUsers || []) if (user.audioTrack?.setPlaybackDevice) await user.audioTrack.setPlaybackDevice(selected.id);
          }
          return;
        }
        if (name === 'switchCamera' && localTracks.video) {
          const cameras = await AgoraRTC.getCameras();
          const current = localTracks.video.getTrackLabel?.();
          const index = cameras.findIndex((device) => device.label === current);
          const next = cameras[(index + 1) % cameras.length];
          if (next) await localTracks.video.setDevice(next.deviceId);
          return;
        }
        if (name === 'listDevices') return listDevices(session);
        throw new Error(`Agora does not support ${name}.`);
      },
      async attachVideo(track, container) {
        const native = track.native?.track || remoteUsers.get(track.id)?.track;
        if (native?.play) native.play(container.id);
      },
      detachVideo(track, container) {
        const native = track.native?.track || remoteUsers.get(track.id)?.track;
        if (native?.stop) native.stop();
        container.replaceChildren();
      },
      async leave() {
        for (const track of [localTracks.screen, localTracks.video, localTracks.audio]) {
          if (track?.close) track.close();
        }
        await client.leave();
      },
      async dispose() { client.removeAllListeners?.(); },
      async getStats() {
        const stats = client.getRTCStats?.();
        return stats ? { rttMs: Math.round(stats.RTT || 0), uploadKbps: Math.round((stats.SendBitrate || 0) / 1000), downloadKbps: Math.round((stats.RecvBitrate || 0) / 1000) } : null;
      },
    };
    return session;
  }

  function createTrtcSession(session) {
    const info = providerBlock(session, 'trtc');
    const sdk = global.TRTC;
    const trtc = sdk.create({ assetsPath: new URL('assets/packages/flutter_realtime_sdk/assets/provider_web_runtime/vendors/trtc-assets/', document.baseURI).toString() });
    const localVideoId = `trtc:video:${session.localParticipantId}`;
    const remoteTracks = new Map();
    const refreshLocalTrack = () => {
      const track = trtc.getVideoTrack?.();
      if (track) addVideoTrack(session, { id: localVideoId, participantId: session.localParticipantId, isLocal: true, native: track });
    };
    const events = sdk.EVENT || {};
    const attachRemote = (event) => {
      const userId = String(event.userId || '');
      if (!userId) return;
      addParticipant(session, userId);
      const streamType = event.streamType || sdk.TYPE?.STREAM_TYPE_MAIN || 'main';
      const trackId = `trtc:video:${userId}:${streamType}`;
      remoteTracks.set(trackId, { userId, streamType });
      addVideoTrack(session, { id: trackId, participantId: userId, isScreenShare: streamType === (sdk.TYPE?.STREAM_TYPE_SUB || 'sub'), native: { userId, streamType } });
    };
    trtc.on(events.REMOTE_USER_ENTER || 'remote-user-enter', (event) => { addParticipant(session, event.userId); publishSnapshot(session); });
    trtc.on(events.REMOTE_USER_EXIT || 'remote-user-exit', (event) => removeParticipant(session, event.userId));
    trtc.on(events.REMOTE_VIDEO_AVAILABLE || 'remote-video-available', attachRemote);
    trtc.on(events.REMOTE_VIDEO_UNAVAILABLE || 'remote-video-unavailable', (event) => removeVideoTrack(session, `trtc:video:${event.userId}:${event.streamType || sdk.TYPE?.STREAM_TYPE_MAIN || 'main'}`));
    trtc.on(events.CONNECTION_STATE_CHANGED || 'connection-state-changed', (event) => {
      const value = String(event.state || event.currentState || '').toLowerCase();
      if (value.includes('reconnect')) emitState(session, 'reconnecting');
      if (value.includes('connected')) emitState(session, 'connected');
    });
    trtc.on(events.ERROR || 'error', (error) => reportError(session, error));
    trtc.on(events.SCREEN_SHARE_STOPPED || 'screen-share-stopped', () => {
      session.screenTrack = null;
      removeVideoTrack(session, `trtc:screen:${session.localParticipantId}`);
    });
    session.driver = {
      async join() {
        const live = session.role !== 'participant';
        await trtc.enterRoom({
          sdkAppId: Number(info.sdkAppId),
          strRoomId: info.strRoomId,
          userId: info.userId,
          userSig: info.userSig,
          privateMapKey: info.privateMapKey,
          scene: live ? sdk.TYPE.SCENE_LIVE : sdk.TYPE.SCENE_RTC,
          ...(live ? { role: session.role === 'viewer' ? sdk.TYPE.ROLE_AUDIENCE : sdk.TYPE.ROLE_ANCHOR } : {}),
          autoReceiveAudio: true,
          autoReceiveVideo: true,
        });
        if (session.role !== 'viewer') {
          await trtc.startLocalAudio();
          await trtc.startLocalVideo({ publish: true });
          session.localMuted = false;
          session.localVideoEnabled = true;
          refreshLocalTrack();
        }
      },
      async command(name, args) {
        if (name === 'setMuted') {
          await trtc.updateLocalAudio({ mute: Boolean(args.muted) });
          session.localMuted = Boolean(args.muted);
          return;
        }
        if (name === 'setVideoEnabled') {
          await trtc.updateLocalVideo({ mute: !args.enabled, publish: Boolean(args.enabled) });
          session.localVideoEnabled = Boolean(args.enabled);
          if (!args.enabled) removeVideoTrack(session, localVideoId); else refreshLocalTrack();
          return;
        }
        if (name === 'setScreenShareEnabled') {
          if (args.enabled) {
            await trtc.startLocalScreen({ publish: true });
            session.screenTrack = trtc.getVideoTrack({ streamType: sdk.TYPE.STREAM_TYPE_SUB });
            if (session.screenTrack) addVideoTrack(session, { id: `trtc:screen:${session.localParticipantId}`, participantId: session.localParticipantId, isLocal: true, isScreenShare: true, native: session.screenTrack });
          } else {
            await trtc.stopLocalScreen();
            session.screenTrack = null;
            removeVideoTrack(session, `trtc:screen:${session.localParticipantId}`);
          }
          return;
        }
        if (name === 'switchCamera') {
          const cameras = await sdk.getCameras();
          const current = cameras.find((device) => device.deviceId === session.cameraId);
          const index = current ? cameras.indexOf(current) : -1;
          const next = cameras[(index + 1) % cameras.length];
          if (next) { session.cameraId = next.deviceId; await trtc.updateLocalVideo({ option: { cameraId: next.deviceId } }); }
          return;
        }
        if (name === 'selectDevice') {
          const selected = args.device || args;
          if (selected.kind === 'microphone') await trtc.updateLocalAudio({ option: { microphoneId: selected.id } });
          if (selected.kind === 'camera') { session.cameraId = selected.id; await trtc.updateLocalVideo({ option: { cameraId: selected.id } }); }
          return;
        }
        if (name === 'listDevices') return listDevices(session);
        throw new Error(`TRTC does not support ${name}.`);
      },
      async attachVideo(track, container) {
        const native = track.native;
        if (native?.userId) {
          await trtc.startRemoteVideo({ userId: native.userId, streamType: native.streamType, view: container.id });
        } else {
          const mediaTrack = native?.mediaStreamTrack || native;
          if (mediaTrack && mediaTrack.kind === 'video') attachStreamTrack(mediaTrack, container);
        }
      },
      async detachVideo(track) {
        const native = track.native;
        if (native?.userId) await trtc.stopRemoteVideo({ userId: native.userId, streamType: native.streamType });
      },
      async leave() { await trtc.exitRoom(); },
      async dispose() { trtc.destroy?.(); },
      async getStats() {
        const statistics = session.lastTrtcStatistics;
        return statistics ? { uploadKbps: statistics.localVideo?.sendBitrate, downloadKbps: statistics.remoteVideo?.receiveBitrate, rttMs: statistics.rtt } : null;
      },
    };
    trtc.on(events.STATISTICS || 'statistics', (value) => { session.lastTrtcStatistics = value; });
    return session;
  }

  function createArtcSession(session) {
    const info = providerBlock(session, 'artc');
    const namespace = global.AliRtcEngine;
    const AliRtcEngine = namespace?.AliRtcEngine || namespace?.default || namespace;
    const profile = AliRtcEngine.AliRtcSdkChannelProfile;
    const roles = AliRtcEngine.AliRtcSdkClientRole;
    const engine = AliRtcEngine.createInstance ? AliRtcEngine.createInstance() : AliRtcEngine.getInstance();
    const cameraTrack = AliRtcEngine.AliRtcVideoTrack.AliRtcVideoTrackCamera;
    const screenTrack = AliRtcEngine.AliRtcVideoTrack.AliRtcVideoTrackScreen;
    const remoteVideo = new Map();
    engine.on('connectionStatusChange', (status) => {
      if (status === AliRtcEngine.AliRtcConnectionStatus.AliRtcConnectionStatusReconnecting) emitState(session, 'reconnecting');
      if (status === AliRtcEngine.AliRtcConnectionStatus.AliRtcConnectionStatusConnected) emitState(session, 'connected');
    });
    engine.on('remoteUserOnLineNotify', (uid) => { addParticipant(session, uid); publishSnapshot(session); });
    engine.on('remoteUserOffLineNotify', (uid) => removeParticipant(session, uid));
    engine.on('remoteTrackAvailableNotify', (uid, audioTracks, videoTracks) => {
      const id = `artc:video:${uid}`;
      if (videoTracks) {
        remoteVideo.set(id, { uid, track: cameraTrack });
        addVideoTrack(session, { id, participantId: uid, native: { uid, track: cameraTrack } });
      } else removeVideoTrack(session, id);
    });
    engine.on('error', (error) => reportError(session, error));
    session.driver = {
      async join() {
        if (session.role === 'participant') engine.setChannelProfile(profile.AliRtcSdkCommunication);
        else {
          engine.setChannelProfile(profile.AliRtcInteractiveLive);
          await engine.setClientRole(session.role === 'viewer' ? roles.AliRtcSdkLive : roles.AliRtcSdkInteractive);
        }
        await engine.joinChannel(info.authInfo, session.payload.displayName || info.userId);
        if (session.role !== 'viewer') {
          await engine.startPreview();
          session.localMuted = false;
          session.localVideoEnabled = true;
          addVideoTrack(session, { id: `artc:video:${session.localParticipantId}`, participantId: session.localParticipantId, isLocal: true, native: { uid: session.localParticipantId, track: cameraTrack } });
        }
      },
      async command(name, args) {
        if (name === 'setMuted') { engine.muteLocalMic(Boolean(args.muted)); session.localMuted = Boolean(args.muted); return; }
        if (name === 'setVideoEnabled') { await engine.enableLocalVideo(Boolean(args.enabled)); session.localVideoEnabled = Boolean(args.enabled); if (!args.enabled) removeVideoTrack(session, `artc:video:${session.localParticipantId}`); else addVideoTrack(session, { id: `artc:video:${session.localParticipantId}`, participantId: session.localParticipantId, isLocal: true, native: { uid: session.localParticipantId, track: cameraTrack } }); return; }
        if (name === 'setScreenShareEnabled') {
          if (args.enabled) { await engine.startPreviewScreen(); await engine.publishLocalScreenShareStream(true); addVideoTrack(session, { id: `artc:screen:${session.localParticipantId}`, participantId: session.localParticipantId, isLocal: true, isScreenShare: true, native: { uid: session.localParticipantId, track: screenTrack } }); }
          else { await engine.publishLocalScreenShareStream(false); await engine.stopPreviewScreen(); removeVideoTrack(session, `artc:screen:${session.localParticipantId}`); }
          return;
        }
        if (name === 'switchCamera') {
          const cameras = await AliRtcEngine.getCameraList();
          const current = engine.getCurrentCameraDeviceId?.();
          const index = cameras.findIndex((device) => device.deviceId === current);
          const next = cameras[(index + 1) % cameras.length];
          if (next) await engine.switchCamera(next.deviceId);
          return;
        }
        if (name === 'selectDevice') {
          const selected = args.device || args;
          if (selected.kind === 'camera') { engine.setCameraCapturerConfiguration({ deviceId: selected.id }); await engine.switchCamera(selected.id); }
          if (selected.kind === 'microphone') engine.setMicrophoneDeviceId?.(selected.id);
          return;
        }
        if (name === 'listDevices') return listDevices(session);
        throw new Error(`ARTC does not support ${name}.`);
      },
      async attachVideo(track, container) {
        if (track.isLocal) await engine.setLocalViewConfig(container.id, track.isScreenShare ? screenTrack : cameraTrack);
        else engine.setRemoteViewConfig(container.id, track.participantId, track.isScreenShare ? screenTrack : cameraTrack);
      },
      detachVideo(track) {
        if (track.isLocal) engine.setLocalViewConfig(null, track.isScreenShare ? screenTrack : cameraTrack);
        else engine.setRemoteViewConfig(null, track.participantId, track.isScreenShare ? screenTrack : cameraTrack);
      },
      async leave() { await engine.leaveChannel(); },
      async dispose() { await engine.destroy(); },
      async getStats() { return session.lastArtcStats || null; },
    };
    engine.on('networkQuality', (stats) => {
      session.lastArtcStats = {
        rttMs: stats?.subscribe?.rtt,
        downlinkPacketLossPercent: stats?.subscribe?.loss,
      };
      emit(session, { type: 'stats', timestampMs: Date.now(), ...session.lastArtcStats });
    });
    return session;
  }

  function createIvsSession(session) {
    const info = providerBlock(session, 'ivs');
    const sdk = global.IVSBroadcastClient;
    if (!sdk?.Stage || !sdk?.LocalStageStream) {
      throw new Error('Amazon IVS Web Broadcast SDK is unavailable in this browser build.');
    }
    const canPublish = session.role !== 'viewer' && info.capabilities?.includes('PUBLISH');
    const localStreams = [];
    const remoteStreams = new Map();
    const stage = new sdk.Stage(info.token, {
      stageStreamsToPublish: () => localStreams,
      shouldPublishParticipant: () => Boolean(canPublish),
      shouldSubscribeToParticipant: (participant) => participant.capabilities?.has('subscribe') ? sdk.SubscribeType.AUDIO_VIDEO : sdk.SubscribeType.NONE,
    });
    stage.on(StageEvents.CONNECTION, (state) => {
      if (state === sdk.StageConnectionState.CONNECTED) emitState(session, 'connected');
      else if (state === sdk.StageConnectionState.CONNECTING) emitState(session, 'connecting');
      else if (state === sdk.StageConnectionState.DISCONNECTED) emitState(session, 'disconnected');
    });
    stage.on(StageEvents.JOINED, (participant) => { addParticipant(session, participant.userId || participant.id, participant.userInfo?.displayName, participant.isLocal); publishSnapshot(session); });
    stage.on(StageEvents.LEFT, (participant) => removeParticipant(session, participant.userId || participant.id));
    stage.on(StageEvents.STREAMS_ADDED, (participant, streams) => {
      const participantId = String(participant.userId || participant.id);
      addParticipant(session, participantId, participant.userInfo?.displayName, participant.isLocal);
      for (const stream of streams) {
        if (stream.streamType !== sdk.StreamType.VIDEO) continue;
        remoteStreams.set(stream.id, stream);
        addVideoTrack(session, { id: `ivs:${participantId}:${stream.id}`, participantId, isLocal: participant.isLocal, native: stream });
      }
      for (const stream of streams) {
        if (stream.streamType === sdk.StreamType.AUDIO && !participant.isLocal) {
          const audio = document.createElement('audio');
          audio.autoplay = true;
          audio.srcObject = new MediaStream([stream.mediaStreamTrack]);
          document.body.append(audio);
          stream.__audioElement = audio;
          audio.play().catch(() => {});
        }
      }
    });
    stage.on(StageEvents.STREAMS_REMOVED, (_participant, streams) => {
      for (const stream of streams) {
        removeVideoTrack(session, [...session.tracks.values()].find((track) => track.native === stream)?.id);
        stream.__audioElement?.remove();
        remoteStreams.delete(stream.id);
      }
    });
    stage.on(StageEvents.ERROR, (error) => reportError(session, error));
    session.localStreams = localStreams;
    session.stage = stage;
    session.driver = {
      async join() {
        if (canPublish) {
          if (!navigator.mediaDevices?.getUserMedia) {
            throw new Error('This browser cannot access camera or microphone media devices.');
          }
          const media = await navigator.mediaDevices.getUserMedia({ audio: true, video: true });
          for (const track of media.getTracks()) {
            const localStream = new sdk.LocalStageStream(track);
            localStreams.push(localStream);
            if (track.kind === 'video') {
              session.localVideoStream = localStream;
              session.localVideoEnabled = true;
              addVideoTrack(session, { id: `ivs:local:${track.id}`, participantId: session.localParticipantId, isLocal: true, native: localStream });
            } else session.localAudioStream = localStream;
          }
          session.localMuted = false;
        }
        await stage.join();
      },
      async command(name, args) {
        if (name === 'setMuted') {
          session.localMuted = Boolean(args.muted);
          if (session.localAudioStream) session.localAudioStream.setMuted(session.localMuted);
          return;
        }
        if (name === 'setVideoEnabled') {
          session.localVideoEnabled = Boolean(args.enabled);
          if (session.localVideoStream) session.localVideoStream.setMuted(!session.localVideoEnabled);
          return;
        }
        if (name === 'setScreenShareEnabled') {
          if (args.enabled) {
            const media = await navigator.mediaDevices.getDisplayMedia({ video: true });
            const track = media.getVideoTracks()[0];
            const localStream = new sdk.LocalStageStream(track);
            localStreams.push(localStream);
            session.screenTrack = localStream;
            stage.refreshStrategy();
            addVideoTrack(session, { id: `ivs:screen:${track.id}`, participantId: session.localParticipantId, isLocal: true, isScreenShare: true, native: localStream });
            track.addEventListener('ended', () => this.command('setScreenShareEnabled', { enabled: false }).catch(() => {}), { once: true });
          } else if (session.screenTrack) {
            const track = session.screenTrack.mediaStreamTrack;
            track.stop();
            localStreams.splice(localStreams.indexOf(session.screenTrack), 1);
            removeVideoTrack(session, [...session.tracks.values()].find((item) => item.native === session.screenTrack)?.id);
            session.screenTrack = null;
            stage.refreshStrategy();
          }
          return;
        }
        if (name === 'switchCamera') return;
        if (name === 'selectDevice') {
          const selected = args.device || args;
          if (selected.kind !== 'camera' && selected.kind !== 'microphone') return;
          const media = await navigator.mediaDevices.getUserMedia(selected.kind === 'camera' ? { video: { deviceId: { exact: selected.id } } } : { audio: { deviceId: { exact: selected.id } } });
          const track = media.getTracks()[0];
          const old = selected.kind === 'camera' ? session.localVideoStream : session.localAudioStream;
          if (old) {
            old.mediaStreamTrack.stop();
            const index = localStreams.indexOf(old);
            if (index >= 0) localStreams.splice(index, 1);
          }
          const replacement = new sdk.LocalStageStream(track);
          localStreams.push(replacement);
          if (selected.kind === 'camera') {
            session.localVideoStream = replacement;
            if (old) removeVideoTrack(session, [...session.tracks.values()].find((item) => item.native === old)?.id);
            addVideoTrack(session, { id: `ivs:local:${track.id}`, participantId: session.localParticipantId, isLocal: true, native: replacement });
          } else session.localAudioStream = replacement;
          stage.refreshStrategy();
          return;
        }
        if (name === 'listDevices') return listDevices(session);
        throw new Error(`IVS Real-Time does not support ${name}.`);
      },
      async attachVideo(track, container) { attachStreamTrack(track.native.mediaStreamTrack, container); },
      detachVideo(_track, container) { container.replaceChildren(); },
      async leave() {
        stage.leave();
        for (const stream of [...localStreams]) stream.mediaStreamTrack.stop();
        localStreams.length = 0;
      },
      async dispose() { stage.removeAllListeners?.(); },
      async getStats() {
        const stats = await Promise.all(localStreams.map((stream) => stream.requestQualityStats?.()));
        const values = stats.flat().filter(Boolean);
        if (!values.length) return null;
        const loss = values.map((item) => item.packetsLost && item.packetsSent ? (item.packetsLost / item.packetsSent) * 100 : 0).reduce((a, b) => a + b, 0) / values.length;
        return { uplinkPacketLossPercent: loss };
      },
    };
    return session;
  }

  function createChimeSession(session) {
    const info = session.payload;
    const meeting = info.meeting || info.Meeting;
    const attendee = info.attendee || info.Attendee;
    if (!meeting || !attendee) throw new Error('Chime join data must include meeting and attendee objects.');
    const logger = new ChimeSDK.ConsoleLogger(`media-web-${session.id}`, ChimeSDK.LogLevel.WARN);
    const deviceController = new ChimeSDK.DefaultDeviceController(logger);
    const configuration = new ChimeSDK.MeetingSessionConfiguration(meeting, attendee);
    const meetingSession = new ChimeSDK.DefaultMeetingSession(configuration, logger, deviceController);
    const audioVideo = meetingSession.audioVideo;
    const tiles = new Map();
    const tileIdFor = (tile) => `chime:tile:${tile.tileId}`;
    const observer = {
      audioVideoDidStart() { emitState(session, 'connected'); },
      audioVideoDidStop(status) {
        if (session.joined && status?.statusCode !== ChimeSDK.MeetingSessionStatusCode.Left) {
          reportError(session, status);
        }
      },
      videoTileDidUpdate(tile) {
        if (!tile || !tile.tileId || !tile.boundAttendeeId) return;
        tiles.set(tile.tileId, tile);
        addParticipant(session, tile.boundAttendeeId, null, Boolean(tile.localTile));
        addVideoTrack(session, { id: tileIdFor(tile), participantId: tile.boundAttendeeId, isLocal: Boolean(tile.localTile), isScreenShare: Boolean(tile.isContent), native: tile });
      },
      videoTileWasRemoved(tileId) {
        const tile = tiles.get(tileId);
        if (tile) removeVideoTrack(session, tileIdFor(tile));
        tiles.delete(tileId);
      },
      connectionDidSuggestStop() { emitState(session, 'reconnecting', 'connection-did-suggest-stop'); },
    };
    audioVideo.addObserver(observer);
    const presenceObserver = (attendeeId, present, externalUserId) => {
      if (!attendeeId || attendeeId.includes('#')) return;
      if (present) {
        addParticipant(
          session,
          attendeeId,
          externalUserId || attendeeId,
          attendeeId === session.localParticipantId,
        );
        publishSnapshot(session);
      } else {
        removeParticipant(session, attendeeId);
      }
    };
    audioVideo.realtimeSubscribeToAttendeeIdPresence(presenceObserver);
    const dataTopic = 'chat';
    const dataObserver = (dataMessage) => {
      let message = '';
      try {
        if (typeof dataMessage.text === 'function') message = dataMessage.text();
        else if (dataMessage.data) message = new TextDecoder().decode(dataMessage.data);
      } catch (_) {
        message = '';
      }
      emitMessage(session, {
        participantId: dataMessage.senderAttendeeId,
        displayName: dataMessage.senderExternalUserId,
        message,
        topic: dataMessage.topic || dataTopic,
        timestampMs: dataMessage.timestampMs,
        throttled: dataMessage.throttled,
      });
    };
    audioVideo.realtimeSubscribeToReceiveDataMessage(dataTopic, dataObserver);
    session.meetingSession = meetingSession;
    session.driver = {
      async join() {
        const [microphones, cameras] = await Promise.all([
          audioVideo.listAudioInputDevices(),
          audioVideo.listVideoInputDevices(),
        ]);
        if (microphones.length) {
          await audioVideo.startAudioInput(microphones[0].deviceId);
        }
        if (cameras.length) {
          await audioVideo.startVideoInput(cameras[0].deviceId);
        }
        audioVideo.start();
        if (cameras.length) audioVideo.startLocalVideoTile();
        session.localMuted = microphones.length === 0;
        session.localVideoEnabled = cameras.length > 0;
        for (const tile of audioVideo.getAllVideoTiles()) observer.videoTileDidUpdate(tile.state());
      },
      async command(name, args) {
        if (name === 'setMuted') {
          if (args.muted) audioVideo.realtimeMuteLocalAudio(); else await audioVideo.realtimeUnmuteLocalAudio();
          session.localMuted = Boolean(args.muted);
          return;
        }
        if (name === 'setVideoEnabled') {
          if (args.enabled) await audioVideo.startLocalVideoTile(); else audioVideo.stopLocalVideoTile();
          session.localVideoEnabled = Boolean(args.enabled);
          return;
        }
        if (name === 'setScreenShareEnabled') {
          if (args.enabled) await audioVideo.startContentShareFromScreenCapture(); else audioVideo.stopContentShare();
          return;
        }
        if (name === 'selectDevice' || name === 'selectAudioOutput') {
          const selected = args.device || args;
          if (selected.kind === 'microphone') await audioVideo.startAudioInput(selected.id);
          if (selected.kind === 'camera') await audioVideo.startVideoInput(selected.id);
          if (selected.kind === 'audioOutput') await audioVideo.chooseAudioOutput(selected.id);
          return;
        }
        if (name === 'listDevices') {
          const [microphones, cameras, outputs] = await Promise.all([audioVideo.listAudioInputDevices(), audioVideo.listVideoInputDevices(), audioVideo.listAudioOutputDevices()]);
          return [...microphones.map((item) => ({ id: item.deviceId, label: item.label, groupId: item.groupId, kind: 'microphone' })), ...cameras.map((item) => ({ id: item.deviceId, label: item.label, groupId: item.groupId, kind: 'camera' })), ...outputs.map((item) => ({ id: item.deviceId, label: item.label, groupId: item.groupId, kind: 'audioOutput' }))];
        }
        if (name === 'sendMessage') {
          const topic = String(args.topic || dataTopic);
          const message = String(args.message || '');
          const lifetimeMs = Number(args.lifetimeMs || 300000);
          if (!message || !topic || lifetimeMs <= 0) throw new Error('Chime data message requires message, topic, and positive lifetimeMs.');
          audioVideo.realtimeSendDataMessage(topic, message, lifetimeMs);
          return;
        }
        throw new Error(`Chime does not support ${name}.`);
      },
      attachVideo(track, container) {
        const tile = track.native;
        const video = makeVideoElement(container);
        audioVideo.bindVideoElement(tile.tileId, video);
      },
      detachVideo(track) { audioVideo.unbindVideoElement(track.native.tileId); },
      async leave() { audioVideo.stop(); await deviceController.destroy?.(); },
      async dispose() {
        audioVideo.removeObserver(observer);
        audioVideo.realtimeUnsubscribeToAttendeeIdPresence(presenceObserver);
        audioVideo.realtimeUnsubscribeFromReceiveDataMessage(dataTopic);
      },
      async getStats() { return null; },
    };
    return session;
  }

  global.MediaProviderBridge = bridge;
})(globalThis);
