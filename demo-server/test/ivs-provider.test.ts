import assert from 'node:assert/strict';
import test from 'node:test';
import {
  createIvsProvider,
  type IvsRealtimeApi,
} from '../providers/ivs.ts';
import type { MediaRole } from '../types.ts';

function fakeApi() {
  const issued: Array<{ role: MediaRole; capabilities: string[] }> = [];
  let tokenSequence = 0;
  const api: IvsRealtimeApi = {
    async createStage(name) {
      return { arn: `arn:aws:ivs:us-west-2:123456789012:stage/${name}` };
    },
    async createParticipantToken(input) {
      tokenSequence += 1;
      const capabilities =
        input.role === 'viewer'
          ? ['SUBSCRIBE']
          : ['PUBLISH', 'SUBSCRIBE'];
      issued.push({ role: input.role, capabilities });
      return {
        token: `token-${tokenSequence}`,
        participantId: `aws-participant-${tokenSequence}`,
        capabilities,
        expiresAtMs: Date.now() + 60_000,
      };
    },
    async deleteStage() {},
    async disconnectParticipant() {},
  };
  return { api, issued };
}

test('IVS roles mint server-enforced publish capabilities', async () => {
  const { api, issued } = fakeApi();
  const provider = createIvsProvider({
    env: {},
    contractVersion: 1,
    normalizeDisplayName: (value) => String(value ?? '').trim(),
    api,
  });
  const created = await provider.createRoom({
    roomCode: '123456',
    role: 'host',
  });

  const host = await provider.joinRoom({
    entry: created.entry,
    rawName: 'Host',
    userId: 'host-1',
    role: 'host',
  });
  const viewer = await provider.joinRoom({
    entry: created.entry,
    rawName: 'Viewer',
    userId: 'viewer-1',
    role: 'viewer',
  });

  assert.equal(host.participantId, 'host-1');
  assert.deepEqual(issued[0]?.capabilities, ['PUBLISH', 'SUBSCRIBE']);
  assert.equal(viewer.participantId, 'viewer-1');
  assert.deepEqual(issued[1]?.capabilities, ['SUBSCRIBE']);
});

test('IVS credential refresh cannot promote a viewer to host', async () => {
  const { api, issued } = fakeApi();
  const provider = createIvsProvider({
    env: {},
    contractVersion: 1,
    normalizeDisplayName: (value) => String(value ?? '').trim(),
    api,
  });
  const created = await provider.createRoom({
    roomCode: 'viewer-refresh',
    role: 'host',
  });
  const joined = await provider.joinRoom({
    entry: created.entry,
    rawName: 'Viewer',
    userId: 'viewer-1',
    role: 'viewer',
  });

  const refreshed = await provider.refreshCredentials?.({
    entry: created.entry,
    participantId: joined.participantId,
    role: 'host',
  });

  assert.ok(refreshed);
  assert.equal(refreshed.role, 'viewer');
  assert.deepEqual(issued.at(-1)?.capabilities, ['SUBSCRIBE']);
});

test('IVS credential refresh preserves logical participant identity', async () => {
  const { api } = fakeApi();
  const provider = createIvsProvider({
    env: {},
    contractVersion: 1,
    normalizeDisplayName: (value) => String(value ?? '').trim(),
    api,
  });
  const created = await provider.createRoom({
    roomCode: '654321',
    role: 'participant',
  });
  const joined = await provider.joinRoom({
    entry: created.entry,
    rawName: 'Alice',
    userId: 'alice-1',
    role: 'participant',
  });
  const firstAwsParticipantId = (
    joined.ivs as { tokenParticipantId: string }
  ).tokenParticipantId;

  const refreshed = await provider.refreshCredentials?.({
    entry: created.entry,
    participantId: joined.participantId,
    role: 'participant',
  });

  assert.ok(refreshed);
  assert.equal(refreshed.participantId, 'alice-1');
  assert.notEqual(
    (refreshed.ivs as { tokenParticipantId: string }).tokenParticipantId,
    firstAwsParticipantId,
  );
});
