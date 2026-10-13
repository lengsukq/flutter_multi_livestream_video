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

export async function postRoomsByCodeChatMembers(input: ApplicationInput, dependencies: Pick<ChatApplicationDependencies, 'contractVersion' | 'resolveRoom'>): Promise<ApplicationReply> {
const { contractVersion, resolveRoom } = dependencies;


  try {
    const entry = await resolveRoom(input.params.code);
    if (!entry || !entry.chatProvider) {
      return fail(
        404,
        'room-not-found',
        'The requested room or attached chat was not found.',
      );
    }
    if (
      !requireRoomManager(
        entry,
        input.body?.requesterParticipantId,
        input.body?.participantCredential,
        input.body?.roomOwnerCredential,
      )
    ) {
      return fail( 403, 'forbidden', 'Room owner permission is required.');
    }
    return reply({
      contractVersion: contractVersion,
      roomCode: entry.roomCode,
      members: entry.attendees
        .filter((item) => !item.chatRemoved)
        .map(chatMemberPayload),
    });
  } catch (error) {
    if (error instanceof ProviderOperationError) throw error;
    console.error('attached chat member list failed', error);
    fail( 500, 'chat-member-list-failed', 'Unable to list chat members.');
  }

}
