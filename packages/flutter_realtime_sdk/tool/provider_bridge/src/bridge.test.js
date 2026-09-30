import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import vm from 'node:vm';

async function createChimeHarness() {
  const calls = [];
  const events = [];
  let observer;
  let presenceObserver;
  let dataObserver;

  const audioVideo = {
    addObserver(value) {
      observer = value;
      calls.push('addObserver');
    },
    removeObserver(value) {
      assert.equal(value, observer);
      calls.push('removeObserver');
    },
    realtimeSubscribeToAttendeeIdPresence(value) {
      presenceObserver = value;
      calls.push('subscribePresence');
    },
    realtimeUnsubscribeToAttendeeIdPresence(value) {
      assert.equal(value, presenceObserver);
      calls.push('unsubscribePresence');
    },
    realtimeSubscribeToReceiveDataMessage(topic, value) {
      assert.equal(topic, 'chat');
      dataObserver = value;
      calls.push('subscribeData');
    },
    realtimeUnsubscribeFromReceiveDataMessage(topic) {
      assert.equal(topic, 'chat');
      calls.push('unsubscribeData');
    },
    async listAudioInputDevices() {
      calls.push('listAudioInputs');
      return [{ deviceId: 'mic-1', label: 'Mic', groupId: 'g1' }];
    },
    async listVideoInputDevices() {
      calls.push('listVideoInputs');
      return [{ deviceId: 'cam-1', label: 'Camera', groupId: 'g2' }];
    },
    async listAudioOutputDevices() {
      calls.push('listAudioOutputs');
      return [{ deviceId: 'speaker-1', label: 'Speaker', groupId: 'g3' }];
    },
    async startAudioInput(deviceId) {
      calls.push(`startAudioInput:${deviceId}`);
    },
    async startVideoInput(deviceId) {
      calls.push(`startVideoInput:${deviceId}`);
    },
    start() {
      calls.push('start');
      observer?.audioVideoDidStart?.();
    },
    startLocalVideoTile() {
      calls.push('startLocalVideoTile');
    },
    stopLocalVideoTile() {
      calls.push('stopLocalVideoTile');
    },
    getAllVideoTiles() {
      return [];
    },
    realtimeMuteLocalAudio() {
      calls.push('mute');
    },
    async realtimeUnmuteLocalAudio() {
      calls.push('unmute');
    },
    async chooseAudioOutput(deviceId) {
      calls.push(`chooseAudioOutput:${deviceId}`);
    },
    realtimeSendDataMessage(topic, message, lifetimeMs) {
      calls.push(`message:${topic}:${message}:${lifetimeMs}`);
    },
    stop() {
      calls.push('stop');
    },
    bindVideoElement() {},
    unbindVideoElement() {},
  };

  class DefaultDeviceController {
    async destroy() {
      calls.push('destroyDeviceController');
    }
  }

  class DefaultMeetingSession {
    constructor() {
      this.audioVideo = audioVideo;
    }
  }

  const context = vm.createContext({
    console,
    TextDecoder,
    setInterval: () => 1,
    clearInterval: () => {},
    __flutterMediaProviderOnEvent: (sessionId, serializedEvent) => {
      events.push({ sessionId, event: JSON.parse(serializedEvent) });
    },
    ChimeSDK: {
      ConsoleLogger: class {},
      LogLevel: { WARN: 'warn' },
      DefaultDeviceController,
      MeetingSessionConfiguration: class {},
      DefaultMeetingSession,
      MeetingSessionStatusCode: { Left: 'Left' },
    },
  });
  const source = await readFile(new URL('./bridge.js', import.meta.url), 'utf8');
  const effectsSource = await readFile(new URL('../../../../flutter_realtime_video_effects/web/video-effects-bridge.js', import.meta.url), 'utf8');
  vm.runInContext(effectsSource, context, {filename: 'video-effects-bridge.js'});
  vm.runInContext(source, context, { filename: 'bridge.js' });
  return {
    bridge: context.MediaProviderBridge,
    calls,
    events,
    getDataObserver: () => dataObserver,
  };
}

