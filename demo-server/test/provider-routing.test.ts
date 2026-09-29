import assert from 'node:assert/strict';
import { spawn, type ChildProcess } from 'node:child_process';
import { once } from 'node:events';
import { writeFileSync } from 'node:fs';
import { createServer, type Server } from 'node:http';
import os from 'node:os';
import path from 'node:path';
import test, { after, before } from 'node:test';

let serverProcess: ChildProcess | undefined;
let liveKitServer: Server | undefined;
let baseUrl: string | undefined;
let output = '';
const liveKitRoomServiceCalls: string[] = [];
let failLiveKitDeleteRoom = false;

interface ApiBody {
  activeProvider?: string;
  activeChatProvider?: string | null;
  provider?: string;
  engine?: string;
  roomCode?: string;
  participantId?: string;
  participantCredential?: string;
  roomOwnerCredential?: string;
  role?: string;
  roomMode?: string;
  providerList?: Array<{
    id: string;
    capabilities?: Array<{
      key?: string;
      support?: string;
      note?: string;
    }>;
  }>;
  providers?: Record<
    string,
    {
      configured?: boolean;
      engines?: Record<string, string>;
      capabilities?: Array<{ key?: string; support?: string }>;
    }
  >;
  participants?: Array<{
    participantId?: string;
    displayName?: string;
    role?: string;
    joinedAt?: string;
    deviceId?: string;
    userId?: string;
  }>;
  rooms?: Array<{
    provider?: string;
    roomCode?: string;
    roomMode?: string;
    attendeeCount?: number;
    attendees?: Array<{
      externalUserId?: string;
      deviceId?: string;
      role?: string;
    }>;
  }>;
  error?: { code?: string };
}

function requireBaseUrl(): string {
  assert.ok(baseUrl, 'test server URL is not available');
  return baseUrl;
}

