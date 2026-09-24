import assert from 'node:assert/strict';
import test from 'node:test';

import { ProviderOperationError, ProviderRegistry } from '../providers/provider-registry.ts';
import { RoomDirectory } from '../providers/room-directory.ts';
import type { ProviderAdapter, RoomEntry } from '../types.ts';

function fakeProvider(id = 'fake'): ProviderAdapter {
  return {
    id,
    displayName: 'Fake RTC',
    label: 'Fake RTC Provider',
    description: 'Test provider',
    themeKey: 'fake',
    isConfigured: () => true,
    supportsRole: () => true,
    async createRoom({ roomCode, role }) {
      const entry = {
        provider: id,
        roomCode,
        providerRoomName: `fake-${roomCode}`,
        createdAt: new Date().toISOString(),
        attendees: [],
        lastHeartbeatMs: Date.now(),
      };
      return {
        entry,
        response: { contractVersion: 1, provider: id, role, roomCode },
      };
    },
    async joinRoom({ entry, rawName, role }) {
      const participantId = `fake-${entry.attendees.length + 1}`;
      const displayName = String(rawName ?? '');
      entry.attendees.push({
        attendeeId: participantId,
        externalUserId: displayName,
        joinedAt: new Date().toISOString(),
      });
      return {
        contractVersion: 1,
        provider: id,
        role,
        roomCode: entry.roomCode,
        participantId,
        displayName,
        fake: { token: 'short-lived-token' },
      };
    },
    async closeRoom() {},
    summarizeRoom(entry, { host }) {
      return {
        provider: id,
        roomCode: entry.roomCode,
        meetingId: entry.providerRoomName,
        externalMeetingId: entry.providerRoomName,
        mediaRegion: 'Fake',
        createdAt: entry.createdAt,
        lastHeartbeat: new Date(entry.lastHeartbeatMs).toISOString(),
        idleSec: 0,
        attendeeCount: entry.attendees.length,
        attendees: entry.attendees,
        shareText: entry.roomCode,
        shareLink: `fake://join?roomCode=${entry.roomCode}&server=${host}`,
      };
    },
  };
}

test('registers a fifth provider without changing registry or room-directory code', async () => {
  const provider = fakeProvider('fifth-provider');
  const registry = new ProviderRegistry([provider]);
  const rooms = new RoomDirectory();

  const adapter = registry.requireConfigured('fifth-provider');
  const created = await adapter.createRoom({ roomCode: 'room5001', role: 'participant' });
  rooms.register(created.entry);
  const room = rooms.get('room5001');
  assert.ok(room);
  const joined = await adapter.joinRoom({
    entry: room,
    rawName: 'Developer',
    role: 'participant',
  });

  assert.equal(joined.provider, 'fifth-provider');
  assert.equal(joined.roomCode, 'room5001');
  assert.equal(rooms.entries().length, 1);
  assert.equal(registry.metadata()[0]!.displayName, 'Fake RTC');
});

test('room directory supports provider aliases and removes them with the room', () => {
  const rooms = new RoomDirectory();
  const entry: RoomEntry = {
    provider: 'fake',
    roomCode: 'room6001',
    createdAt: new Date().toISOString(),
    attendees: [],
    lastHeartbeatMs: Date.now(),
  };
  rooms.register(entry, ['provider-native-id']);

  assert.equal(rooms.get('room6001'), entry);
  assert.equal(rooms.get('provider-native-id'), entry);
  assert.equal(rooms.remove(entry), true);
  assert.equal(rooms.get('provider-native-id'), null);
});

test('registry rejects unknown, unconfigured, and unsafe provider ids', () => {
  const registry = new ProviderRegistry([
    fakeProvider('ready'),
    { ...fakeProvider('offline'), isConfigured: () => false, configurationError: 'offline config missing' },
  ]);

  assert.throws(
    () => registry.require('missing'),
    (error) => error instanceof ProviderOperationError && error.code === 'unsupported-provider',
  );
  assert.throws(
    () => registry.requireConfigured('offline'),
    (error) =>
      error instanceof ProviderOperationError &&
      error.code === 'provider-not-configured' &&
      error.message === 'offline config missing',
  );
  assert.throws(() => new ProviderRegistry([fakeProvider('bad id!')]), /unsupported characters/);
});