const chimePayload = {
  participantId: 'attendee-1',
  displayName: 'Ada',
  role: 'participant',
  meeting: {
    MeetingId: 'meeting-1',
    ExternalMeetingId: 'external-1',
    MediaRegion: 'us-east-1',
    MediaPlacement: {
      AudioHostUrl: 'https://audio.example',
      AudioFallbackUrl: 'https://fallback.example',
      SignalingUrl: 'wss://signal.example',
      TurnControlUrl: 'https://turn.example',
    },
  },
  attendee: {
    AttendeeId: 'attendee-1',
    ExternalUserId: 'Ada',
    JoinToken: 'token',
  },
};

test('Chime bridge uses the current 3.32 media input APIs', async () => {
  const { bridge, calls } = await createChimeHarness();

  await bridge.create('chime', 'meeting-1', JSON.stringify(chimePayload));
  await bridge.join('chime', 'meeting-1');

  assert.ok(calls.includes('startAudioInput:mic-1'));
  assert.ok(!calls.includes('startVideoInput:cam-1'));
  assert.ok(calls.includes('start'));
  assert.ok(!calls.includes('startLocalVideoTile'));

  await bridge.command(
    'chime',
    'meeting-1',
    'selectDevice',
    JSON.stringify({
      device: { id: 'mic-2', label: 'Mic 2', kind: 'microphone' },
    }),
  );
  await bridge.command(
    'chime',
    'meeting-1',
    'selectDevice',
    JSON.stringify({
      device: { id: 'cam-2', label: 'Camera 2', kind: 'camera' },
    }),
  );
  await bridge.command(
    'chime',
    'meeting-1',
    'selectAudioOutput',
    JSON.stringify({ id: 'speaker-2', label: 'Speaker 2', kind: 'audioOutput' }),
  );

  assert.ok(calls.includes('startAudioInput:mic-2'));
  assert.ok(calls.includes('startVideoInput:cam-2'));
  assert.ok(calls.includes('chooseAudioOutput:speaker-2'));

  await bridge.dispose('chime', 'meeting-1');
  assert.ok(calls.includes('unsubscribePresence'));
  assert.ok(calls.includes('unsubscribeData'));
  assert.ok(calls.includes('destroyDeviceController'));
});

test('Chime bridge sends and receives normalized data messages', async () => {
  const { bridge, calls, events, getDataObserver } =
    await createChimeHarness();
  await bridge.create('chime', 'meeting-2', JSON.stringify(chimePayload));
  await bridge.join('chime', 'meeting-2');
  await bridge.command(
    'chime',
    'meeting-2',
    'sendMessage',
    JSON.stringify({ topic: 'chat', message: 'hello', lifetimeMs: 300000 }),
  );
  assert.ok(calls.includes('message:chat:hello:300000'));

  const dataObserver = getDataObserver();
  assert.equal(typeof dataObserver, 'function');
  dataObserver({
    senderAttendeeId: 'attendee-2',
    senderExternalUserId: 'Grace',
    topic: 'chat',
    timestampMs: 1234,
    throttled: false,
    text: () => 'incoming',
  });
  const messageEvent = events.find(({ event }) => event.type === 'message');
  assert.deepEqual(messageEvent, {
    sessionId: 'meeting-2',
    event: {
      type: 'message',
      participantId: 'attendee-2',
      displayName: 'Grace',
      message: 'incoming',
      topic: 'chat',
      timestampMs: 1234,
      throttled: false,
    },
  });

  await bridge.dispose('chime', 'meeting-2');
});