before(async () => {
  liveKitServer = createServer((req, res) => {
    if (req.url?.startsWith('/twirp/livekit.RoomService/')) {
      liveKitRoomServiceCalls.push(req.url);
      req.resume();
      if (
        failLiveKitDeleteRoom &&
        req.url === '/twirp/livekit.RoomService/DeleteRoom'
      ) {
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end('{}');
        return;
      }
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end('{}');
      return;
    }
    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end('{}');
  });
  await new Promise<void>((resolve, reject) => {
    liveKitServer?.once('error', reject);
    liveKitServer?.listen(0, '127.0.0.1', resolve);
  });
  const liveKitAddress = liveKitServer.address();
  assert.ok(liveKitAddress && typeof liveKitAddress === 'object');
  const liveKitUrl = `ws://127.0.0.1:${liveKitAddress.port}`;

  const stateFile = path.join(os.tmpdir(), `provider-routing-test-${process.pid}.json`);
  writeFileSync(
    stateFile,
    JSON.stringify({ provider: 'livekit', chatProvider: 'none' }),
    'utf8',
  );
  serverProcess = spawn(process.execPath, ['server.ts'], {
    cwd: path.resolve(import.meta.dirname, '..'),
    env: {
      PATH: process.env.PATH,
      PORT: '0',
      MEDIA_DEFAULT_PROVIDER: 'livekit',
      CHAT_DEFAULT_PROVIDER: 'ivs-chat',
      IVS_CHAT_REGION: 'us-west-2',
      MEDIA_PROVIDER_STATE_PATH: stateFile,
      LIVEKIT_URL: liveKitUrl,
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
  if (serverProcess && serverProcess.exitCode == null) {
    serverProcess.kill('SIGTERM');
    await Promise.race([once(serverProcess, 'exit'), new Promise((resolve) => setTimeout(resolve, 3000))]);
  }
  if (liveKitServer?.listening) {
    await new Promise<void>((resolve, reject) => {
      liveKitServer?.close((error) => error ? reject(error) : resolve());
    });
  }
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
  assert.equal(
    overview.activeChatProvider,
    null,
    'persisted chatProvider=none must override CHAT_DEFAULT_PROVIDER',
  );
  assert.ok(Array.isArray(overview.providerList));
  assert.equal(overview.providerList.some((provider: { id: string }) => provider.id === 'livekit'), true);
  assert.equal(overview.providers?.livekit?.configured, true);
  assert.equal(overview.providers?.agora?.configured, false);
  const livekitMetadata = overview.providerList.find(
    (provider) => provider.id === 'livekit',
  );
  assert.ok(Array.isArray(livekitMetadata?.capabilities));
  assert.equal(
    livekitMetadata?.capabilities?.some(
      (capability) =>
        capability.key === 'rtcDataSend' && capability.support === 'supported',
    ),
    true,
  );
  assert.equal(overview.providers?.chime, undefined);
  assert.equal(overview.providers?.ivs, undefined);
  assert.equal(overview.providers?.aws?.engines?.meeting, 'chime');
  assert.equal(overview.providers?.aws?.engines?.broadcast, 'ivs');

  const unconfigured = await post('/api/provider', { provider: 'agora' });
  assert.equal(unconfigured.status, 503);
  assert.ok(unconfigured.body.error);
  assert.equal(unconfigured.body.error.code, 'provider-not-configured');
});

test('switching the active provider does not change an existing room provider', async () => {
  const created = await post('/rooms', {
    roomCode: 'stickyRoom1',
    nickname: 'Host',
    roomMode: 'meeting',
    deviceId: 'device-sticky-001',
  });
  assert.equal(created.status, 200);
  assert.equal(created.body.provider, 'livekit');
  assert.equal(created.body.role, 'participant');
  assert.equal(created.body.roomMode, 'meeting');
  assert.ok(created.body.roomOwnerCredential);

  const rejoinedSameDevice = await post('/rooms/stickyRoom1/join', {
    userId: 'Renamed Host',
    deviceId: 'device-sticky-001',
    roomOwnerCredential: created.body.roomOwnerCredential,
  });
  assert.equal(rejoinedSameDevice.status, 200);
  assert.equal(rejoinedSameDevice.body.role, 'participant');
  assert.equal(
    rejoinedSameDevice.body.roomOwnerCredential,
    created.body.roomOwnerCredential,
  );

  const meetingParticipants = await post('/rooms/stickyRoom1/participants', {
    requesterParticipantId: rejoinedSameDevice.body.participantId,
    participantCredential: rejoinedSameDevice.body.participantCredential,
    roomOwnerCredential: rejoinedSameDevice.body.roomOwnerCredential,
  });
  assert.equal(meetingParticipants.status, 200);
  assert.equal(meetingParticipants.body.participants?.length, 1);
  assert.equal(meetingParticipants.body.participants?.[0]?.userId, 'Renamed Host');

  const meetingGuest = await post('/rooms/stickyRoom1/join', {
    userId: 'meeting-guest',
    displayName: 'Meeting Guest',
    deviceId: 'device-sticky-guest-001',
  });
  assert.equal(meetingGuest.status, 200);
  assert.equal(meetingGuest.body.role, 'participant');

  const forbiddenMeetingManagement = await post(
    '/rooms/stickyRoom1/participants',
    {
      requesterParticipantId: meetingGuest.body.participantId,
      participantCredential: meetingGuest.body.participantCredential,
    },
  );
  assert.equal(forbiddenMeetingManagement.status, 403);

  const removeMeetingGuest = await post(
    '/rooms/stickyRoom1/participants/remove',
    {
      requesterParticipantId: rejoinedSameDevice.body.participantId,
      participantCredential: rejoinedSameDevice.body.participantCredential,
      roomOwnerCredential: rejoinedSameDevice.body.roomOwnerCredential,
      targetParticipantId: meetingGuest.body.participantId,
    },
  );
  assert.equal(removeMeetingGuest.status, 200);

  const invalidMeetingOwner = await post('/rooms/stickyRoom1/join', {
    userId: 'fake-owner',
    displayName: 'Fake Owner',
    roomOwnerCredential: 'invalid-owner-proof',
  });
  assert.equal(invalidMeetingOwner.status, 403);

  const participantHeartbeat = await post('/rooms/stickyRoom1/heartbeat', {
    participantId: rejoinedSameDevice.body.participantId,
  });
  assert.equal(participantHeartbeat.status, 200);

  const staleHeartbeat = await post('/rooms/stickyRoom1/heartbeat', {
    participantId: 'missing-participant',
  });
  assert.equal(staleHeartbeat.status, 404);
  assert.equal(staleHeartbeat.body.error?.code, 'participant-not-found');

  const presenceResponse = await fetch(`${requireBaseUrl()}/api/overview`);
  const presence = await presenceResponse.json() as ApiBody;
  const stickyRoom = presence.rooms?.find((room) => room.roomCode === 'stickyRoom1');
  assert.equal(stickyRoom?.attendeeCount, 1);
  assert.equal(stickyRoom?.attendees?.[0]?.externalUserId, 'Renamed Host');
  assert.equal(stickyRoom?.attendees?.[0]?.deviceId, 'device-sticky-001');

  const broadcast = await post('/rooms', {
    roomCode: 'broadcast01',
    displayName: 'Creator',
    userId: 'creator-user',
    roomMode: 'broadcast',
    deviceId: 'device-creator-001',
  });
  assert.equal(broadcast.status, 200);
  assert.equal(broadcast.body.role, 'host');
  assert.equal(broadcast.body.roomMode, 'broadcast');
  assert.ok(broadcast.body.roomOwnerCredential);

  const viewer = await post('/rooms/broadcast01/join', {
    userId: 'viewer-user',
    displayName: 'Viewer',
    deviceId: 'device-viewer-001',
  });
  assert.equal(viewer.status, 200);
  assert.equal(viewer.body.role, 'viewer');

  const spoofedCreator = await post('/rooms/broadcast01/join', {
    userId: 'creator-user',
    displayName: 'Impersonated Creator',
    deviceId: 'device-creator-001',
  });
  assert.equal(spoofedCreator.status, 200);
  assert.equal(
    spoofedCreator.body.role,
    'viewer',
    'client-declared creator userId/deviceId must never restore host',
  );

  const wrongOwnerProof = await post('/rooms/broadcast01/join', {
    userId: 'creator-user',
    displayName: 'Fake Creator',
    deviceId: 'device-creator-001',
    roomOwnerCredential: 'not-the-owner-proof',
  });
  assert.equal(wrongOwnerProof.status, 403);

  const creatorRejoin = await post('/rooms/broadcast01/join', {
    userId: 'creator-user',
    displayName: 'Creator again',
    deviceId: 'device-creator-001',
    roomOwnerCredential: broadcast.body.roomOwnerCredential,
  });
  assert.equal(creatorRejoin.status, 200);
  assert.equal(creatorRejoin.body.role, 'host');

  const forbiddenParticipants = await post('/rooms/broadcast01/participants', {
    requesterParticipantId: viewer.body.participantId,
    participantCredential: viewer.body.participantCredential,
  });
  assert.equal(forbiddenParticipants.status, 403);
  assert.equal(forbiddenParticipants.body.error?.code, 'forbidden');

  const hostParticipants = await post('/rooms/broadcast01/participants', {
    requesterParticipantId: creatorRejoin.body.participantId,
    participantCredential: creatorRejoin.body.participantCredential,
  });
  assert.equal(hostParticipants.status, 200);
  assert.equal(hostParticipants.body.participants?.length, 2);
  assert.equal(
    hostParticipants.body.participants?.some((item) => item.role === 'host'),
    true,
  );
  assert.equal(
    hostParticipants.body.participants?.some((item) => item.role === 'viewer'),
    true,
  );
  assert.equal(hostParticipants.body.participants?.[0]?.deviceId, undefined);
  assert.equal(typeof hostParticipants.body.participants?.[0]?.userId, 'string');

  const impersonatedHost = await post('/rooms/broadcast01/participants', {
    requesterParticipantId: creatorRejoin.body.participantId,
    participantCredential: viewer.body.participantCredential,
  });
  assert.equal(impersonatedHost.status, 403);

  const selfRemove = await post('/rooms/broadcast01/participants/remove', {
    requesterParticipantId: creatorRejoin.body.participantId,
    participantCredential: creatorRejoin.body.participantCredential,
    targetParticipantId: creatorRejoin.body.participantId,
  });
  assert.equal(selfRemove.status, 400);

  const broadcastOverviewResponse = await fetch(`${requireBaseUrl()}/api/overview`);
  const broadcastOverview = await broadcastOverviewResponse.json() as ApiBody;
  assert.equal(
    JSON.stringify(broadcastOverview).includes('participantCredential'),
    false,
  );
  assert.equal(
    JSON.stringify(broadcastOverview).includes('participantCredentialHash'),
    false,
  );
  assert.equal(
    JSON.stringify(broadcastOverview).includes('roomOwnerCredential'),
    false,
  );
  assert.equal(
    JSON.stringify(broadcastOverview).includes('roomOwnerCredentialHash'),
    false,
  );
  const broadcastRoom = broadcastOverview.rooms?.find((room) => room.roomCode === 'broadcast01');
  assert.equal(broadcastRoom?.roomMode, 'broadcast');
  assert.equal(
    broadcastRoom?.attendees?.some((attendee) => attendee.role === 'host'),
    true,
  );
  assert.equal(
    broadcastRoom?.attendees?.some((attendee) => attendee.role === 'viewer'),
    true,
  );

  const discoveredResponse = await fetch(`${requireBaseUrl()}/rooms/discover`, {
    headers: { 'X-Media-Backend-Contract': '1' },
  });
  assert.equal(discoveredResponse.status, 200);
  const discovered = await discoveredResponse.json() as ApiBody;
  const discoveredBroadcast = discovered.rooms?.find((room) => room.roomCode === 'broadcast01');
  assert.equal(discoveredBroadcast?.provider, 'livekit');
  assert.equal(discoveredBroadcast?.roomMode, 'broadcast');
  assert.equal(typeof discoveredBroadcast?.attendeeCount, 'number');
  assert.equal(discoveredBroadcast?.attendees, undefined);

  const hostClose = await post('/rooms/broadcast01/close', {
    requesterParticipantId: creatorRejoin.body.participantId,
    participantCredential: creatorRejoin.body.participantCredential,
  });
  assert.equal(hostClose.status, 200);
  assert.equal(
    liveKitRoomServiceCalls.includes('/twirp/livekit.RoomService/DeleteRoom'),
    true,
  );

  const retryRoom = await post('/rooms', {
    roomCode: 'deleteRetry1',
    displayName: 'Retry Host',
    userId: 'retry-host',
    roomMode: 'broadcast',
    deviceId: 'device-retry-001',
  });
  assert.equal(retryRoom.status, 200);
  failLiveKitDeleteRoom = true;
  const failedClose = await post('/rooms/deleteRetry1/close', {
    requesterParticipantId: retryRoom.body.participantId,
    participantCredential: retryRoom.body.participantCredential,
  });
  assert.equal(failedClose.status, 500);
  const afterFailedClose = await fetch(`${requireBaseUrl()}/api/overview`);
  const failedCloseOverview = await afterFailedClose.json() as ApiBody;
  assert.equal(
    failedCloseOverview.rooms?.some((room) => room.roomCode === 'deleteRetry1'),
    true,
    'failed provider deletion must keep the room directory entry for retry',
  );
  const discoverAfterFailedClose = await fetch(
    `${requireBaseUrl()}/rooms/discover`,
    { headers: { 'X-Media-Backend-Contract': '1' } },
  );
  const discoverAfterFailure = await discoverAfterFailedClose.json() as ApiBody;
  assert.equal(
    discoverAfterFailure.rooms?.some((room) => room.roomCode === 'deleteRetry1'),
    false,
    'partially closed rooms must not remain discoverable',
  );

  failLiveKitDeleteRoom = false;
  const retriedClose = await post('/rooms/deleteRetry1/close', {
    requesterParticipantId: retryRoom.body.participantId,
    participantCredential: retryRoom.body.participantCredential,
  });
  assert.equal(retriedClose.status, 200);
  const afterRetry = await fetch(`${requireBaseUrl()}/api/overview`);
  const retryOverview = await afterRetry.json() as ApiBody;
  assert.equal(
    retryOverview.rooms?.some((room) => room.roomCode === 'deleteRetry1'),
    false,
  );

  const closeableMeeting = await post('/rooms', {
    roomCode: 'meetClose1',
    displayName: 'Meeting Owner',
    userId: 'meeting-owner',
    roomMode: 'meeting',
    deviceId: 'device-meeting-close-001',
  });
  assert.equal(closeableMeeting.status, 200);
  assert.equal(closeableMeeting.body.role, 'participant');
  assert.ok(closeableMeeting.body.roomOwnerCredential);
  const closeMeeting = await post('/rooms/meetClose1/close', {
    requesterParticipantId: closeableMeeting.body.participantId,
    participantCredential: closeableMeeting.body.participantCredential,
    roomOwnerCredential: closeableMeeting.body.roomOwnerCredential,
  });
  assert.equal(closeMeeting.status, 200);

  const switched = await post('/api/provider', { provider: 'chime' });
  assert.equal(switched.status, 200);
  assert.equal(switched.body.activeProvider, 'aws');

  const joined = await post('/rooms/stickyRoom1/join', {
    userId: 'Guest',
  });
  assert.equal(joined.status, 200);
  assert.equal(joined.body.provider, 'livekit');
  assert.equal(joined.body.roomCode, 'stickyRoom1');

});
