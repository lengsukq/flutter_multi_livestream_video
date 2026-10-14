import assert from 'node:assert/strict';
import { test } from 'node:test';

import { ChatProviderRegistry } from '../chat/chat-provider-registry.ts';
import { ProviderRegistry } from '../providers/provider-registry.ts';
import { RoomDirectory } from '../providers/room-directory.ts';
import { createRoomClosure } from '../services/room-closure.ts';
import type { ChatProviderAdapter, ProviderAdapter, RoomEntry } from '../types.ts';

test('partial closure retries only failing provider and retains room until fully closed', async () => {
  let chatCalls = 0;
  let mediaCalls = 0;
  let failMedia = true;
  const chat = {
    id: 'chat', isConfigured: () => true,
    closeRoom: async () => { chatCalls++; },
  } as unknown as ChatProviderAdapter;
  const media = {
    id: 'media', isConfigured: () => true,
    closeRoom: async () => {
      mediaCalls++;
      if (failMedia) throw new Error('media close interrupted');
    },
  } as unknown as ProviderAdapter;
  const providerRegistry = new ProviderRegistry([media]);
  const chatProviderRegistry = new ChatProviderRegistry([chat]);
  const roomDirectory = new RoomDirectory();
  const entry = {
    roomCode: '789123', provider: 'media', chatProvider: 'chat',
    attendees: [], createdAt: new Date().toISOString(),
    lastHeartbeatMs: Date.now(),
  } as unknown as RoomEntry;
  roomDirectory.register(entry);
  const forgotten: string[] = [];
  const logs: string[] = [];
  const close = createRoomClosure({
    providerRegistry, chatProviderRegistry, roomDirectory,
    classroomDirectory: { forget: () => forgotten.push('classroom') } as never,
    liveInteractionDirectory: { forget: () => forgotten.push('live') } as never,
    logEvent: (kind) => logs.push(kind),
  });

  await assert.rejects(close(entry, 'leave'), /media close interrupted/);
  assert.equal(entry.closePending, true);
  assert.equal(entry.chatClosed, true);
  assert.equal(entry.mediaClosed, undefined);
  assert.equal(roomDirectory.get(entry.roomCode), entry);
  assert.deepEqual(forgotten, []);
  assert.deepEqual([chatCalls, mediaCalls], [1, 1]);

  failMedia = false;
  await close(entry, 'retry');
  assert.deepEqual([chatCalls, mediaCalls], [1, 2]);
  assert.equal(entry.mediaClosed, true);
  assert.equal(roomDirectory.get(entry.roomCode), null);
  assert.deepEqual(forgotten, ['classroom', 'live']);
  assert.deepEqual(logs, ['error', 'delete']);
});

test('a live room is not deleted until its active cloud recorder stops', async () => {
  const operations: string[] = [];
  let failStop = true;
  const provider = {
    id: 'agora', isConfigured: () => true,
    closeRoom: async () => { operations.push('media'); },
  } as unknown as ProviderAdapter;
  const providerRegistry = new ProviderRegistry([provider]);
  const roomDirectory = new RoomDirectory();
  const entry = {
    provider: 'agora', roomCode: '123456',
    attendees: [], createdAt: new Date().toISOString(),
    lastHeartbeatMs: Date.now(),
  } as unknown as RoomEntry;
  roomDirectory.register(entry);
  const close = createRoomClosure({
    providerRegistry,
    chatProviderRegistry: new ChatProviderRegistry([]),
    roomDirectory,
    classroomDirectory: {forget: () => operations.push('classroom')} as never,
    liveInteractionDirectory: {forget: () => operations.push('live')} as never,
    stopActiveRecording: async () => {
      operations.push('recording-stop');
      if (failStop) throw Error('Agora Stop HTTP 502');
    },
    logEvent: () => {},
  });

  await assert.rejects(close(entry, 'host ended live'), /Agora Stop HTTP 502/);
  assert.equal(roomDirectory.get(entry.roomCode), entry);
  assert.equal(entry.closePending, undefined);
  assert.deepEqual(operations, ['recording-stop']);

  failStop = false;
  await close(entry, 'retry ending live');
  assert.equal(roomDirectory.get(entry.roomCode), null);
  assert.deepEqual(operations, [
    'recording-stop', 'recording-stop', 'media', 'classroom', 'live',
  ]);
});