async function createIvsHarness() {
  const calls = [];
  const events = [];
  let stage;
  let mediaSequence = 0;

  function track(kind, id) {
    return {
      kind,
      id,
      stop: () => calls.push(`stop:${id}`),
      addEventListener: () => {},
    };
  }

  class LocalStageStream {
    constructor(mediaStreamTrack) {
      this.mediaStreamTrack = mediaStreamTrack;
      this.id = mediaStreamTrack.id;
      this.streamType = mediaStreamTrack.kind === 'video' ? 'video' : 'audio';
    }

    setMuted(muted) {
      calls.push(`mute:${this.mediaStreamTrack.id}:${muted}`);
    }

    async requestQualityStats() {
      return [{ packetsLost: 1, packetsSent: 100 }];
    }
  }

  class Stage {
    constructor(token, strategy) {
      this.token = token;
      this.strategy = strategy;
      this.handlers = new Map();
      stage = this;
    }

    on(name, handler) {
      this.handlers.set(name, handler);
    }

    async join() {
      calls.push('stage.join');
    }

    leave() {
      calls.push('stage.leave');
    }

    refreshStrategy() {
      calls.push('stage.refreshStrategy');
    }

    removeAllListeners() {
      calls.push('stage.removeAllListeners');
    }
  }

  const mediaDevices = {
    async getUserMedia(constraints) {
      mediaSequence += 1;
      calls.push(`getUserMedia:${JSON.stringify(constraints)}`);
      if (constraints.audio === true && constraints.video === true) {
        const tracks = [
          track('audio', `audio-${mediaSequence}`),
          track('video', `video-${mediaSequence}`),
        ];
        return {
          getTracks: () => tracks,
          getVideoTracks: () => tracks.filter((item) => item.kind === 'video'),
        };
      }
      const kind = constraints.video ? 'video' : 'audio';
      const selected = track(kind, `${kind}-${mediaSequence}`);
      return {
        getTracks: () => [selected],
        getVideoTracks: () => kind === 'video' ? [selected] : [],
      };
    },
    async enumerateDevices() {
      return [];
    },
  };

  const context = vm.createContext({
    console,
    setInterval: () => 1,
    clearInterval: () => {},
    navigator: { mediaDevices },
    document: {
      createElement: () => ({
        remove: () => {},
        play: () => Promise.resolve(),
      }),
      body: { append: () => {} },
    },
    MediaStream: class {
      constructor(tracks) {
        this.tracks = tracks;
      }
    },
    __flutterMediaProviderOnEvent: (sessionId, serializedEvent) => {
      events.push({ sessionId, event: JSON.parse(serializedEvent) });
    },
    IVSBroadcastClient: {
      Stage,
      LocalStageStream,
      StageConnectionState: {
        CONNECTED: 'connected',
        CONNECTING: 'connecting',
        DISCONNECTED: 'disconnected',
      },
      SubscribeType: { AUDIO_VIDEO: 'audio-video', NONE: 'none' },
      StreamType: { VIDEO: 'video', AUDIO: 'audio' },
    },
  });
  const source = await readFile(new URL('./bridge.js', import.meta.url), 'utf8');
  const effectsSource = await readFile(new URL('../../../../flutter_realtime_video_effects/web/video-effects-bridge.js', import.meta.url), 'utf8');
  vm.runInContext(effectsSource, context, {filename: 'video-effects-bridge.js'});
  vm.runInContext(source, context, { filename: 'bridge.js' });
  return {
    bridge: context.MediaProviderBridge,
    calls,
    events,
    getStage: () => stage,
  };
}

test('IVS bridge publishes only with publisher credentials and refreshes strategy', async () => {
  const { bridge, calls, getStage } = await createIvsHarness();
  const payload = {
    participantId: 'host-1',
    displayName: 'Host',
    role: 'host',
    ivs: {
      token: 'publisher-token',
      capabilities: ['PUBLISH', 'SUBSCRIBE'],
    },
  };

  await bridge.create('ivs', 'stage-1', JSON.stringify(payload));
  const stage = getStage();
  assert.equal(stage.strategy.shouldPublishParticipant(), true);
  assert.equal(
    stage.strategy.shouldSubscribeToParticipant({
      capabilities: new Set(['subscribe']),
    }),
    'audio-video',
  );

  await bridge.join('ivs', 'stage-1');
  assert.ok(calls.some((call) => call.startsWith('getUserMedia:')));
  assert.ok(calls.includes('stage.join'));

  await bridge.command(
    'ivs',
    'stage-1',
    'setMuted',
    JSON.stringify({ muted: true }),
  );
  assert.ok(calls.some((call) => call.startsWith('mute:audio-') && call.endsWith(':true')));

  await bridge.command(
    'ivs',
    'stage-1',
    'selectDevice',
    JSON.stringify({
      device: { id: 'camera-2', kind: 'camera', label: 'Camera 2' },
    }),
  );
  assert.ok(calls.includes('stage.refreshStrategy'));

  await bridge.dispose('ivs', 'stage-1');
  assert.ok(calls.includes('stage.leave'));
  assert.ok(calls.includes('stage.removeAllListeners'));
});

