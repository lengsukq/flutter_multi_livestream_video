import assert from 'node:assert/strict';
import test from 'node:test';

import {
  issueParticipantCredential,
  requireParticipantCredential,
} from '../participant-credential.ts';
import { ProviderOperationError } from '../providers/provider-registry.ts';
import type { RoomEntry } from '../types.ts';

function room(): RoomEntry {
  return {
    provider: 'ivs',
    roomCode: 'secure01',
    createdAt: new Date().toISOString(),
    lastHeartbeatMs: Date.now(),
    attendees: [
      {
        attendeeId: 'host-1',
        externalUserId: 'Host',
        role: 'host',
        joinedAt: new Date().toISOString(),
      },
      {
        attendeeId: 'viewer-1',
        externalUserId: 'Viewer',
        role: 'viewer',
        joinedAt: new Date().toISOString(),
      },
    ],
  };
}

test('participant credential authorizes only its own participant', () => {
  const entry = room();
  const hostCredential = issueParticipantCredential(entry, 'host-1');
  const viewerCredential = issueParticipantCredential(entry, 'viewer-1');

  assert.equal(
    requireParticipantCredential(entry, 'host-1', hostCredential).role,
    'host',
  );
  assert.throws(
    () => requireParticipantCredential(entry, 'host-1', viewerCredential),
    (error: unknown) =>
      error instanceof ProviderOperationError &&
      error.status === 403 &&
      error.code === 'forbidden',
  );
  assert.throws(
    () => requireParticipantCredential(entry, 'host-1', ''),
    (error: unknown) =>
      error instanceof ProviderOperationError &&
      error.status === 403 &&
      error.code === 'forbidden',
  );
});

test('issuing a new participant credential rotates the old proof', () => {
  const entry = room();
  const oldCredential = issueParticipantCredential(entry, 'viewer-1');
  const newCredential = issueParticipantCredential(entry, 'viewer-1');

  assert.throws(
    () => requireParticipantCredential(entry, 'viewer-1', oldCredential),
    ProviderOperationError,
  );
  assert.equal(
    requireParticipantCredential(entry, 'viewer-1', newCredential).attendeeId,
    'viewer-1',
  );
});
