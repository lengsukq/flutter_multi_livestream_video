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
  assert.ok(calls.includes('startVideoInput:cam-1'));
  assert.ok(calls.includes('start'));
  assert.ok(calls.includes('startLocalVideoTile'));

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