test('IVS viewer never requests local media or publishes', async () => {
  const { bridge, calls, getStage } = await createIvsHarness();
  const payload = {
    participantId: 'viewer-1',
    displayName: 'Viewer',
    role: 'viewer',
    ivs: {
      token: 'viewer-token',
      capabilities: ['SUBSCRIBE'],
    },
  };

  await bridge.create('ivs', 'stage-viewer', JSON.stringify(payload));
  assert.equal(getStage().strategy.shouldPublishParticipant(), false);
  await bridge.join('ivs', 'stage-viewer');
  assert.equal(calls.some((call) => call.startsWith('getUserMedia:')), false);
  assert.ok(calls.includes('stage.join'));
  await bridge.dispose('ivs', 'stage-viewer');
});

async function createAgoraHarness() {
  const calls = [];
  const events = [];
  let mediaSequence = 0;

  function mediaTrack(kind, id) {
    return {
      kind,
      id,
      enabled: true,
      clone() { const copy = mediaTrack(kind, id); copy.origin = this.origin || this; copy.isClone = true; return copy; },
      stop() {
        calls.push(`stop:${id}${this.isClone ? ':clone' : ''}`);
      },
      getSettings() {
        return kind === 'video' ? { width: 1280, height: 720 } : {};
      },
    };
  }

  const mediaDevices = {
    async getUserMedia(constraints) {
      mediaSequence += 1;
      calls.push(`getUserMedia:${JSON.stringify(constraints)}`);
      const track = mediaTrack(constraints.video ? 'video' : 'audio', `camera-${mediaSequence}`);
      return {
        getTracks: () => [track],
        getVideoTracks: () => track.kind === 'video' ? [track] : [],
      };
    },
    async enumerateDevices() {
      return [
        { deviceId: 'cam-1', label: 'Camera 1', groupId: 'g1', kind: 'videoinput' },
        { deviceId: 'cam-2', label: 'Camera 2', groupId: 'g2', kind: 'videoinput' },
      ];
    },
  };

  const canvasTrack = mediaTrack('video', 'sdk-processed-video');
  const canvasContext = {
    save() {},
    restore() {},
    clearRect() {},
    drawImage() {},
    fillRect() {},
    putImageData() {},
    set filter(_) {},
    set globalCompositeOperation(_) {},
  };
  const createCanvas = () => ({
    width: 0,
    height: 0,
    getContext: () => canvasContext,
    captureStream: () => ({
      getVideoTracks: () => [canvasTrack],
    }),
  });
  const createVideo = () => ({
    autoplay: false,
    muted: false,
    playsInline: false,
    readyState: 2,
    videoWidth: 1280,
    videoHeight: 720,
    srcObject: null,
    async play() {},
    requestVideoFrameCallback() {
      return 1;
    },
    cancelVideoFrameCallback() {},
  });

  const client = {
    remoteUsers: [],
    handlers: new Map(),
    on(name, handler) {
      this.handlers.set(name, handler);
    },
    async setClientRole(role) {
      calls.push(`role:${role}`);
    },
    async join(appId, channelName, token, uid) {
      calls.push(`join:${appId}:${channelName}:${token}:${uid}`);
    },
    async publish(track) {
      const tracks = Array.isArray(track) ? track : [track];
      for (const item of tracks) calls.push(`publish:${item.id}`);
    },
    async unpublish(track) {
      calls.push(`unpublish:${track.id}`);
    },
    async subscribe() {},
    async leave() {
      calls.push('client.leave');
    },
    removeAllListeners() {},
    getRTCStats() {
      return {};
    },
  };

  const audioTrack = {
    id: 'agora-audio',
    play() {},
    async setEnabled(enabled) {
      calls.push(`audio-enabled:${enabled}`);
    },
    close() {},
  };
  const customVideoTrack = {
    id: 'agora-custom-video',
    play() {},
    stop() {},
    close() {
      calls.push('custom-video.close');
    },
  };
  const imageSegmenter = {
    segmentForVideo() {
      return { confidenceMasks: [], close() {} };
    },
    close() {
      calls.push('segmenter.close');
    },
  };

  const context = vm.createContext({
    console,
    URL,
    performance: { now: () => 1 },
    navigator: { mediaDevices },
    requestAnimationFrame: () => 1,
    cancelAnimationFrame: () => {},
    document: {
      baseURI: 'https://example.test/',
      createElement(tag) {
        return tag === 'video' ? createVideo() : createCanvas();
      },
      getElementById: () => null,
    },
    ImageData: class {
      constructor(data, width, height) {
        this.data = data;
        this.width = width;
        this.height = height;
      }
    },
    MediaStream: class {
      constructor(tracks) {
        this.tracks = tracks;
      }
    },
    SdkVideoEffectsVision: {
      FaceDetector: {async createFromOptions(){return {detectForVideo(){return {detections:[]};},close(){}};}},
      FilesetResolver: {
        async forVisionTasks(path) {
          calls.push(`vision.fileset:${path}`);
          return { path };
        },
      },
      ImageSegmenter: {
        async createFromOptions(_fileset, options) {
          calls.push(`segmenter.create:${options.runningMode}`);
          return imageSegmenter;
        },
      },
    },
    AgoraRTC: {
      createClient() {
        return client;
      },
      async createMicrophoneAudioTrack() {
        calls.push('createMicrophoneAudioTrack');
        return audioTrack;
      },
      createCustomVideoTrack({ mediaStreamTrack }) {
        calls.push(`createCustomVideoTrack:${mediaStreamTrack.id}`);
        context.supplierInputs?.push({provider: 'agora', track: mediaStreamTrack});
        return customVideoTrack;
      },
      async createScreenVideoTrack() {
        throw new Error('screen share not expected');
      },
      async getCameras() {
        return [
          { deviceId: 'cam-1', label: 'Camera 1' },
          { deviceId: 'cam-2', label: 'Camera 2' },
        ];
      },
    },
    setInterval: () => 1,
    clearInterval: () => {},
    __flutterMediaProviderOnEvent: (sessionId, serializedEvent) => {
      events.push({ sessionId, event: JSON.parse(serializedEvent) });
    },
  });
  const source = await readFile(new URL('./bridge.js', import.meta.url), 'utf8');
  const effectsSource = await readFile(new URL('../../../../flutter_realtime_video_effects/web/video-effects-bridge.js', import.meta.url), 'utf8');
  vm.runInContext(effectsSource, context, {filename: 'video-effects-bridge.js'});
  vm.runInContext(source, context, { filename: 'bridge.js' });
  return {
    bridge: context.MediaProviderBridge,
    effectsBridge: context.RealtimeVideoEffectsBridge,
    context,
    calls,
    events,
  };
}

