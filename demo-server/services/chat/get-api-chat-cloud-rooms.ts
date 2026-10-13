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

export async function getApiChatCloudRooms(input: ApplicationInput, dependencies: Pick<ChatApplicationDependencies, 'chatRoomDirectory' | 'chatProviderRegistry' | 'currentChatProvider' | 'contractVersion'>): Promise<ApplicationReply> {
const { chatRoomDirectory, chatProviderRegistry, currentChatProvider, contractVersion } = dependencies;


  try {
    const providerId = String(
      input.query.provider ?? currentChatProvider() ?? '',
    ).trim().toLowerCase();
    if (!providerId) {
      return reply({
        contractVersion: contractVersion,
        provider: null,
        source: 'local',
        rooms: [],
      });
    }

    const provider = chatProviderRegistry.requireConfigured(providerId);
    const localRooms = chatRoomDirectory
      .list()
      .filter((entry) => entry.chatProvider === providerId);

    if (!provider.listCloudRooms) {
      return reply({
        contractVersion: contractVersion,
        provider: providerId,
        source: 'local',
        rooms: localRooms.map((entry) => ({
          roomCode: entry.roomCode,
          providerRoomId: entry.chatRoomArn ?? entry.roomCode,
          chatProvider: entry.chatProvider,
          name: entry.roomCode,
          type: 'standalone',
          memberCount: entry.attendees.length,
          createdAt: entry.createdAt,
          tracked: true,
          attendees: entry.attendees,
        })),
      });
    }

    const cloudRooms = await provider.listCloudRooms();
    const localByProviderRoomId = new Map(
      localRooms
        .filter((entry) => entry.chatRoomArn)
        .map((entry) => [entry.chatRoomArn!, entry]),
    );
    return reply({
      contractVersion: contractVersion,
      provider: providerId,
      source: 'cloud',
      rooms: cloudRooms.map((room) => {
        const local = localByProviderRoomId.get(room.providerRoomId);
        return {
          roomCode: local?.roomCode ?? room.inferredRoomCode ?? '',
          providerRoomId: room.providerRoomId,
          chatProvider: providerId,
          name: room.name,
          type: room.type,
          memberCount: room.memberCount ?? local?.attendees.length ?? 0,
          createdAt: room.createdAt ?? local?.createdAt ?? null,
          tracked: Boolean(local),
          attendees: local?.attendees ?? [],
        };
      }),
    });
  } catch (error) {
    if (error instanceof ProviderOperationError) throw error;
    console.error('admin cloud chat room list failed', error);
    fail(
      500,
      'chat-cloud-room-list-failed',
      'Unable to list cloud chat rooms.',
    );
  }

}
