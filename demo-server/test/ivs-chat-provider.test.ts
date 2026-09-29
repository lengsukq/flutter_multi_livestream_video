import assert from 'node:assert/strict';
import test from 'node:test';
import type { MediaRole, RoomAttendee, RoomEntry } from '../types.ts';
import {
  createIvsChatProvider,
  ivsChatCapabilitiesForRole,
  normalizeIvsChatTokenDurationMinutes,
  type IvsChatApi,
} from '../chat/ivs-chat.ts';

function attendee(role: MediaRole): RoomAttendee {
  return {
    attendeeId: `${role}-participant`,
    externalUserId: `${role} user`,
    userId: `${role}-user`,
    displayName: `${role} user`,
    joinedAt: new Date().toISOString(),
    role,
  };
}

function room(): RoomEntry {
  return {
    provider: 'livekit',
    chatProvider: 'ivs-chat',
    chatRoomArn: 'arn:aws:ivschat:us-west-2:123456789012:room/abc123',
    roomCode: '123456',
    createdAt: new Date().toISOString(),
    attendees: [],
    lastHeartbeatMs: Date.now(),
  };
}

function fakeApi() {
  const tokenInputs: Array<{
    role: MediaRole;
    capabilities: string[];
    userId: string;
  }> = [];
  let deletedArn: string | null = null;
  const disconnected: Array<{ roomArn: string; userId: string }> = [];
  const api: IvsChatApi = {
    async createRoom(name) {
      return {
        arn: `arn:aws:ivschat:us-west-2:123456789012:room/${name}`,
      };
    },
    async createToken(input) {
      const capabilities = ivsChatCapabilitiesForRole(input.role);
      tokenInputs.push({
        role: input.role,
        capabilities: [...capabilities],
        userId: input.userId,
      });
      return {
        token: `chat-token-${tokenInputs.length}`,
        capabilities,
        tokenExpirationTimeMs: Date.now() + 60_000,
        sessionExpirationTimeMs: Date.now() + 3_600_000,
      };
    },
    async deleteRoom(roomArn) {
      deletedArn = roomArn;
    },
    async disconnectUser(roomArn, userId) {
      disconnected.push({ roomArn, userId });
    },
  };
  return {
    api,
    tokenInputs,
    deletedArn: () => deletedArn,
    disconnected,
  };
}

test('IVS Chat role capabilities are server-controlled', async () => {
  const fake = fakeApi();
  const provider = createIvsChatProvider({
    env: {},
    contractVersion: 1,
    api: fake.api,
  });
  const entry = room();

  const viewer = await provider.issueToken({
    entry,
    attendee: attendee('viewer'),
  });
  const host = await provider.issueToken({
    entry,
    attendee: attendee('host'),
  });

  assert.equal(viewer.role, 'viewer');
  assert.deepEqual(
    (viewer.chat.capabilities as string[]),
    ['SEND_MESSAGE'],
  );
  assert.equal(host.role, 'host');
  assert.deepEqual(
    (host.chat.capabilities as string[]).sort(),
    ['DELETE_MESSAGE', 'DISCONNECT_USER', 'SEND_MESSAGE'].sort(),
  );
  assert.equal(fake.tokenInputs[0]?.userId, 'viewer-user');
  assert.equal(fake.tokenInputs[1]?.userId, 'host-user');
});

test('IVS Chat room lifecycle is independent from the media provider', async () => {
  const fake = fakeApi();
  const provider = createIvsChatProvider({
    env: {},
    contractVersion: 1,
    api: fake.api,
  });

  const binding = await provider.createRoom('654321');
  assert.equal(binding.chatProvider, 'ivs-chat');
  assert.match(binding.chatRoomArn, /chat-654321$/);

  const entry = room();
  await provider.closeRoom(entry);
  assert.equal(fake.deletedArn(), entry.chatRoomArn);
  await provider.removeMember?.(entry, attendee('viewer'));
  assert.deepEqual(fake.disconnected, [
    { roomArn: entry.chatRoomArn, userId: 'viewer-user' },
  ]);
});

test('IVS Chat token duration is clamped to the AWS 1-180 minute range', () => {
  assert.equal(normalizeIvsChatTokenDurationMinutes(undefined), 60);
  assert.equal(normalizeIvsChatTokenDurationMinutes(0), 1);
  assert.equal(normalizeIvsChatTokenDurationMinutes(999), 180);
  assert.equal(normalizeIvsChatTokenDurationMinutes('45'), 45);
});
