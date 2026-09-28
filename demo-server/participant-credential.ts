import crypto from 'node:crypto';

import { ProviderOperationError } from './providers/provider-registry.ts';
import type { RoomAttendee, RoomEntry } from './types.ts';

function hashParticipantCredential(value: string): string {
  return crypto.createHash('sha256').update(value).digest('hex');
}

export function issueParticipantCredential(
  entry: RoomEntry,
  participantId: string,
): string {
  const attendee = entry.attendees.find(
    (item) => item.attendeeId === participantId,
  );
  if (!attendee) {
    throw new ProviderOperationError(
      404,
      'participant-not-found',
      'The participant is no longer registered in this room.',
    );
  }
  const credential = crypto.randomBytes(32).toString('base64url');
  attendee.participantCredentialHash = hashParticipantCredential(credential);
  return credential;
}

export function requireParticipantCredential(
  entry: RoomEntry,
  participantId: string,
  rawCredential: unknown,
): RoomAttendee {
  const attendee = entry.attendees.find(
    (item) => item.attendeeId === participantId,
  );
  if (!attendee) {
    throw new ProviderOperationError(
      404,
      'participant-not-found',
      'The participant is no longer registered in this room.',
    );
  }
  const credential = String(rawCredential ?? '').trim();
  const expected = attendee.participantCredentialHash;
  if (!credential || !expected) {
    throw new ProviderOperationError(
      403,
      'forbidden',
      'A valid participant credential is required.',
    );
  }
  const actualBuffer = Buffer.from(hashParticipantCredential(credential), 'hex');
  const expectedBuffer = Buffer.from(expected, 'hex');
  if (
    actualBuffer.length !== expectedBuffer.length ||
    !crypto.timingSafeEqual(actualBuffer, expectedBuffer)
  ) {
    throw new ProviderOperationError(
      403,
      'forbidden',
      'The participant credential does not match this participant.',
    );
  }
  return attendee;
}
