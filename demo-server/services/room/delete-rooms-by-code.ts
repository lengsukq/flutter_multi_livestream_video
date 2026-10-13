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

export async function deleteRoomsByCode(input: ApplicationInput, dependencies: Pick<RoomApplicationDependencies, 'roomDirectory' | 'contractVersion' | 'resolveRoom' | 'closeRoom'>): Promise<ApplicationReply> {
const { roomDirectory, contractVersion, resolveRoom, closeRoom } = dependencies;


  try {
    const entry = await resolveRoom(input.params.code);
    if (!entry) return fail( 404, 'room-not-found', 'The requested room was not found.');
    await closeRoom(entry, 'force close');
    return reply({ contractVersion: contractVersion, deleted: true, roomCode: entry.roomCode });
  } catch (error) {
    if (error instanceof ProviderOperationError) throw error;
    if (error instanceof Error && error.name === 'NotFoundException') {
      const stale = roomDirectory.get(input.params.code);
      if (stale) roomDirectory.remove(stale);
      return fail( 404, 'room-not-found', 'The requested room was not found.');
    }
    console.error('room delete failed', error);
    fail( 500, 'delete-failed', 'Unable to close the room.');
  }

}
