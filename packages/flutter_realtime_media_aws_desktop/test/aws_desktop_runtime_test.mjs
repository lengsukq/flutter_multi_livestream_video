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