const agoraPayload = {
  participantId: '42',
  displayName: 'Ada',
  role: 'participant',
  agora: {
    appId: 'app-id',
    channelName: 'channel-a',
    token: 'token',
    uid: 42,
  },
};

test('Agora Web defers camera publication until SDK effects are configured', async () => {
  const { bridge, calls } = await createAgoraHarness();

  await bridge.create('agora', 'agora-1', JSON.stringify(agoraPayload));
  await bridge.join('agora', 'agora-1');

  assert.ok(calls.includes('publish:agora-audio'));
  assert.equal(
    calls.some((call) => call.startsWith('getUserMedia:')),
    false,
  );
  assert.equal(
    calls.some((call) => call.startsWith('createCustomVideoTrack:')),
    false,
  );

  await bridge.command(
    'agora',
    'agora-1',
    'setBackgroundEffect',
    JSON.stringify({ type: 'blur', blurStrength: 'medium' }),
  );
  assert.equal(
    calls.some((call) => call.startsWith('getUserMedia:')),
    false,
  );

  await bridge.command(
    'agora',
    'agora-1',
    'setVideoEnabled',
    JSON.stringify({ enabled: true }),
  );

  assert.ok(
    calls.some((call) => call.startsWith('vision.fileset:')),
  );
  assert.ok(calls.includes('segmenter.create:VIDEO'));
  assert.ok(calls.includes('createCustomVideoTrack:sdk-processed-video'));
  assert.ok(calls.includes('publish:agora-custom-video'));

  await bridge.dispose('agora', 'agora-1');
});

