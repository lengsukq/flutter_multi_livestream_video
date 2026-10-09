import crypto from 'node:crypto';
import type { MediaRole, RoomEntry, RoomMode } from '../types.ts';
import { matchesRoomOwnerCredential } from '../room-owner-credential.ts';
import { ProviderOperationError } from '../providers/provider-registry.ts';

/** Canonical room identity/roles; shared by all HTTP room routers. */
export function normalizeRoomCode(raw: unknown): string | null {
  if (raw == null) return null;
  const code = String(raw).trim();
  return /^[A-Za-z0-9]{4,12}$/.test(code) ? code : null;
}

export function normalizeUserId(raw: unknown): string {
  const id = String(raw ?? '').trim() || `user-${crypto.randomUUID().slice(0, 8)}`;
  if (/^[-_&@+=,(){}\[\]\/«.:\s'"#a-zA-Z0-9À-ÿ]*$/.test(id) && id.length <= 64) return id;
  const ascii = id
    .replace(/[^\x20-\x7E]/g, '')
    .replace(/[^A-Za-z0-9\-_=@,. ]/g, '')
    .trim()
    .slice(0, 48);
  return ascii || `user-${crypto.randomUUID().slice(0, 8)}`;
}

export function normalizeDisplayName(raw: unknown): string {
  return String(raw ?? '').trim().slice(0, 64);
}

export function normalizeDeviceId(raw: unknown): string | null {
  if (raw == null) return null;
  const value = String(raw).trim();
  if (!value) return null;
  return /^[A-Za-z0-9._:-]{8,128}$/.test(value) ? value : null;
}

export function bindDevicePresence(
  entry: RoomEntry,
  participantId: string,
  deviceId: string | null,
): void {
  if (!deviceId) return;
  const current = entry.attendees.find(
    (attendee) => attendee.attendeeId === participantId,
  );
  if (!current) return;
  current.deviceId = deviceId;
  current.lastHeartbeatMs = Date.now();
  entry.attendees = entry.attendees.filter(
    (attendee) =>
      attendee.attendeeId === participantId || attendee.deviceId !== deviceId,
  );
}

export function parseRole(raw: unknown): MediaRole | null {
  const role = String(raw ?? 'participant').trim().toLowerCase();
  if (role === 'participant' || role === 'host' || role === 'viewer') return role;
  return null;
}

export function parseRoomMode(raw: unknown): RoomMode | null {
  if (raw == null || String(raw).trim() === '') return null;
  const mode = String(raw).trim().toLowerCase();
  return mode === 'meeting' || mode === 'broadcast' ? mode : null;
}

export function creatorRoleForMode(mode: RoomMode): MediaRole {
  return mode === 'broadcast' ? 'host' : 'participant';
}

export function joinRoleForRoom(
  entry: RoomEntry,
  roomOwnerCredential: unknown,
): MediaRole {
  const credential = String(roomOwnerCredential ?? '').trim();
  if (entry.roomMode !== 'broadcast') {
    if (credential && !matchesRoomOwnerCredential(entry, credential)) {
      throw new ProviderOperationError(
        403,
        'forbidden',
        'The room owner credential is invalid.',
      );
    }
    return 'participant';
  }
  if (!credential) return 'viewer';
  if (!matchesRoomOwnerCredential(entry, credential)) {
    throw new ProviderOperationError(
      403,
      'forbidden',
      'The room owner credential is invalid.',
    );
  }
  return 'host';
}

