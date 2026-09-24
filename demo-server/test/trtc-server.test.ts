import assert from 'node:assert/strict';
import { spawn, type ChildProcess } from 'node:child_process';
import { once } from 'node:events';
import os from 'node:os';
import path from 'node:path';
import test, { after, before } from 'node:test';

const testSecret = 'server-test-trtc-secret-not-for-response';
let serverProcess: ChildProcess | undefined;
let baseUrl: string | undefined;
let output = '';

interface TrtcApiBody {
  provider?: string;
  role?: string;
  roomCode?: string;
  participantId?: string;
  displayName?: string;
  trtc?: {
    sdkAppId?: number;
    strRoomId?: string;
    userId?: string;
    expiresAtMs?: number;
  };
  error?: { code?: string };
  providers?: Record<string, { configured?: boolean }>;
}

function requireBaseUrl(): string {
  assert.ok(baseUrl, 'TRTC test server URL is not available');
  return baseUrl;
}

before(async () => {
  const stateFile = path.join(os.tmpdir(), `trtc-provider-test-${process.pid}.json`);
  serverProcess = spawn(process.execPath, ['server.ts'], {
    cwd: path.resolve(import.meta.dirname, '..'),
    env: {
      PATH: process.env.PATH,
      PORT: '0',
      MEDIA_DEFAULT_PROVIDER: 'trtc',
      MEDIA_PROVIDER_STATE_PATH: stateFile,
      TRTC_SDK_APP_ID: '1400000001',
      TRTC_SDK_SECRET_KEY: testSecret,
      TRTC_TOKEN_TTL_SECONDS: '600',
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
  serverProcess.stderr?.on('data', (chunk: string) => {
    output += chunk;
  });

  const started = Date.now();
  while (!baseUrl && Date.now() - started < 10000) {
    if (serverProcess.exitCode != null) throw new Error(`TRTC test server exited: ${output}`);
    await new Promise((resolve) => setTimeout(resolve, 25));
  }
  assert.ok(baseUrl, `TRTC test server did not start: ${output}`);
});

after(async () => {
  if (!serverProcess || serverProcess.exitCode != null) return;
  serverProcess.kill('SIGTERM');
  await Promise.race([once(serverProcess, 'exit'), new Promise((resolve) => setTimeout(resolve, 3000))]);
});

async function post(
  endpoint: string,
  body: Record<string, unknown>,
): Promise<{ status: number; body: TrtcApiBody }> {
  const response = await fetch(`${requireBaseUrl()}${endpoint}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Media-Backend-Contract': '1',
    },
    body: JSON.stringify(body),
  });
  return { status: response.status, body: await response.json() as TrtcApiBody };
}

test('assigns TRTC broadcast roles and refreshes credentials for the same attendee', async () => {
  const created = await post('/rooms', {
    roomCode: 'trtcHost01',
    nickname: 'Host',
    roomMode: 'broadcast',
  });
  assert.equal(created.status, 200);
  assert.equal(created.body.provider, 'trtc');
  assert.equal(created.body.role, 'host');
  assert.ok(created.body.trtc);
  assert.equal(created.body.participantId, created.body.trtc.userId);
  assert.equal(created.body.trtc.sdkAppId, 1400000001);
  assert.equal(created.body.trtc.strRoomId, 'media-trtcHost01');
  assert.ok(created.body.trtc.expiresAtMs);
  assert.equal(created.body.trtc.expiresAtMs - Date.now() > 0, true);
  assert.equal(JSON.stringify(created.body).includes(testSecret), false);

  const forcedParticipant = await post('/rooms/trtcHost01/join', {
    userId: 'Participant',
    role: 'participant',
  });
  assert.equal(forcedParticipant.status, 200);
  assert.equal(forcedParticipant.body.role, 'viewer');

  const viewer = await post('/rooms/trtcHost01/join', {
    userId: 'Viewer',
  });
  assert.equal(viewer.status, 200);
  const refreshed = await post('/rooms/trtcHost01/credentials/refresh', {
    participantId: viewer.body.participantId,
    role: 'viewer',
  });
  assert.equal(refreshed.status, 200);
  assert.equal(refreshed.body.provider, 'trtc');
  assert.equal(refreshed.body.roomCode, 'trtcHost01');
  assert.equal(refreshed.body.participantId, viewer.body.participantId);
  assert.equal(refreshed.body.role, 'viewer');
  assert.equal(JSON.stringify(refreshed.body).includes(testSecret), false);

  const changedRole = await post('/rooms/trtcHost01/credentials/refresh', {
    participantId: viewer.body.participantId,
    role: 'host',
  });
  assert.equal(changedRole.status, 403);
  assert.ok(changedRole.body.error);
  assert.equal(changedRole.body.error.code, 'forbidden');

  const wrongIdentity = await post('/rooms/trtcHost01/credentials/refresh', {
    participantId: 'unknown-user',
    role: 'viewer',
  });
  assert.equal(wrongIdentity.status, 403);

  const overviewResponse = await fetch(`${requireBaseUrl()}/api/overview`);
  const overview = await overviewResponse.json() as TrtcApiBody;
  assert.equal(overview.providers?.trtc?.configured, true);
  assert.equal(JSON.stringify(overview).includes(testSecret), false);
  assert.equal(JSON.stringify(overview).includes('privateMapKey'), false);
});

test('assigns participant role to every TRTC meeting attendee', async () => {
  const created = await post('/rooms', {
    roomCode: 'trtcMeet01',
    nickname: 'Participant',
    roomMode: 'meeting',
  });
  assert.equal(created.status, 200);
  const forcedHost = await post('/rooms/trtcMeet01/join', {
    userId: 'Host',
    role: 'host',
  });
  assert.equal(forcedHost.status, 200);
  assert.equal(forcedHost.body.role, 'participant');
});