test('Agora Web camera selection stays inside the SDK processor pipeline', async () => {
  const { bridge, calls } = await createAgoraHarness();

  await bridge.create('agora', 'agora-2', JSON.stringify(agoraPayload));
  await bridge.join('agora', 'agora-2');
  await bridge.command(
    'agora',
    'agora-2',
    'setVideoEnabled',
    JSON.stringify({ enabled: true }),
  );
  await bridge.command(
    'agora',
    'agora-2',
    'selectDevice',
    JSON.stringify({
      device: { id: 'cam-2', label: 'Camera 2', kind: 'camera' },
    }),
  );

  assert.ok(
    calls.some(
      (call) =>
        call.startsWith('getUserMedia:') &&
        call.includes('"deviceId":{"exact":"cam-2"}'),
    ),
  );
  assert.equal(
    calls.filter((call) => call.startsWith('createCustomVideoTrack:')).length,
    1,
  );

  await bridge.dispose('agora', 'agora-2');
});

test('SDK local preview applies blur without joining or publishing to Agora', async () => {
  const { effectsBridge, calls } = await createAgoraHarness();

  await effectsBridge.createSource(
    'preview-1',
    JSON.stringify({
      effect: { type: 'none', blurStrength: 'medium' },
    }),
  );

  assert.ok(calls.some((call) => call.startsWith('getUserMedia:')));
  assert.equal(calls.some((call) => call.startsWith('join:')), false);
  assert.equal(calls.some((call) => call.startsWith('publish:')), false);

  await effectsBridge.setEffect(
    'preview-1',
    JSON.stringify({ type: 'blur', blurStrength: 'medium' }),
  );

  assert.ok(calls.includes('segmenter.create:VIDEO'));
  assert.equal(
    calls.some((call) => call.startsWith('createCustomVideoTrack:')),
    false,
  );

  effectsBridge.disposeSource('preview-1');
  assert.ok(calls.includes('stop:sdk-processed-video'));
});

test('Agora Web publishes an attached SDK processed source without recapturing camera', async () => {
  const { bridge, effectsBridge, calls } = await createAgoraHarness();

  await effectsBridge.createSource(
    'effects-source-1',
    JSON.stringify({
      effect: { type: 'blur', blurStrength: 'medium' },
    }),
  );
  const captureCallsAfterEffectsSource = calls.filter((call) =>
    call.startsWith('getUserMedia:')
  ).length;

  await bridge.create('agora', 'agora-sink-1', JSON.stringify(agoraPayload));
  await bridge.join('agora', 'agora-sink-1');
  await bridge.command(
    'agora',
    'agora-sink-1',
    'attachProcessedVideoSource',
    JSON.stringify({ sourceId: 'effects-source-1' }),
  );
  await bridge.command(
    'agora',
    'agora-sink-1',
    'setVideoEnabled',
    JSON.stringify({ enabled: true }),
  );

  assert.equal(
    calls.filter((call) => call.startsWith('getUserMedia:')).length,
    captureCallsAfterEffectsSource,
  );
  assert.ok(calls.includes('createCustomVideoTrack:sdk-processed-video'));
  assert.ok(calls.includes('publish:agora-custom-video'));

  await bridge.dispose('agora', 'agora-sink-1');
  effectsBridge.disposeSource('effects-source-1');
});


