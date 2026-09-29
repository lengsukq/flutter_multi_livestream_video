import assert from 'node:assert/strict';
import test from 'node:test';
import type { MediaRole, RoomAttendee, RoomEntry } from '../types.ts';
import {
  agoraChatProviderUserId,
  createAgoraChatProvider,
  normalizeAgoraChatTokenTtl,
  type AgoraChatApi,
} from '../chat/agora-chat.ts';

function attendee(role: MediaRole): RoomAttendee {
  return {
    attendeeId: `${role}-participant`,
    externalUserId: `${role} display`,
    userId: `${role}-logical-user`,
    displayName: `${role} display`,
    joinedAt: new Date().toISOString(),
    role,
  };
}

function room(): RoomEntry {
  return {
    provider: 'chime',
    chatProvider: 'agora-chat',
    chatRoomArn: 'agora-room-123',
    roomCode: '123456',
    createdAt: new Date().toISOString(),
    attendees: [],
    lastHeartbeatMs: Date.now(),
  };
}

function fakeApi() {
  const users: string[] = [];
  const deleted: string[] = [];
  const removed: Array<{ roomId: string; username: string }> = [];
  const api: AgoraChatApi = {
    async createRoom(name) {
      return `room:${name}`;
    },
    async ensureUser(username) {
      users.push(username);
      return `uuid:${username}`;
    },
    async deleteRoom(roomId) {
      deleted.push(roomId);
    },
    async removeMember(roomId, username) {
      removed.push({ roomId, username });
    },
    buildUserToken(userUuid, ttlSeconds) {
      return `token:${userUuid}:${ttlSeconds}`;
    },
  };
  return { api, users, deleted, removed };
}

test('Agora Chat room lifecycle stays independent from media provider', async () => {
  const fake = fakeApi();
  const provider = createAgoraChatProvider({
    env: { AGORA_CHAT_APP_KEY: 'org#app' },
    contractVersion: 1,
    api: fake.api,
  });
  const binding = await provider.createRoom('654321');
  assert.equal(binding.chatProvider, 'agora-chat');
  assert.equal(binding.chatRoomArn, 'room:Realtime room 654321');

  const entry = room();
  await provider.closeRoom(entry);
  assert.deepEqual(fake.deleted, [entry.chatRoomArn]);
  await provider.removeMember?.(entry, attendee('viewer'));
  assert.deepEqual(fake.removed, [
    {
      roomId: entry.chatRoomArn,
      username: agoraChatProviderUserId('viewer-logical-user'),
    },
  ]);
});

test('Agora Chat credentials use registered Chat UUID for token minting', async () => {
  const fake = fakeApi();
  const provider = createAgoraChatProvider({
    env: {
      AGORA_CHAT_APP_KEY: 'org#app',
      AGORA_CHAT_TOKEN_TTL_SECONDS: '900',
    },
    contractVersion: 1,
    api: fake.api,
  });
  const entry = room();
  const issued = await provider.issueToken({ entry, attendee: attendee('viewer') });
  const providerUserId = agoraChatProviderUserId('viewer-logical-user');

  assert.equal(issued.chat.appKey, 'org#app');
  assert.equal(issued.chat.providerUserId, providerUserId);
  assert.equal(issued.chat.chatRoomId, entry.chatRoomArn);
  assert.equal(
    issued.chat.token,
    `token:uuid:${providerUserId}:900`,
  );
  assert.deepEqual(issued.chat.capabilities, ['SEND_MESSAGE']);
  assert.deepEqual(fake.users, [providerUserId]);
});

test('Agora provider user ids and token TTL obey service constraints', () => {
  assert.match(agoraChatProviderUserId('Some User 用户'), /^u_[a-f0-9]{40}$/);
  assert.equal(normalizeAgoraChatTokenTtl(undefined), 3600);
  assert.equal(normalizeAgoraChatTokenTtl(1), 60);
  assert.equal(normalizeAgoraChatTokenTtl(999_999), 86400);
});
