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

export async function postChatRoomsByCodeJoin(input: ApplicationInput, dependencies: Pick<ChatApplicationDependencies, 'chatRoomDirectory' | 'chatProviderRegistry' | 'chatManagementCapabilities' | 'normalizeUserId' | 'normalizeDisplayName'>): Promise<ApplicationReply> {
const { chatRoomDirectory, chatProviderRegistry, chatManagementCapabilities, normalizeUserId, normalizeDisplayName } = dependencies;


  try {
    const avatarUrl = normalizeAvatarUrl(input.body?.avatarUrl);
    const entry = chatRoomDirectory.get(input.params.code ?? '');
    if (!entry || !entry.chatProvider) {
      return fail( 404, 'room-not-found', 'The requested chat room was not found.');
    }
    const provider = chatProviderRegistry.requireConfigured(entry.chatProvider);
    const userId = normalizeUserId(input.body?.userId);
    const displayName = normalizeDisplayName(input.body?.displayName ?? userId);
    // Public joins are never allowed to self-promote to host. The creator gets
    // host credentials atomically from POST /chat/rooms.
    const role: MediaRole = 'participant';
    const participantId = `chat-${crypto.randomUUID()}`;
    const attendee: RoomAttendee = {
      attendeeId: participantId,
      externalUserId: userId,
      userId,
      displayName,
      avatarUrl,
      role,
      joinedAt: new Date().toISOString(),
      lastHeartbeatMs: Date.now(),
    };
    entry.attendees.push(attendee);
    entry.lastHeartbeatMs = Date.now();
    const response = await provider.issueToken({ entry, attendee });
    const participantCredential = issueParticipantCredential(entry, participantId);
    return reply({
      ...response,
      avatarUrl,
      participantCredential,
      context: 'standalone',
      management: chatManagementCapabilities(provider, attendee.role === 'host'),
    });
  } catch (error) {
    if (error instanceof ProviderOperationError) throw error;
    console.error('standalone chat join failed', error);
    fail( 500, 'chat-join-failed', 'Unable to join the chat room.');
  }

}
import { normalizeAvatarUrl } from '../participant-profile.ts';