test('all five Web suppliers consume clones of one processed source and camera switching never recaptures in suppliers', async () => {
  const h = await createAgoraHarness();
  const inputs = [];
  h.context.supplierInputs = inputs;
  const receive = (provider, track) => { if (track) inputs.push({provider,track}); };
  const trtc = {
    on(){}, async enterRoom(){}, async startLocalAudio(){}, async stopLocalVideo(){},
    async startLocalVideo({option}){assert.ok(option.videoTrack); receive('trtc', option.videoTrack);},
    getVideoTrack(){return inputs.find(i=>i.provider==='trtc')?.track;},
    async updateLocalVideo({option}){assert.ok(option.videoTrack);receive('trtc',option.videoTrack);},
    async exitRoom(){}, destroy(){},
  };
  h.context.TRTC = {create:()=>trtc, TYPE:{SCENE_RTC:'rtc'}};
  const artc = {
    publisher:{streamManager:{cameraCaptureDisabled:true}}, on(){}, setChannelProfile(){},
    async enableLocalVideo(enabled){assert.equal(enabled,false,'ARTC must never open its own raw camera'); this.publisher.streamManager.cameraCaptureDisabled=true;},
    async publishLocalVideoStream(){}, async joinChannel(){}, async muteLocalCamera(){},
    async switchCamera(deviceId, track){assert.equal(deviceId,undefined); assert.equal(this.publisher.streamManager.cameraCaptureDisabled,false);receive('artc',track);},
    async leaveChannel(){}, async destroy(){},
  };
  h.context.AliRtcEngine = {createInstance:()=>artc, AliRtcSdkChannelProfile:{AliRtcSdkCommunication:'rtc'},
    AliRtcSdkClientRole:{}, AliRtcVideoTrack:{AliRtcVideoTrackCamera:0,AliRtcVideoTrackScreen:1}, AliRtcConnectionStatus:{}};
  h.context.IVSBroadcastClient = {
    Stage:class {constructor(_token,strategy){this.strategy=strategy;} on(){} async join(){} refreshStrategy(){} leave(){} removeAllListeners(){}},
    LocalStageStream:class {constructor(track){this.mediaStreamTrack=track;this.id=track.id;if(track.kind==='video')receive('ivs',track);}setMuted(){}},
    StageConnectionState:{},StreamType:{AUDIO:'audio',VIDEO:'video'},SubscribeType:{NONE:0,AUDIO_VIDEO:1},
  };
  const audioVideo = {addObserver(){},removeObserver(){}, realtimeSubscribeToAttendeeIdPresence(){},realtimeUnsubscribeToAttendeeIdPresence(){},
    realtimeSubscribeToReceiveDataMessage(){},realtimeUnsubscribeFromReceiveDataMessage(){},
    async listAudioInputDevices(){return [];},async listVideoInputDevices(){return [];},
    async startVideoInput(stream){assert.ok(stream.tracks);receive('chime',stream.tracks[0]);},async stopVideoInput(){},
    start(){},stop(){},startLocalVideoTile(){},stopLocalVideoTile(){},getAllVideoTiles(){return [];}};
  h.context.ChimeSDK = {ConsoleLogger:class {},LogLevel:{WARN:1},MeetingSessionConfiguration:class {},
    DefaultDeviceController:class {async destroy(){}}, DefaultMeetingSession:class {constructor(){this.audioVideo=audioVideo;}},MeetingSessionStatusCode:{Left:0}};
  await h.effectsBridge.createSource('shared-output', {effect:{type:'blur'}});
  const output = h.effectsBridge.getTrack('shared-output');
  for (const provider of ['agora','trtc','artc','ivs','chime']) {
    const payload = {participantId:'publisher',displayName:'Publisher',role:'participant',
      agora:agoraPayload.agora,trtc:{sdkAppId:1,strRoomId:'room',userId:'publisher',userSig:'test'},
      artc:{authInfo:'test',userId:'publisher'},ivs:{token:'test',capabilities:['PUBLISH','SUBSCRIBE']},
      meeting:chimePayload.meeting,attendee:chimePayload.attendee};
    await h.bridge.create(provider,provider,payload);await h.bridge.join(provider,provider);
    await h.bridge.command(provider,provider,'attachProcessedVideoSource',{sourceId:'shared-output'});
    await h.bridge.command(provider,provider,'setVideoEnabled',{enabled:true});
    const input = inputs.find(i=>i.provider===provider)?.track;
    assert.ok(input,`${provider} received input`);assert.notEqual(input,output);assert.equal(input.origin,output);
    await h.bridge.command(provider,provider,'selectDevice',{device:{id:'cam-2',kind:'camera'}});
    await h.bridge.command(provider,provider,'detachProcessedVideoSource',{});
    await h.bridge.dispose(provider,provider);
  }
  // One initial camera plus the five SDK-controlled selections; IVS requests audio only.
  const captures=h.calls.filter(c=>typeof c==='string' && c.startsWith('getUserMedia:')).map(c=>JSON.parse(c.slice('getUserMedia:'.length)));
  assert.equal(captures.filter(c=>c.video).length,6);
  assert.equal(h.calls.includes('stop:sdk-processed-video'),false,'disposing suppliers must preserve the source');
  h.effectsBridge.disposeSource('shared-output');assert.ok(h.calls.includes('stop:sdk-processed-video'));
});
