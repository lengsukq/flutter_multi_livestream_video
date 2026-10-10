import assert from 'node:assert/strict';
import {once} from 'node:events';
import {mkdtemp, rm, writeFile} from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import express from 'express';
import type {AddressInfo} from 'node:net';

import type {NamedRoomEntry} from '../types.ts';
import {issueParticipantCredential} from '../participant-credential.ts';
import {LiveKitCloudRecording} from '../recording/livekit-cloud-recording.ts';
import {registerRecordingRoutes} from '../routes/recording-routes.ts';

test('cloud recording HTTP routes authorize only this room host and never expose credentials', async () => {
  const entry = (roomCode: string, provider = 'livekit'): NamedRoomEntry => ({
    provider, roomCode, providerRoomName: `media-${roomCode}`,
    createdAt: new Date().toISOString(), lastHeartbeatMs: Date.now(),
    attendees: [
      {attendeeId: 'host', role: 'host', joinedAt: new Date().toISOString(), externalUserId: 'host'},
      {attendeeId: 'student', role: 'participant', joinedAt: new Date().toISOString(), externalUserId: 'student'},
    ],
  });
  const rooms = new Map([
    ['room1', entry('room1')],
    ['room2', entry('room2')],
    ['other', entry('other', 'agora')],
  ]);
  const hostCredential = issueParticipantCredential(rooms.get('room1')!, 'host');
  const studentCredential = issueParticipantCredential(rooms.get('room1')!, 'student');

  const app = express();
  app.use(express.json());
  registerRecordingRoutes(app, {
    resolveRoom: async (code) => rooms.get(String(code)) ?? null,
    recorder: new LiveKitCloudRecording({}),
    contractError: (res, status, code, message) =>
      res.status(status).json({error: {code, message}}),
  });
  const server = app.listen(0, '127.0.0.1');
  try {
    if (!server.listening) await once(server, 'listening');
    const address = server.address() as AddressInfo;
    async function send(code: string, route: string, body: object) {
      const reply = await fetch(
        `http://127.0.0.1:${address.port}/rooms/${code}/recording/${route}`,
        {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(body)},
      );
      return {status: reply.status, body: await reply.json() as Record<string, any>};
    }
    const asHost = {
      requesterParticipantId: 'host',
      participantCredential: hostCredential,
    };
    assert.equal((await send('room1', 'start', {
      requesterParticipantId: 'host', participantCredential: 'wrong',
      layout: 'grid',
    })).status, 403);
    assert.equal((await send('room1', 'start', {
      requesterParticipantId: 'student', participantCredential: studentCredential,
      layout: 'grid',
    })).status, 403);
    assert.equal((await send('room2', 'status', asHost)).status, 403);
    assert.equal((await send('room1', 'status', asHost)).body.state, 'idle');
    assert.equal((await send('room1', 'start', {
      ...asHost, layout: 'grid', rawProviderParams: {storage: {secret: 'client-injected'}},
    })).status, 400);
    assert.equal((await send('room1', 'start', {
      ...asHost, layout: 'custom',
    })).status, 400);
    assert.equal((await send('room1', 'start', {...asHost, layout: 'grid'})).status, 503);
    assert.equal((await send('other', 'start', asHost)).status, 403);
    assert.equal((await send('room1', 'download', asHost)).status, 409);
  } finally {
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }
});

test('Demo MP4 download streams a finished recording with a one-time room-scoped ticket', async () => {
  const sharedDir = await mkdtemp(path.join(os.tmpdir(), 'demo-egress-download-'));
  let egressOutput = '';
  const egressFetch = (async (input: string | URL | Request, init?: RequestInit) => {
    const action = String(input).split('/').at(-1);
    if (action === 'StartEgress') {
      egressOutput = JSON.parse(String(init?.body)).outputs[0].file.filepath;
      return new Response(JSON.stringify({
        egress_id: 'EG_download', room_name: 'media-room1', status: 'EGRESS_ACTIVE',
      }), {status: 200});
    }
    if (action === 'StopEgress') {
      return new Response(JSON.stringify({
        egress_id: 'EG_download', room_name: 'media-room1', status: 'EGRESS_ENDING',
      }), {status: 200});
    }
    return new Response(JSON.stringify({items: []}), {status: 200});
  }) as typeof fetch;
  const entry: NamedRoomEntry = {
    provider: 'livekit', roomCode: 'room1', providerRoomName: 'media-room1',
    attendees: [{attendeeId: 'host', role: 'host', joinedAt: new Date().toISOString(), externalUserId: 'host'}],
    createdAt: new Date().toISOString(), lastHeartbeatMs: Date.now(),
  };
  const credential = issueParticipantCredential(entry, 'host');
  const app = express();
  app.use(express.json());
  registerRecordingRoutes(app, {
    resolveRoom: async (code) => code === 'room1' ? entry : null,
    recorder: new LiveKitCloudRecording({
      LIVEKIT_URL: 'wss://livekit.example.test',
      LIVEKIT_API_KEY: 'key',
      LIVEKIT_API_SECRET: 'secret',
      LIVEKIT_EGRESS_OUTPUT_DIR: '/out',
      LIVEKIT_RECORDING_EXPORT_DIR: sharedDir,
    }, egressFetch),
    contractError: (res, status, code, message) =>
      res.status(status).json({error: {code, message}}),
  });
  const server = app.listen(0, '127.0.0.1');
  try {
    if (!server.listening) await once(server, 'listening');
    const port = (server.address() as AddressInfo).port;
    const root = `http://127.0.0.1:${port}`;
    async function post(action: string, extra: object = {}) {
      const response = await fetch(`${root}/rooms/room1/recording/${action}`, {
        method: 'POST', headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({
          requesterParticipantId: 'host', participantCredential: credential, ...extra,
        }),
      });
      assert.equal(response.status, 200);
      return response.json() as Promise<Record<string, any>>;
    }
    await post('start', {layout: 'grid'});
    await post('stop');
    const bytes = Buffer.alloc(1024);
    bytes.write('ftyp', 4);
    bytes.write('moov', 500);
    await writeFile(path.join(sharedDir, path.basename(egressOutput)), bytes);
    assert.equal((await post('status')).canDownload, false);
    await new Promise((done) => setTimeout(done, 1600));
    assert.equal((await post('status')).canDownload, true);
    const {downloadUrl} = await post('download');
    assert.ok(downloadUrl.startsWith('/rooms/room1/recording/export/'));
    const stolen = await fetch(`${root}${downloadUrl.replace('/room1/', '/room2/')}`);
    assert.equal(stolen.status, 404);
    const again = await post('download');
    const response = await fetch(`${root}${again.downloadUrl}`);
    assert.equal(response.status, 200);
    assert.match(response.headers.get('content-disposition') ?? '', /attachment/);
    assert.equal((await response.arrayBuffer()).byteLength, bytes.length);
    assert.equal((await fetch(`${root}${again.downloadUrl}`)).status, 404);
  } finally {
    await new Promise<void>((resolve) => server.close(() => resolve()));
    await rm(sharedDir, {recursive: true, force: true});
  }
});
