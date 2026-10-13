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

export async function postRoomsByCodeClose(input: ApplicationInput, dependencies: Pick<RoomApplicationDependencies, 'contractVersion' | 'resolveRoom' | 'withRoomOperation' | 'closeRoomUnlocked'>): Promise<ApplicationReply> {
const { contractVersion, resolveRoom, withRoomOperation, closeRoomUnlocked } = dependencies;


  try {
    const entry = await resolveRoom(input.params.code);
    if (!entry) {
      return fail( 404, 'room-not-found', 'The requested room was not found.');
    }
    return await withRoomOperation(entry, async () => {
      if (!requireRoomManager(
        entry,
        input.body?.requesterParticipantId,
        input.body?.participantCredential,
        input.body?.roomOwnerCredential,
      )) {
        return fail( 403, 'forbidden', 'Host permission is required.');
      }
      await closeRoomUnlocked(entry, 'host close');
      return reply({
        contractVersion: contractVersion,
        ok: true,
        closed: true,
        roomCode: entry.roomCode,
    });
    });
  } catch (error) {
    if (error instanceof ProviderOperationError) throw error;
    console.error('host room close failed', error);
    fail( 500, 'close-failed', 'Unable to close the room.');
  }

}
