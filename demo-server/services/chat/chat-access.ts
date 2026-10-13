import type { ChatRoomEntry, RoomAttendee } from '../../types.ts';
import { ProviderOperationError } from '../../providers/provider-registry.ts';
import { requireParticipantCredential } from '../../participant-credential.ts';
export function requireStandaloneChatHost(entry: ChatRoomEntry, body: Record<string, unknown>): RoomAttendee {
  const participantId = String(body.requesterParticipantId ?? '').trim();
  const attendee = requireParticipantCredential(
    entry,
    participantId,
    body.participantCredential,
  );
  if (attendee.role !== 'host') {
    throw new ProviderOperationError(403, 'forbidden', 'Chat management requires the host role.');
  }
  return attendee;
}

export function chatMemberPayload(item: RoomAttendee) {
  return {
    userId: item.userId ?? item.externalUserId,
    displayName: item.displayName ?? item.externalUserId,
    role: item.role ?? 'participant',
  };
}

export function findChatMemberByUserId(
  entry: ChatRoomEntry,
  userId: unknown,
): RoomAttendee | null {
  const target = String(userId ?? '').trim();
  if (!target) return null;
  return (
    entry.attendees.find(
      (item) => (item.userId ?? item.externalUserId) === target,
    ) ?? null
  );
}