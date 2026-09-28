import crypto from 'node:crypto';

import type { RoomEntry } from './types.ts';

function hashRoomOwnerCredential(value: string): string {
  return crypto.createHash('sha256').update(value).digest('hex');
}

export function issueRoomOwnerCredential(entry: RoomEntry): string {
  const credential = crypto.randomBytes(32).toString('base64url');
  entry.roomOwnerCredentialHash = hashRoomOwnerCredential(credential);
  return credential;
}

export function matchesRoomOwnerCredential(
  entry: RoomEntry,
  rawCredential: unknown,
): boolean {
  const credential = String(rawCredential ?? '').trim();
  const expected = entry.roomOwnerCredentialHash;
  if (!credential || !expected) return false;

  const actualBuffer = Buffer.from(hashRoomOwnerCredential(credential), 'hex');
  const expectedBuffer = Buffer.from(expected, 'hex');
  return (
    actualBuffer.length === expectedBuffer.length &&
    crypto.timingSafeEqual(actualBuffer, expectedBuffer)
  );
}
