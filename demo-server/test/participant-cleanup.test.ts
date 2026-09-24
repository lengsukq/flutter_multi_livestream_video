import assert from 'node:assert/strict';
import test from 'node:test';

import { createChimeProvider } from '../providers/chime.ts';
import { createLiveKitProvider } from '../providers/livekit.ts';
import type { ChimeRoomEntry } from '../types.ts';

const normalizeName = (raw: unknown) => String(raw ?? '').trim();

test('LiveKit removes a participant from demo room state on leave', async () => {
  const provider = createLiveKitProvider({
    env: {
      LIVEKIT_URL: 'ws://localhost:7880',
      LIVEKIT_API_KEY: 'devkey',
      LIVEKIT_API_SECRET: 'secret',
    },
    contractVersion: 1,
    normalizeDisplayName: normalizeName,
  });
  const created = await provider.createRoom({
    roomCode: 'livekit01',
    role: 'participant',
  });
  const joined = await provider.joinRoom({
    entry: created.entry,
    rawName: 'First name',
    role: 'participant',
  });

  assert.equal(created.entry.attendees.length, 1);
  const result = provider.removeAttendee?.(
    created.entry,
    joined.participantId,
  );

  assert.equal(result?.removed, true);
  assert.equal(created.entry.attendees.length, 0);
});

test('Chime removes locally tracked attendee state on leave', () => {
  const provider = createChimeProvider({
    env: {
      AWS_REGION: 'us-east-1',
      CHIME_MEDIA_REGION: 'us-east-1',
    },
    contractVersion: 1,
    normalizeUserId: normalizeName,
  });
  const entry: ChimeRoomEntry = {
    provider: 'chime',
    roomCode: 'chime001',
    createdAt: new Date().toISOString(),
    lastHeartbeatMs: Date.now(),
    attendees: [
      {
        attendeeId: 'attendee-1',
        externalUserId: 'First name',
        joinedAt: new Date().toISOString(),
      },
    ],
    meeting: {
      MeetingId: 'meeting-1',
      TenantIds: [],
    },
  };

  const result = provider.removeAttendee?.(entry, 'attendee-1');

  assert.equal(result?.removed, true);
  assert.equal(entry.attendees.length, 0);
});
