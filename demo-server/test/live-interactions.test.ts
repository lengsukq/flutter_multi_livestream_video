import assert from 'node:assert/strict';
import test from 'node:test';
import { LiveInteractionDirectory } from '../live/live-interactions.ts';
import type { RoomEntry } from '../types.ts';
const fixture = () => {
  const entry: RoomEntry = { provider: 'ivs', roomCode: 'live123', roomMode: 'broadcast',
    createdAt: new Date().toISOString(), lastHeartbeatMs: Date.now(), attendees: [
      { attendeeId: 'host1', userId: 'host', externalUserId: 'host', role: 'host', joinedAt: new Date().toISOString() },
      { attendeeId: 'v1', userId: 'alice', externalUserId: 'alice', role: 'viewer', joinedAt: new Date().toISOString() },
      { attendeeId: 'v2', userId: 'bob', externalUserId: 'bob', role: 'viewer', joinedAt: new Date().toISOString() },
    ] };
  return { entry, directory: new LiveInteractionDirectory() };
};
test('gifts work independently of chat, with authority, replay protection and shared totals', () => {
  const { entry, directory } = fixture();
  const alice = entry.attendees[1]!, bob = entry.attendees[2]!;
  const request = { giftId: 'star', quantity: 5, eventId: 'gift-event-001' };
  const first = directory.send(entry, alice, request);
  assert.equal(first.totals.star, 5);
  assert.equal(first.events[0]?.recipientId, 'host');
  assert.equal(directory.send(entry, alice, request).revision, first.revision);
  assert.throws(() => directory.send(entry, alice, { ...request, quantity: 6 }), /Reused eventId/);
  directory.send(entry, bob, { giftId: 'flower', quantity: 2, eventId: 'gift-event-002' });
  const joined = directory.snapshot(entry, bob);
  assert.deepEqual(joined.totals, { star: 5, flower: 2 });
  assert.equal(joined.events.length, 2);
  assert.equal(first.events.length, 1);
});
test('invalid, excessive and offline-host gifts fail without incrementing totals', () => {
  const { entry, directory } = fixture();
  const alice = entry.attendees[1]!;
  for (const quantity of [0, -1, 100, 1.5, '1']) assert.throws(() => directory.send(entry, alice,
    { giftId: 'star', quantity, eventId: 'bad-gift-001' }), /quantity/);
  assert.throws(() => directory.send(entry, alice, { giftId: 'money', quantity: 1, eventId: 'bad-gift-001' }), /Unknown gift/);
  for (let i = 0; i < 5; i++) directory.send(entry, alice, { giftId: 'star', quantity: 1, eventId: `gift-event-00${i}` });
  assert.throws(() => directory.send(entry, alice, { giftId: 'star', quantity: 1, eventId: 'gift-event-006' }), /wait/);
  assert.equal(directory.snapshot(entry, alice).totals.star, 5);
  entry.attendees.shift();
  assert.equal(directory.snapshot(entry, alice).canSendGift, false);
  assert.throws(() => directory.send(entry, alice, { giftId: 'star', quantity: 1, eventId: 'gift-event-007' }), /offline/);
  assert.throws(() => directory.snapshot({ ...entry, roomMode: 'meeting' }, alice), /broadcast/);
});
