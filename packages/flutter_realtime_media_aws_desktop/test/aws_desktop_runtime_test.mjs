import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import vm from 'node:vm';

const runtimeSource = await readFile(
  new URL('../macos/Resources/aws_desktop_runtime.js', import.meta.url),
  'utf8',
);

function createRuntime() {
  const messages = [];
  const context = {
    webkit: {
      messageHandlers: {
        awsDesktop: { postMessage: (message) => messages.push(message) },
      },
    },
    setTimeout,
    clearTimeout,
  };
  context.globalThis = context;
  vm.runInNewContext(runtimeSource, context);
  return { context, messages };
}

function createVideoRuntime(options = {}) {
  const runtime = createRuntime();
  const tracks = [];
  const nativeCommands = [];
  let frameRequestCount = 0;

  class FakeCanvas {
    constructor() {
      this.width = 300;
      this.height = 150;
      this.context = {
        fillStyle: '',
        fillRect() {},
        drawImage() {},
        getImageData() { return { data: [0, 255, 0, 255] }; },
      };
    }

    getContext() { return this.context; }
    toDataURL() { return 'data:image/png;base64,AA=='; }

    captureStream() {
      const track = {
        enabled: true,
        readyState: 'live',
        requestFrame() {},
        stop() { this.readyState = 'ended'; },
      };
      tracks.push(track);
      return {
        getVideoTracks() { return [track]; },
        getTracks() { return [track]; },
      };
    }
  }

  class FakeImage {
    naturalWidth = 0;
    naturalHeight = 0;
    onload = null;
    onerror = null;

    set src(url) {
      this.url = url;
      if (!url) return;
      setTimeout(() => {
        if (url.includes('/probe/')) {
          this.naturalWidth = 1;
          this.naturalHeight = 1;
          this.onload?.();
          return;
        }
        frameRequestCount += 1;
        if (options.failFrames) {
          this.onerror?.();
          return;
        }
        this.naturalWidth = options.frameWidth || 640;
        this.naturalHeight = options.frameHeight || 360;
        this.onload?.();
      }, 0);
    }
  }

  runtime.context.document = {
    createElement(name) {
      if (name !== 'canvas') throw new Error('Unexpected element: ' + name);
      return new FakeCanvas();
    },
  };
  runtime.context.Image = FakeImage;
  runtime.context.MediaProviderBridge = {
    async command(providerId, sessionId, name, serializedArgs) {
      nativeCommands.push({ providerId, sessionId, name, args: JSON.parse(serializedArgs) });
    },
  };

  return {
    ...runtime,
    tracks,
    nativeCommands,
    get frameRequestCount() { return frameRequestCount; },
  };
}

function deferred() {
  let resolve;
  let reject;
  const promise = new Promise((res, rej) => {
    resolve = res;
    reject = rej;
  });
  return { promise, resolve, reject };
}

async function waitFor(predicate, description) {
  const deadline = Date.now() + 1000;
  while (!predicate() && Date.now() < deadline) {
    await new Promise((resolve) => setTimeout(resolve, 2));
  }
  assert.ok(predicate(), 'Timed out waiting for ' + description);
}

test('dispatches IVS Chat operations to the bundled provider bridge', async () => {
  const { context } = createRuntime();
  const operations = [];
  context.IvsChatMessagingBridge = {
    async create(id, payload) {
      operations.push(['create', id, JSON.parse(payload)]);
    },
    async connect(id) {
      operations.push(['connect', id]);
    },
    async command(id, name, payload) {
      operations.push(['command', id, name, JSON.parse(payload)]);
    },
    async dispose(id) {
      operations.push(['dispose', id]);
    },
  };

  await context.AwsDesktopChatRuntime.invoke('create', 'session-1', {
    chat: { region: 'us-west-2', token: 'token-1' },
  });
  await context.AwsDesktopChatRuntime.invoke('connect', 'session-1', {});
  await context.AwsDesktopChatRuntime.invoke('command', 'session-1', {
    name: 'sendMessage',
    arguments: { message: 'hello' },
  });
  await context.AwsDesktopChatRuntime.invoke('dispose', 'session-1', {});

  assert.deepEqual(operations, [
    ['create', 'session-1', { chat: { region: 'us-west-2', token: 'token-1' } }],
    ['connect', 'session-1'],
    ['command', 'session-1', 'sendMessage', { message: 'hello' }],
    ['dispose', 'session-1'],
  ]);
});

test('forwards Chat events and completes token refresh requests', async () => {
  const { context, messages } = createRuntime();
  context.__flutterIvsChatOnEvent(
    'session-2',
    'message',
    JSON.stringify({ id: 'message-1', userId: 'user-1' }),
  );
  assert.deepEqual(
    JSON.parse(JSON.stringify(messages.at(-1))),
    {
      kind: 'chatEvent',
      sessionId: 'session-2',
      event: { type: 'message', id: 'message-1', userId: 'user-1' },
    },
  );

  const tokenPromise = context.__flutterIvsChatRequestToken('session-2');
  const request = messages.at(-1);
  assert.equal(request.kind, 'chatTokenRequest');
  assert.equal(request.sessionId, 'session-2');
  const token = {
    token: 'refreshed-token',
    tokenExpirationTimeMs: 2000,
    sessionExpirationTimeMs: 3000,
  };
  assert.equal(
    context.AwsDesktopChatRuntime.resolveToken(request.requestId, token, null),
    true,
  );
  assert.deepEqual(await tokenPromise, token);
});

