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

export async function postChatRooms(input: ApplicationInput, dependencies: Pick<ChatApplicationDependencies, 'chatRoomDirectory' | 'chatProviderRegistry' | 'currentChatProvider' | 'contractVersion' | 'chatManagementCapabilities' | 'normalizeDisplayName' | 'generateRoomCode'>): Promise<ApplicationReply> {
const { chatRoomDirectory, chatProviderRegistry, currentChatProvider, contractVersion, chatManagementCapabilities, normalizeDisplayName, generateRoomCode } = dependencies;


  try {
    const providerId = String(
      input.body?.chatProvider ?? currentChatProvider() ?? '',
    ).trim().toLowerCase();
    if (!providerId) {
      return fail(
        400,
        'provider-not-configured',
        'Select a configured chat provider before creating a chat room.',
      );
    }
    const provider = chatProviderRegistry.requireConfigured(providerId);
    const requestedCode = String(input.body?.roomCode ?? '').trim();
    const roomCode = requestedCode || generateRoomCode();
    if (chatRoomDirectory.get(roomCode)) {
      return fail( 409, 'room-exists', 'The chat room code is already in use.');
    }
    const binding = await provider.createRoom(roomCode);
    const now = Date.now();
    const entry = chatRoomDirectory.add({
      roomCode,
      chatProvider: binding.chatProvider,
      chatRoomArn: binding.chatRoomArn,
      createdAt: new Date(now).toISOString(),
      attendees: [],
      lastHeartbeatMs: now,
    });
    const userId = String(input.body?.userId ?? '').trim();
    if (userId) {
      const displayName = normalizeDisplayName(input.body?.displayName ?? userId);
      const participantId = `chat-${crypto.randomUUID()}`;
      const attendee: RoomAttendee = {
        attendeeId: participantId,
        externalUserId: userId,
        userId,
        displayName,
        role: 'host',
        joinedAt: new Date(now).toISOString(),
        lastHeartbeatMs: now,
      };
      entry.attendees.push(attendee);
      const participantCredential = issueParticipantCredential(entry, participantId);
      const response = await provider.issueToken({ entry, attendee });
      return replyStatus(201, {
        ...response,
        participantCredential,
        context: 'standalone',
        management: chatManagementCapabilities(provider, attendee.role === 'host'),
      });
    }
    return replyStatus(201, {
      contractVersion: contractVersion,
      roomCode: entry.roomCode,
      chatProvider: entry.chatProvider,
      context: 'standalone',
    });
  } catch (error) {
    if (error instanceof ProviderOperationError) throw error;
    console.error('standalone chat room create failed', error);
    fail( 500, 'chat-room-create-failed', 'Unable to create the chat room.');
  }

}
