import type { RoomAttendee, RoomEntry } from './types.ts';
import { ProviderOperationError } from './providers/provider-registry.ts';
import { requireParticipantCredential } from './participant-credential.ts';
import { matchesRoomOwnerCredential } from './room-owner-credential.ts';

export function requireRoomManager(
  entry: RoomEntry,
  requesterParticipantId: unknown,
  participantCredential: unknown,
  roomOwnerCredential: unknown,
): RoomAttendee | null {
  const requester = String(requesterParticipantId ?? '').trim();
  if (!requester) return null;
  try {
    const attendee = requireParticipantCredential(
      entry,
      requester,
      participantCredential,
    );
    if (attendee.role === 'host') return attendee;
    const ownerCredential = String(roomOwnerCredential ?? '').trim();
    return ownerCredential &&
      matchesRoomOwnerCredential(entry, ownerCredential)
      ? attendee
      : null;
  } catch (error) {
    if (
      error instanceof ProviderOperationError &&
      (error.status === 403 || error.status === 404)
    ) {
      return null;
    }
    throw error;
  }
}
