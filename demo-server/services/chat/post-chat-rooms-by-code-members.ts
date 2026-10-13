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

export async function postChatRoomsByCodeMembers(input: ApplicationInput, dependencies: Pick<ChatApplicationDependencies, 'chatRoomDirectory' | 'contractVersion'>): Promise<ApplicationReply> {
const { chatRoomDirectory, contractVersion } = dependencies;


  try {
    const entry = chatRoomDirectory.get(input.params.code ?? '');
    if (!entry) {
      return fail( 404, 'room-not-found', 'The requested chat room was not found.');
    }
    requireStandaloneChatHost(entry, input.body ?? {});
    return reply({
      contractVersion: contractVersion,
      roomCode: entry.roomCode,
      members: entry.attendees.map(chatMemberPayload),
    });
  } catch (error) {
    if (error instanceof ProviderOperationError) throw error;
    throw error;
  }

}
