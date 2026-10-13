import { requireStandaloneChatHost, chatMemberPayload, findChatMemberByUserId } from './chat-access.ts';
import crypto from 'node:crypto';
import type { RoomEntry, ChatRoomEntry, RoomAttendee, ChatProviderAdapter, MediaRole } from '../../types.ts';
import type { ChatRoomDirectory } from '../../chat/chat-room-directory.ts';
import type { ChatProviderRegistry } from '../../chat/chat-provider-registry.ts';
import { ProviderOperationError } from '../../providers/provider-registry.ts';
import { requireParticipantCredential, issueParticipantCredential } from '../../participant-credential.ts';
import { requireRoomManager } from '../../room-access.ts';

import type { ChatApplicationDependencies } from './dependencies.ts';
import { fail, reply, replyStatus, type ApplicationInput, type ApplicationReply } from '../application-protocol.ts';

export async function postRoomsByCodeChatManageRemove(input: ApplicationInput, dependencies: Pick<ChatApplicationDependencies, 'chatProviderRegistry' | 'contractVersion' | 'resolveRoom'>): Promise<ApplicationReply> {
const { chatProviderRegistry, contractVersion, resolveRoom } = dependencies;


  try {
    const entry = await resolveRoom(input.params.code);
    if (!entry || !entry.chatProvider) {
      return fail(
        404,
        'room-not-found',
        'The requested room or attached chat was not found.',
      );
    }
    const manager = requireRoomManager(
      entry,
      input.body?.requesterParticipantId,
      input.body?.participantCredential,
      input.body?.roomOwnerCredential,
    );
    if (!manager) {
      return fail( 403, 'forbidden', 'Room owner permission is required.');
    }
    const target = findChatMemberByUserId(entry, input.body?.targetUserId);
    if (!target || target.chatRemoved) {
      return fail(
        404,
        'participant-not-found',
        'The requested chat member was not found.',
      );
    }
    if (target.attendeeId === manager.attendeeId) {
      return fail(
        400,
        'invalid-argument',
        'The room owner cannot remove itself from attached chat.',
      );
    }
    const provider = chatProviderRegistry.requireConfigured(entry.chatProvider);
    const providerEnforced = input.body?.providerEnforced === true;
    if (!providerEnforced) {
      if (!provider.removeMember) {
        return fail(
          400,
          'unsupported-feature',
          'This chat provider does not support member removal.',
        );
      }
      await provider.removeMember(entry, target);
    }
    target.chatRemoved = true;
    return reply({
      contractVersion: contractVersion,
      ok: true,
      roomCode: entry.roomCode,
      userId: target.userId ?? target.externalUserId,
    });
  } catch (error) {
    if (error instanceof ProviderOperationError) throw error;
    console.error('attached chat member removal failed', error);
    fail(
      500,
      'chat-member-remove-failed',
      'Unable to remove the attached chat member.',
    );
  }

}
