import assert from 'node:assert/strict';
import test from 'node:test';
import { RoomDirectory } from '../providers/room-directory.ts';
import { ProviderOperationError } from '../providers/provider-registry.ts';
import { postRooms } from '../services/room/post-rooms.ts';
import type { RoomApplicationDependencies } from '../services/room/dependencies.ts';
import type { ApplicationInput } from '../services/application-protocol.ts';
import type { ProviderAdapter, RoomEntry } from '../types.ts';

test('failed initial creator join rolls back the reserved room code for retry', async () => {
  const roomDirectory = new RoomDirectory();
  let joins = 0;
  let closes = 0;
  const provider = {
    id: 'fake', displayName: 'Fake',
    async createRoom({roomCode}: {roomCode: string}) {
      return {
        entry: {
          provider: 'fake', roomCode, roomMode: 'meeting',
          createdAt: new Date().toISOString(),
          attendees: [], lastHeartbeatMs: Date.now(),
        } as RoomEntry,
        response: {contractVersion: 1, provider: 'fake', roomCode, role: 'participant' as const},
      };
    },
    async joinRoom({entry}: {entry: RoomEntry}) {
      joins++;
      if (joins === 1) throw new Error('simulated provider join failure');
      entry.attendees.push({
        attendeeId: 'creator-1', externalUserId: 'creator',
        joinedAt: new Date().toISOString(), lastHeartbeatMs: Date.now(),
      });
      return {
        contractVersion: 1, provider: 'fake', roomCode: entry.roomCode,
        role: 'participant' as const, participantId: 'creator-1', displayName: 'Creator',
      };
    },
    async closeRoom() { closes++; },
  } as unknown as ProviderAdapter;
  const dependencies = {
    roomDirectory,
    currentProvider: () => 'fake', currentChatProvider: () => null,
    chatProviderRegistry: {}, classroomDirectory: {snapshot: () => null},
    withRoomOperation: async (_entry: RoomEntry, action: () => Promise<unknown>) => action(),
    assertRoomOpen: () => {},
    bindLogicalIdentity: () => {},
    normalizeRoomCode: (raw: unknown) => typeof raw === 'string' ? raw : null,
    normalizeDeviceId: () => null,
    normalizeUserId: (raw: unknown) => String(raw),
    parseRole: () => null, parseRoomMode: () => 'meeting',
    creatorRoleForMode: () => 'participant',
    generateRoomCode: () => 'fixedroom',
    engineProviderForSelection: () => provider,
    publicProviderId: (name: string) => name,
    exposeVendorResponse: (response: unknown) => response,
    registerRoom: (_provider: ProviderAdapter, entry: RoomEntry) => roomDirectory.register(entry),
    assertRole: () => {},
    closeRoomUnlocked: async (entry: RoomEntry) => { await provider.closeRoom({entry, reason: 'rollback'}); roomDirectory.remove(entry); },
    mediaManagementCapabilities: () => ({}),
    logEvent: () => {},
  } as unknown as RoomApplicationDependencies;
  const request: ApplicationInput = {
    params: {}, query: {}, body: {roomCode: 'fixedroom', roomMode: 'meeting', displayName: 'Creator', avatarUrl: 'https://avatar.test/creator.png'},
  };
  await assert.rejects(postRooms(request, dependencies),
    (error: unknown) => error instanceof ProviderOperationError && error.status === 500);
  assert.equal(closes, 1);
  assert.equal(roomDirectory.has('fixedroom'), false);
  const retry = await postRooms(request, dependencies);
  assert.equal(retry.status, 200);
  assert.equal(roomDirectory.has('fixedroom'), true);
  assert.equal(joins, 2);
  assert.equal(roomDirectory.get('fixedroom')?.attendees[0]?.avatarUrl, 'https://avatar.test/creator.png');
});
