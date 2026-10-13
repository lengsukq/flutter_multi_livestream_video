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

export async function postChatRoomsByCodeManageClose(input: ApplicationInput, dependencies: Pick<ChatApplicationDependencies, 'chatRoomDirectory' | 'chatProviderRegistry' | 'contractVersion' | 'closeRoom'>): Promise<ApplicationReply> {
const { chatRoomDirectory, chatProviderRegistry, contractVersion, closeRoom } = dependencies;


  try {
    const entry = chatRoomDirectory.get(input.params.code ?? '');
    if (!entry || !entry.chatProvider) {
      return fail( 404, 'room-not-found', 'The requested chat room was not found.');
    }
    requireStandaloneChatHost(entry, input.body ?? {});
    const provider = chatProviderRegistry.requireConfigured(entry.chatProvider);
    await provider.closeRoom(entry);
    chatRoomDirectory.remove(entry.roomCode);
    return reply({ contractVersion: contractVersion, ok: true, roomCode: entry.roomCode });
  } catch (error) {
    if (error instanceof ProviderOperationError) throw error;
    console.error('standalone chat close failed', error);
    fail( 500, 'chat-room-close-failed', 'Unable to close the chat room.');
  }

}
