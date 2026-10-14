import type { RoomAttendee } from '../types.ts';
import { ProviderOperationError } from '../providers/provider-registry.ts';

export function normalizeAvatarUrl(value: unknown): string | undefined {
  if (value == null || value === '') return undefined;
  if (typeof value !== 'string') throw new ProviderOperationError(400, 'invalid-argument', 'avatarUrl must be an HTTP(S) image URL.');
  const text = value.trim();
  if (!text) return undefined;
  try {
    const url = new URL(text);
    if (text.length <= 2048 && ['http:', 'https:'].includes(url.protocol) && url.hostname && !url.username && !url.password) return text;
  } catch { /* Invalid references are rejected before provisioning. */ }
  throw new ProviderOperationError(400, 'invalid-argument', 'avatarUrl must be an HTTP(S) image URL.');
}

export function publicParticipantProfiles(entry: { attendees: RoomAttendee[] }) {
  return entry.attendees.map(person => ({ participantId: person.attendeeId,
    displayName: person.displayName ?? person.externalUserId,
    ...(person.avatarUrl ? {avatarUrl: person.avatarUrl} : {}),
  }));
}
