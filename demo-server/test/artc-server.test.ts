import assert from 'node:assert/strict';
import { spawn, type ChildProcess } from 'node:child_process';
import { once } from 'node:events';
import os from 'node:os';
import path from 'node:path';
import test, { after, before } from 'node:test';

const appKey = 'test-only-artc-app-key-not-for-response';
let serverProcess: ChildProcess | undefined;
let baseUrl: string | undefined;
let output = '';

interface ArtcApiBody {
  provider?: string;
  role?: string;
  roomCode?: string;
  participantId?: string;
  artc?: {
    appId?: string;
    channelId?: string;
    userId?: string;
    authInfo?: string;
    expiresAtMs?: number;
  };
  error?: { code?: string };
  providers?: Record<string, { configured?: boolean }>;
}

function requireBaseUrl(): string {
  assert.ok(baseUrl, 'ARTC test server URL is not available');
  return baseUrl;
}

before(async () => {
  const stateFile = path.join(os.tmpdir(), `artc-provider-test-${process.pid}.json`);
  serverProcess = spawn(process.execPath, ['server.ts'], {
    cwd: path.resolve(import.meta.dirname, '..'),
    env: {
      PATH: process.env.PATH,
      PORT: '0',
      MEDIA_DEFAULT_PROVIDER: 'artc',
      MEDIA_PROVIDER_STATE_PATH: stateFile,
      ARTC_APP_ID: 'demo-artc-app',
      ARTC_APP_KEY: appKey,
      ARTC_TOKEN_TTL_SECONDS: '600',
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
    if (serverProcess.exitCode != null) throw new Error(`ARTC test server exited: ${output}`);
    await new Promise((resolve) => setTimeout(resolve, 25));
  }
  assert.ok(baseUrl, `ARTC test server did not start: ${output}`);
});

after(async () => {
  if (!serverProcess || serverProcess.exitCode != null) return;
  serverProcess.kill('SIGTERM');
  await Promise.race([once(serverProcess, 'exit'), new Promise((resolve) => setTimeout(resolve, 3000))]);
});

async function post(
  endpoint: string,
  body: Record<string, unknown>,
): Promise<{ status: number; body: ArtcApiBody }> {
  const response = await fetch(`${requireBaseUrl()}${endpoint}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Media-Backend-Contract': '1',
    },
    body: JSON.stringify(body),
  });
  return { status: response.status, body: await response.json() as ArtcApiBody };
}

test('assigns ARTC broadcast roles, signs short-lived auth info, and refreshes the same identity', async () => {
  const created = await post('/rooms', {
    roomCode: 'artcHost01',
    nickname: 'Host',
    roomMode: 'broadcast',
  });
  assert.equal(created.status, 200);
  assert.equal(created.body.provider, 'artc');
  assert.equal(created.body.role, 'host');
  assert.ok(created.body.artc?.authInfo);
  assert.equal(created.body.participantId, created.body.artc?.userId);
  assert.equal(created.body.artc?.appId, 'demo-artc-app');
  assert.equal(created.body.artc?.channelId, 'media-artcHost01');
  assert.ok(created.body.artc?.expiresAtMs);
  assert.equal(created.body.artc!.expiresAtMs! > Date.now(), true);
  assert.equal(JSON.stringify(created.body).includes(appKey), false);

  const auth = JSON.parse(Buffer.from(created.body.artc!.authInfo!, 'base64').toString('utf8')) as Record<string, unknown>;
  assert.equal(auth.appid, 'demo-artc-app');
  assert.equal(auth.channelid, 'media-artcHost01');
  assert.equal(auth.userid, created.body.participantId);
  assert.equal(typeof auth.token, 'string');

  const forcedParticipant = await post('/rooms/artcHost01/join', {
    userId: 'Participant',
    role: 'participant',
  });
  assert.equal(forcedParticipant.status, 200);
  assert.equal(forcedParticipant.body.role, 'viewer');

  const viewer = await post('/rooms/artcHost01/join', {
    userId: 'Viewer',
  });
  assert.equal(viewer.status, 200);
  assert.equal(viewer.body.role, 'viewer');
  const refreshed = await post('/rooms/artcHost01/credentials/refresh', {
    participantId: viewer.body.participantId,
    role: 'viewer',
  });
  assert.equal(refreshed.status, 200);
  assert.equal(refreshed.body.provider, 'artc');
  assert.equal(refreshed.body.roomCode, 'artcHost01');
  assert.equal(refreshed.body.participantId, viewer.body.participantId);
  assert.equal(refreshed.body.role, 'viewer');
  assert.equal(JSON.stringify(refreshed.body).includes(appKey), false);

  const changedRole = await post('/rooms/artcHost01/credentials/refresh', {
    participantId: viewer.body.participantId,
    role: 'host',
  });
  assert.equal(changedRole.status, 403);

  const overviewResponse = await fetch(`${requireBaseUrl()}/api/overview`);
  const overview = await overviewResponse.json() as ArtcApiBody;
  assert.equal(overview.providers?.artc?.configured, true);
  assert.equal(JSON.stringify(overview).includes(appKey), false);
});

test('assigns participant role to every ARTC meeting attendee', async () => {
  const created = await post('/rooms', {
    roomCode: 'artcMeet01',
    nickname: 'Participant',
    roomMode: 'meeting',
  });
  assert.equal(created.status, 200);
  const forcedHost = await post('/rooms/artcMeet01/join', {
    userId: 'Host',
    role: 'host',
  });
  assert.equal(forcedHost.status, 200);
  assert.equal(forcedHost.body.role, 'participant');
});
