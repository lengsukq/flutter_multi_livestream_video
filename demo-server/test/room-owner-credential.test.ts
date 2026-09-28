import assert from 'node:assert/strict';
import test from 'node:test';

import {
  issueRoomOwnerCredential,
  matchesRoomOwnerCredential,
} from '../room-owner-credential.ts';
import type { RoomEntry } from '../types.ts';

function room(): RoomEntry {
  return {
    provider: 'livekit',
    roomCode: 'owner01',
    roomMode: 'broadcast',
    createdAt: new Date().toISOString(),
    lastHeartbeatMs: Date.now(),
    attendees: [],
  };
}

test('room owner credential is random proof stored only as a digest', () => {
  const entry = room();
  const credential = issueRoomOwnerCredential(entry);

  assert.ok(credential.length >= 40);
  assert.ok(entry.roomOwnerCredentialHash);
  assert.notEqual(entry.roomOwnerCredentialHash, credential);
  assert.equal(matchesRoomOwnerCredential(entry, credential), true);
  assert.equal(matchesRoomOwnerCredential(entry, 'wrong-proof'), false);
  assert.equal(matchesRoomOwnerCredential(entry, ''), false);
});
