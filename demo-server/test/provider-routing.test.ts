import assert from 'node:assert/strict';
import { spawn, type ChildProcess } from 'node:child_process';
import { once } from 'node:events';
import os from 'node:os';
import path from 'node:path';
import test, { after, before } from 'node:test';

let serverProcess: ChildProcess | undefined;
let baseUrl: string | undefined;
let output = '';

interface ApiBody {
  activeProvider?: string;
  provider?: string;
  roomCode?: string;
  providerList?: Array<{ id: string }>;
  providers?: Record<string, { configured?: boolean }>;
  rooms?: Array<{
    roomCode?: string;
    attendeeCount?: number;
    attendees?: Array<{
      externalUserId?: string;
      deviceId?: string;
    }>;
  }>;
  error?: { code?: string };
}

function requireBaseUrl(): string {
  assert.ok(baseUrl, 'test server URL is not available');
  return baseUrl;
}

before(async () => {
  const stateFile = path.join(os.tmpdir(), `provider-routing-test-${process.pid}.json`);
  serverProcess = spawn(process.execPath, ['server.ts'], {
    cwd: path.resolve(import.meta.dirname, '..'),
    env: {
      PATH: process.env.PATH,
      PORT: '0',
      MEDIA_DEFAULT_PROVIDER: 'livekit',
      MEDIA_PROVIDER_STATE_PATH: stateFile,
      LIVEKIT_URL: 'ws://127.0.0.1:7880',
      LIVEKIT_API_KEY: 'test-api-key',
      LIVEKIT_API_SECRET: 'test-api-secret',
      EMPTY_CLOSE_AFTER_MS: '60000',
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  serverProcess.stdout?.setEncoding('utf8');
  serverProcess.stderr?.setEncoding('utf8');
  serverProcess.stdout?.on('data', (chunk: string) => {
    output += chunk;
    const match = output.match(/media-demo-server on :(\d+)/);
    if (match) baseUrl = `http://127.0.0.1:${match[1]}`;
  });
  serverProcess.stderr?.on('data', (chunk: string) => { output += chunk; });

  const started = Date.now();
  while (!baseUrl && Date.now() - started < 10000) {
    if (serverProcess.exitCode != null) throw new Error(`Provider routing test server exited: ${output}`);
    await new Promise((resolve) => setTimeout(resolve, 25));
  }
  assert.ok(baseUrl, `Provider routing test server did not start: ${output}`);
});

after(async () => {
  if (!serverProcess || serverProcess.exitCode != null) return;
  serverProcess.kill('SIGTERM');
  await Promise.race([once(serverProcess, 'exit'), new Promise((resolve) => setTimeout(resolve, 3000))]);
});

async function post(
  endpoint: string,
  body: Record<string, unknown>,
): Promise<{ status: number; body: ApiBody }> {
  const response = await fetch(`${requireBaseUrl()}${endpoint}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-Media-Backend-Contract': '1' },
    body: JSON.stringify(body),
  });
  return { status: response.status, body: await response.json() as ApiBody };
}

test('provider metadata is dynamic and unconfigured providers cannot be selected', async () => {
  const overviewResponse = await fetch(`${requireBaseUrl()}/api/overview`);
  const overview = await overviewResponse.json() as ApiBody;

  assert.equal(overview.activeProvider, 'livekit');
  assert.ok(Array.isArray(overview.providerList));
  assert.equal(overview.providerList.some((provider: { id: string }) => provider.id === 'livekit'), true);
  assert.equal(overview.providers?.livekit?.configured, true);
  assert.equal(overview.providers?.agora?.configured, false);

  const unconfigured = await post('/api/provider', { provider: 'agora' });
  assert.equal(unconfigured.status, 503);
  assert.ok(unconfigured.body.error);
  assert.equal(unconfigured.body.error.code, 'provider-not-configured');
});

test('switching the active provider does not change an existing room provider', async () => {
  const created = await post('/rooms', {
    roomCode: 'stickyRoom1',
    nickname: 'Host',
    role: 'participant',
    deviceId: 'device-sticky-001',
  });
  assert.equal(created.status, 200);
  assert.equal(created.body.provider, 'livekit');

  const rejoinedSameDevice = await post('/rooms/stickyRoom1/join', {
    userId: 'Renamed Host',
    role: 'participant',
    deviceId: 'device-sticky-001',
  });
  assert.equal(rejoinedSameDevice.status, 200);

  const presenceResponse = await fetch(`${requireBaseUrl()}/api/overview`);
  const presence = await presenceResponse.json() as ApiBody;
  const stickyRoom = presence.rooms?.find((room) => room.roomCode === 'stickyRoom1');
  assert.equal(stickyRoom?.attendeeCount, 1);
  assert.equal(stickyRoom?.attendees?.[0]?.externalUserId, 'Renamed Host');
  assert.equal(stickyRoom?.attendees?.[0]?.deviceId, 'device-sticky-001');

  const switched = await post('/api/provider', { provider: 'chime' });
  assert.equal(switched.status, 200);
  assert.equal(switched.body.activeProvider, 'chime');

  const joined = await post('/rooms/stickyRoom1/join', {
    userId: 'Guest',
    role: 'participant',
  });
  assert.equal(joined.status, 200);
  assert.equal(joined.body.provider, 'livekit');
  assert.equal(joined.body.roomCode, 'stickyRoom1');

  const chimeUnsupportedRole = await post('/rooms', {
    roomCode: 'chimeHost1',
    nickname: 'Host',
    role: 'host',
  });
  assert.equal(chimeUnsupportedRole.status, 400);
  assert.ok(chimeUnsupportedRole.body.error);
  assert.equal(chimeUnsupportedRole.body.error.code, 'unsupported-role');
});
