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

export async function postChatRoomsByCodeCredentials(input: ApplicationInput, dependencies: Pick<ChatApplicationDependencies, 'chatRoomDirectory' | 'chatProviderRegistry' | 'chatManagementCapabilities'>): Promise<ApplicationReply> {
const { chatRoomDirectory, chatProviderRegistry, chatManagementCapabilities } = dependencies;


  try {
    const entry = chatRoomDirectory.get(input.params.code ?? '');
    if (!entry || !entry.chatProvider) {
      return fail( 404, 'room-not-found', 'The requested chat room was not found.');
    }
    const participantId = String(input.body?.participantId ?? '').trim();
    const attendee = requireParticipantCredential(
      entry,
      participantId,
      input.body?.participantCredential,
    );
    const provider = chatProviderRegistry.requireConfigured(entry.chatProvider);
    const response = await provider.issueToken({ entry, attendee });
    return reply({
      ...response,
      avatarUrl: attendee.avatarUrl,
      participantCredential: String(input.body?.participantCredential ?? '').trim(),
      context: 'standalone',
      management: chatManagementCapabilities(provider, attendee.role === 'host'),
    });
  } catch (error) {
    if (error instanceof ProviderOperationError) throw error;
    console.error('standalone chat credential refresh failed', error);
    fail( 500, 'chat-credential-refresh-failed', 'Unable to refresh chat credentials.');
  }

}
