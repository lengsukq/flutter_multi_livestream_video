import type { ProviderAdapter, ChatProviderAdapter, RoomEntry, RoomAttendee, MediaRole, RoomMode } from '../../types.ts';
import type { ProviderRegistry } from '../../providers/provider-registry.ts';
import type { RoomDirectory } from '../../providers/room-directory.ts';
import type { ChatProviderRegistry } from '../../chat/chat-provider-registry.ts';
import type { ChatRoomDirectory } from '../../chat/chat-room-directory.ts';
import type { ClassroomStateDirectory } from '../../classroom/classroom-state.ts';
import { requireParticipantCredential, issueParticipantCredential } from '../../participant-credential.ts';
import { matchesRoomOwnerCredential } from '../../room-owner-credential.ts';
import { ProviderOperationError } from '../../providers/provider-registry.ts';
import { requireRoomManager } from '../../room-access.ts';
import { createRoomProvisioner } from '../../services/room-creation.ts';

import type { RoomApplicationDependencies } from './dependencies.ts';
import { fail, reply, replyStatus, type ApplicationInput, type ApplicationReply } from '../application-protocol.ts';

export async function postRoomsByCodeHeartbeat(input: ApplicationInput, dependencies: Pick<RoomApplicationDependencies, 'contractVersion' | 'resolveRoom'>): Promise<ApplicationReply> {
const { contractVersion, resolveRoom } = dependencies;


  const entry = await resolveRoom(input.params.code);
  if (!entry) return fail( 404, 'room-not-found', 'The requested room was not found.');
  const participantId = String(input.body?.participantId ?? '').trim();
  if (participantId) {
    const attendee = entry.attendees.find((item) => item.attendeeId === participantId);
    if (!attendee) {
      return fail(
        404,
        'participant-not-found',
        'The participant is no longer registered in this room.',
      );
    }
    attendee.lastHeartbeatMs = Date.now();
  }
  entry.lastHeartbeatMs = Date.now();
  return reply({ contractVersion: contractVersion, ok: true, roomCode: entry.roomCode });

}
