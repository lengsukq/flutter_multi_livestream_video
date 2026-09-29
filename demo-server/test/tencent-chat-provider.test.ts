import assert from 'node:assert/strict';
import test from 'node:test';
import type { MediaRole, RoomAttendee, RoomEntry } from '../types.ts';
import {
  createTencentChatProvider,
  normalizeTencentChatTokenTtl,
  tencentChatProviderUserId,
  type TencentChatApi,
} from '../chat/tencent-chat.ts';

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
    provider: 'livekit',
    chatProvider: 'tencent-chat',
    chatRoomArn: 'rm_123456',
    roomCode: '123456',
    createdAt: new Date().toISOString(),
    attendees: [],
    lastHeartbeatMs: Date.now(),
  };
}

function fakeApi() {
  const created: string[] = [];
  const imported: Array<{ userId: string; displayName: string }> = [];
  const deleted: string[] = [];
  const removed: Array<{ groupId: string; userId: string }> = [];
  const api: TencentChatApi = {
    async createGroup(name) {
      created.push(name);
      return `tencent-group-${created.length}`;
    },
    async listGroups() {
      return [
        {
          providerRoomId: 'tencent-group-1',
          name: 'Realtime room 654321',
          type: 'Meeting',
          memberCount: 2,
          inferredRoomCode: '654321',
        },
      ];
    },
    async importAccount(userId, displayName) {
      imported.push({ userId, displayName });
    },
    async deleteGroup(groupId) {
      deleted.push(groupId);
    },
    async removeGroupMember(groupId, userId) {
      removed.push({ groupId, userId });
    },
    buildUserSig(userId, ttlSeconds) {
      return `sig:${userId}:${ttlSeconds}`;
    },
  };
  return { api, created, imported, deleted, removed };
}

test('Tencent Chat room lifecycle stays independent from media provider', async () => {
  const fake = fakeApi();
  const provider = createTencentChatProvider({
    env: { TENCENT_CHAT_SDK_APP_ID: '1400000001' },
    contractVersion: 1,
    api: fake.api,
  });
  const binding = await provider.createRoom('654321');
  assert.equal(binding.chatProvider, 'tencent-chat');
  assert.equal(binding.chatRoomArn, 'tencent-group-1');
  assert.deepEqual(fake.created, ['Realtime room 654321']);
  assert.deepEqual(await provider.listCloudRooms?.(), [
    {
      providerRoomId: 'tencent-group-1',
      name: 'Realtime room 654321',
      type: 'Meeting',
      memberCount: 2,
      inferredRoomCode: '654321',
    },
  ]);

  const entry = room();
  await provider.closeRoom(entry);
  assert.deepEqual(fake.deleted, [entry.chatRoomArn]);
  await provider.deleteCloudRoom?.('tencent-group-1');
  assert.deepEqual(fake.deleted, [entry.chatRoomArn, 'tencent-group-1']);
  await provider.removeMember?.(entry, attendee('viewer'));
  assert.deepEqual(fake.removed, [
    {
      groupId: entry.chatRoomArn,
      userId: tencentChatProviderUserId('viewer-logical-user'),
    },
  ]);
});

test('Tencent Chat credentials use server-authoritative logical identity', async () => {
  const fake = fakeApi();
  const provider = createTencentChatProvider({
    env: {
      TENCENT_CHAT_SDK_APP_ID: '1400000001',
      TENCENT_CHAT_TOKEN_TTL_SECONDS: '600',
    },
    contractVersion: 1,
    api: fake.api,
  });
  const entry = room();
  const issued = await provider.issueToken({ entry, attendee: attendee('host') });

  assert.equal(issued.role, 'host');
  assert.equal(issued.chat.sdkAppId, 1400000001);
  assert.equal(issued.chat.groupId, entry.chatRoomArn);
  assert.deepEqual(issued.chat.capabilities, ['SEND_MESSAGE']);
  const providerUserId = tencentChatProviderUserId('host-logical-user');
  assert.equal(issued.chat.providerUserId, providerUserId);
  assert.equal(issued.chat.userSig, `sig:${providerUserId}:600`);
  assert.deepEqual(fake.imported, [
    { userId: providerUserId, displayName: 'host display' },
  ]);
});

test('Tencent provider user ids and token TTL are bounded', () => {
  assert.match(tencentChatProviderUserId('Anything@Unicode-用户'), /^u_[a-f0-9]{28}$/);
  assert.equal(normalizeTencentChatTokenTtl(undefined), 3600);
  assert.equal(normalizeTencentChatTokenTtl(1), 60);
  assert.equal(normalizeTencentChatTokenTtl(99_999_999), 604800);
});
