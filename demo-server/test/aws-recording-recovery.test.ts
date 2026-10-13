import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import {mkdtempSync, readFileSync, rmSync} from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import {FileRecordingJobStore} from '../recording/file-recording-job-store.ts';
import {RoomDirectory} from '../providers/room-directory.ts';
import type {NamedRoomEntry} from '../types.ts';

test('AWS Demo rooms resume after restart without persisting raw tokens', () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), 'aws-room-recovery-'));
  try {
    const file = path.join(dir, 'rooms.json');
    const room = {
      provider: 'chime', roomCode: '123456', providerRoomName: 'id',
      createdAt: new Date().toISOString(), lastHeartbeatMs: Date.now(),
      roomMode: 'meeting' as const, roomOwnerCredentialHash: crypto.randomUUID(),
      attendees: [{
        attendeeId: 'attendee', externalUserId: 'host',
        participantCredentialHash: 'hashed-credential',
        role: 'host' as const, joinedAt: new Date().toISOString(),
      }],
      meeting: {MeetingId: 'id', MeetingArn: 'arn:aws:chime:us-east-1:123:meeting/id', TenantIds: []},
    };
    const first = new RoomDirectory(file);
    first.register(room, ['id']);
    const serialized = readFileSync(file, 'utf8');
    assert.ok(!serialized.includes('join-token-secret'));
    const restored = new RoomDirectory(file);
    assert.equal(restored.get('id')?.roomCode, room.roomCode);
    assert.equal(restored.get(room.roomCode)?.attendees[0]?.participantCredentialHash, 'hashed-credential');
    const recording = new FileRecordingJobStore<{id: string}>(
      path.join(dir, 'recordings'), 'chime');
    recording.save(room as NamedRoomEntry, {id: 'job-1'});
    const recovered = new FileRecordingJobStore<{id: string}>(
      path.join(dir, 'recordings'), 'chime');
    assert.equal(recovered.load(room as NamedRoomEntry)?.id, 'job-1');
    restored.remove(room.roomCode);
    assert.equal(new RoomDirectory(file).get(room.roomCode), null);
  } finally {
    rmSync(dir, {recursive: true, force: true});
  }
});