test('rejects token refresh and reports a missing IVS Chat bridge', async () => {
  const { context } = createRuntime();
  const tokenPromise = context.__flutterIvsChatRequestToken('session-3');
  await context.AwsDesktopChatRuntime.resolveToken(
    'ivs-chat-token-1',
    null,
    'backend token refresh failed',
  );
  await assert.rejects(tokenPromise, /backend token refresh failed/);
  await assert.rejects(
    context.AwsDesktopChatRuntime.invoke('connect', 'session-3', {}),
    /bundled Amazon IVS Chat bridge is unavailable/,
  );
});

test('keeps a shared native processed source alive until both providers detach', async () => {
  const { context, tracks, nativeCommands } = createVideoRuntime();
  await context.AwsDesktopRuntime.attachProcessedVideo('chime', 'chime-session', 'shared-source', 1);
  const track = context.RealtimeVideoEffectsBridge.getTrack('shared-source');
  await context.AwsDesktopRuntime.attachProcessedVideo('ivs', 'ivs-session', 'shared-source', 1);
  assert.strictEqual(context.RealtimeVideoEffectsBridge.getTrack('shared-source'), track);

  await context.AwsDesktopRuntime.detachProcessedVideo('chime', 'chime-session', 'shared-source', 2);
  assert.equal(track.readyState, 'live');
  await context.AwsDesktopRuntime.detachProcessedVideo('ivs', 'ivs-session', 'shared-source', 2);
  assert.equal(track.readyState, 'ended');
  assert.equal(tracks.filter((value) => value.readyState === 'ended').length, 3);
  assert.deepEqual(nativeCommands.map((value) => [value.providerId, value.name]), [
    ['chime', 'attachProcessedVideoSource'],
    ['ivs', 'attachProcessedVideoSource'],
    ['chime', 'detachProcessedVideoSource'],
    ['ivs', 'detachProcessedVideoSource'],
  ]);
});

test('cancels an attach that is still waiting for WebKit capability checks', async () => {
  const { context, nativeCommands } = createVideoRuntime();
  const capability = deferred();
  context.AwsDesktopRuntime.canConsumeProcessedVideo = () => capability.promise;
  const attaching = context.AwsDesktopRuntime.attachProcessedVideo('chime', 'session', 'late-source', 1);
  await context.AwsDesktopRuntime.detachProcessedVideo('chime', 'session', null, 2);
  capability.resolve(true);
  assert.equal(await attaching, false);
  assert.deepEqual(nativeCommands.map((value) => value.name), ['detachProcessedVideoSource']);
  assert.throws(() => context.RealtimeVideoEffectsBridge.getTrack('late-source'), /Unknown native processed video source/);
});

test('serializes attach and detach when leave races with a native attach command', async () => {
  const { context, tracks, nativeCommands } = createVideoRuntime();
  const pendingAttach = deferred();
  const attachStarted = deferred();
  context.MediaProviderBridge.command = async (providerId, sessionId, name, serializedArgs) => {
    nativeCommands.push({ providerId, sessionId, name, args: JSON.parse(serializedArgs) });
    if (name === 'attachProcessedVideoSource') {
      attachStarted.resolve();
      await pendingAttach.promise;
    }
  };

  const attaching = context.AwsDesktopRuntime.attachProcessedVideo('chime', 'racing-session', 'racing-source', 1);
  await attachStarted.promise;
  const track = context.RealtimeVideoEffectsBridge.getTrack('racing-source');
  const detaching = context.AwsDesktopRuntime.detachProcessedVideo('chime', 'racing-session', 'racing-source', 2);
  assert.equal(track.readyState, 'ended');
  pendingAttach.resolve();
  await Promise.all([attaching, detaching]);
  assert.deepEqual(nativeCommands.map((value) => value.name), [
    'attachProcessedVideoSource',
    'detachProcessedVideoSource',
  ]);
  assert.equal(tracks[1].readyState, 'ended');
});

test('reports native image decoding failures and stops the captured track', async () => {
  const { context, messages, tracks, nativeCommands } = createVideoRuntime({ failFrames: true });
  await context.AwsDesktopRuntime.attachProcessedVideo('chime', 'failing-session', 'broken-source', 1);
  await waitFor(
    () => messages.some((message) => message.kind === 'processedVideoError'),
    'processed-video sourceError',
  );
  const track = context.RealtimeVideoEffectsBridge.getTrack('broken-source');
  assert.equal(track.readyState, 'ended');
  assert.equal(track.enabled, false);
  assert.equal(messages.at(-1).sourceId, 'broken-source');
  assert.equal(context.AwsDesktopRuntime.snapshot('failing-session'), null);
  assert.equal(nativeCommands[0].name, 'attachProcessedVideoSource');
  await assert.rejects(context.RealtimeVideoEffectsBridge.setEnabled('broken-source', true), /failed/);
  await new Promise((resolve) => setTimeout(resolve, 30));
  assert.equal(tracks[1].readyState, 'ended');
});
