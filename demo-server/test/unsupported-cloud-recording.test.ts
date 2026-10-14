import assert from 'node:assert/strict';
import {once} from 'node:events';
import test from 'node:test';
import express from 'express';
import type {AddressInfo} from 'node:net';

import type {IvsRoomEntry, RoomEntry} from '../types.ts';
import type {CloudRecordingExecutor} from '../recording/cloud-recording-executor.ts';
import {issueParticipantCredential} from '../participant-credential.ts';
import {ChimeCloudRecording} from '../recording/chime-cloud-recording.ts';
import {IvsCloudRecording} from '../recording/ivs-cloud-recording.ts';
import {registerRecordingRoutes} from '../routes/recording-routes.ts';

test('IVS requires MediaConvert and Chime requires bucket before recording, without fabricating MP4', async () => {
  const rooms = new Map<string, RoomEntry>([
    ['IVS123', {
      provider: 'ivs', roomCode: 'IVS123', stageArn: 'arn:aws:ivs:us-east-1:123:stage/abc',
      createdAt: new Date().toISOString(), lastHeartbeatMs: Date.now(),
      attendees: [{attendeeId: 'host', externalUserId: 'host', role: 'host', joinedAt: new Date().toISOString()}],
    } as IvsRoomEntry],
    ['CHI123', {
      provider: 'chime', roomCode: 'CHI123',
      meeting: {MeetingArn: 'arn:aws:chime:us-east-1:123:meeting/abc', MeetingId: 'abc', TenantIds: []},
      createdAt: new Date().toISOString(), lastHeartbeatMs: Date.now(),
      attendees: [{attendeeId: 'host', externalUserId: 'host', role: 'host', joinedAt: new Date().toISOString()}],
    }],
  ]);
  const app = express();
  app.use(express.json());
  registerRecordingRoutes(app, {
    resolveRoom: async (code) => rooms.get(String(code)) ?? null,
    recorders: new Map<string, CloudRecordingExecutor>([
      ['ivs', new IvsCloudRecording({})],
      ['chime', new ChimeCloudRecording({})],
    ]),
    contractError: (res, status, code, message) => res.status(status).json({error: {code, message}}),
  });
  const server = app.listen(0, '127.0.0.1');
  try {
    if (!server.listening) await once(server, 'listening');
    const base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
    for (const roomCode of rooms.keys()) {
      const entry = rooms.get(roomCode)!;
      const body = {
        requesterParticipantId: 'host',
        participantCredential: issueParticipantCredential(entry, 'host'),
      };
      const check = async (action: string) => {
        const response = await fetch(`${base}/rooms/${roomCode}/recording/${action}`, {
          method: 'POST', headers: {'Content-Type': 'application/json'},
          body: JSON.stringify(body),
        });
        return {status: response.status, body: await response.json() as any};
      };
      const result = await check('status');
      assert.equal(result.status, 200);
      assert.deepEqual(result.body.supportedLayouts,
        roomCode === 'CHI123' ? ['grid'] : ['grid', 'featuredParticipant']);
      assert.equal(result.body.recordingAvailable, false);
      assert.ok(result.body.recordingUnavailableReason);
      assert.equal(result.body.recordingId, null);
      assert.equal((await check('start')).status, 503);
      if (roomCode === 'CHI123') {
        const rejected = await fetch(`${base}/rooms/${roomCode}/recording/start`, {
          method: 'POST', headers: {'Content-Type': 'application/json'},
          body: JSON.stringify({...body, layout: 'speaker'}),
        });
        assert.equal(rejected.status, 422);
        assert.equal((await rejected.json() as any).error.code, 'unsupported-recording-layout');
      }
    }
  } finally {
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }
});
