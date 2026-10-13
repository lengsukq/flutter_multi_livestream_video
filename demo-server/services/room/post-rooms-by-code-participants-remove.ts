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

export async function postRoomsByCodeParticipantsRemove(input: ApplicationInput, dependencies: Pick<RoomApplicationDependencies, 'providerRegistry' | 'classroomDirectory' | 'contractVersion' | 'resolveRoom' | 'withRoomOperation' | 'assertRoomOpen' | 'closeRoom' | 'logEvent'>): Promise<ApplicationReply> {
const { providerRegistry, classroomDirectory, contractVersion, resolveRoom, withRoomOperation, assertRoomOpen, closeRoom, logEvent } = dependencies;


  try {
    const entry = await resolveRoom(input.params.code);
    if (!entry) {
      return fail( 404, 'room-not-found', 'The requested room was not found.');
    }
    return await withRoomOperation(entry, async () => {
      assertRoomOpen(entry);
      const host = requireRoomManager(
        entry,
        input.body?.requesterParticipantId,
        input.body?.participantCredential,
        input.body?.roomOwnerCredential,
      );
      if (!host) {
        return fail( 403, 'forbidden', 'Host permission is required.');
      }
      const targetParticipantId = String(input.body?.targetParticipantId ?? '').trim();
      if (!targetParticipantId) {
        return fail( 400, 'invalid-argument', 'targetParticipantId is required.');
      }
      if (host.attendeeId === targetParticipantId) {
        return fail( 400, 'invalid-argument', 'Use leave or closeRoom for the host.');
      }
      const provider = providerRegistry.requireConfigured(entry.provider);
      if (typeof provider.moderateRemoveParticipant !== 'function') {
        return fail(
          400,
          'unsupported-feature',
          'This provider does not support server-enforced participant removal.',
        );
      }
      const removed = await provider.moderateRemoveParticipant(entry, targetParticipantId);
      if (!removed) {
        return fail( 404, 'participant-not-found', 'Participant was not found.');
      }
      if (entry.roomMode === 'meeting') classroomDirectory.snapshot(entry, false);
      logEvent('moderate', `${host.attendeeId} removed ${targetParticipantId} from room ${entry.roomCode}`);
      return reply({
        contractVersion: contractVersion,
        ok: true,
        roomCode: entry.roomCode,
        participantId: targetParticipantId,
    });
    });
  } catch (error) {
    if (error instanceof ProviderOperationError) throw error;
    console.error('participant removal failed', error);
    fail( 500, 'moderation-failed', 'Unable to remove the participant.');
  }

}
