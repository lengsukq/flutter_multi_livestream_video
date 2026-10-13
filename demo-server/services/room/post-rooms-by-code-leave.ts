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

export async function postRoomsByCodeLeave(input: ApplicationInput, dependencies: Pick<RoomApplicationDependencies, 'providerRegistry' | 'classroomDirectory' | 'contractVersion' | 'resolveRoom' | 'withRoomOperation' | 'closeRoomUnlocked' | 'logEvent'>): Promise<ApplicationReply> {
const { providerRegistry, classroomDirectory, contractVersion, resolveRoom, withRoomOperation, closeRoomUnlocked, logEvent } = dependencies;


  try {
    const entry = await resolveRoom(input.params.code);
    if (!entry) return fail( 404, 'room-not-found', 'The requested room was not found.');
    return await withRoomOperation(entry, async () => {
      const provider = providerRegistry.require(entry.provider);
      const who = input.body?.participantId ?? input.body?.attendeeId ?? input.body?.userId ?? 'someone';
      const result = typeof provider.removeAttendee === 'function'
        ? provider.removeAttendee(entry, who)
        : { removed: false, closeWhenEmpty: false };
      if (result.closeWhenEmpty) {
        await closeRoomUnlocked(entry, 'last attendee left');
        return reply({ contractVersion: contractVersion, ok: true, roomCode: entry.roomCode, closed: true });
      }
      if (entry.roomMode === 'meeting') classroomDirectory.snapshot(entry, false);
      logEvent('leave', `${who} left room ${entry.roomCode} (auto-close in ~90s if empty)`);
      return reply({ contractVersion: contractVersion, ok: true, roomCode: entry.roomCode });
    });
  } catch (error) {
    if (error instanceof ProviderOperationError) throw error;
    console.error('leave failed', error);
    fail( 500, 'leave-failed', 'Unable to leave the room.');
  }

}
