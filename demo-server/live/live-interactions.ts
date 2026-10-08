import crypto from 'node:crypto';
import type { RoomEntry, RoomAttendee } from '../types.ts';
import { ProviderOperationError } from '../providers/provider-registry.ts';

export const demoGiftCatalog = Object.freeze([
  { id: 'applause', name: 'Applause', icon: 'applause' },
  { id: 'flower', name: 'Flower', icon: 'flower' },
  { id: 'star', name: 'Star', icon: 'star' },
]);
type GiftEvent = { id: string; sequence: number; userId: string; displayName: string;
  recipientId: string; giftId: string; quantity: number; timestamp: string };
type State = { revision: number; events: GiftEvent[]; totals: Map<string, number>;
  handled: Map<string, string>; recent: Map<string, number[]> };
const fail = (message: string, code = 'invalid-argument', status = 400): never => {
  throw new ProviderOperationError(status, code, message);
};

/** Transient reference control plane, not a payment or wallet service. */
export class LiveInteractionDirectory {
  private readonly rooms = new WeakMap<RoomEntry, State>();
  private get(entry: RoomEntry): State {
    if (entry.roomMode !== 'broadcast') fail('Live interactions require a broadcast room', 'unsupported-feature');
    let state = this.rooms.get(entry);
    if (!state) { state = { revision: 0, events: [], totals: new Map(), handled: new Map(), recent: new Map() }; this.rooms.set(entry, state); }
    return state;
  }
  snapshot(entry: RoomEntry, requester: RoomAttendee) {
    const state = this.get(entry);
    const host = entry.attendees.find(person => person.role === 'host');
    return { contractVersion: 1, roomCode: entry.roomCode, revision: state.revision,
      selfUserId: requester.userId ?? requester.externalUserId,
      recipientId: host?.userId ?? host?.externalUserId ?? '', canSendGift: Boolean(host),
      catalog: demoGiftCatalog.map(item => ({ ...item })),
      events: state.events.map(event => ({ ...event })), totals: Object.fromEntries(state.totals),
    };
  }
  send(entry: RoomEntry, requester: RoomAttendee, raw: Record<string, unknown>) {
    const state = this.get(entry);
    const userId = requester.userId ?? requester.externalUserId;
    const giftId = String(raw.giftId ?? '');
    const quantity = raw.quantity;
    const eventId = String(raw.eventId ?? '');
    if (!/^[a-zA-Z0-9_-]{8,128}$/.test(eventId)) fail('eventId is required');
    if (!demoGiftCatalog.some(gift => gift.id === giftId)) fail('Unknown gift');
    if (!Number.isSafeInteger(quantity) || (quantity as number) < 1 || (quantity as number) > 99) fail('Gift quantity must be 1-99');
    const fingerprint = JSON.stringify([userId, giftId, quantity]);
    const previous = state.handled.get(eventId);
    if (previous && previous !== fingerprint) fail('Reused eventId with different payload', 'idempotency-conflict', 409);
    if (previous) return this.snapshot(entry, requester);
    const host = entry.attendees.find(person => person.role === 'host');
    if (!host) fail('The host is offline', 'invalid-state', 409);
    const now = Date.now();
    const recent = (state.recent.get(userId) ?? []).filter(time => now - time < 10000);
    if (recent.length >= 5) fail('Please wait before sending more gifts', 'rate-limited', 429);
    recent.push(now); state.recent.set(userId, recent);
    state.revision++;
    state.events.push({ id: crypto.randomUUID(), sequence: state.revision,
      userId, displayName: requester.displayName ?? userId,
      recipientId: host!.userId ?? host!.externalUserId, giftId, quantity: quantity as number, timestamp: new Date(now).toISOString() });
    if (state.events.length > 100) state.events.shift();
    state.totals.set(giftId, (state.totals.get(giftId) ?? 0) + (quantity as number));
    state.handled.set(eventId, fingerprint);
    if (state.handled.size > 1000) state.handled.delete(state.handled.keys().next().value!);
    return this.snapshot(entry, requester);
  }
  forget(entry: RoomEntry): void { this.rooms.delete(entry); }
}
