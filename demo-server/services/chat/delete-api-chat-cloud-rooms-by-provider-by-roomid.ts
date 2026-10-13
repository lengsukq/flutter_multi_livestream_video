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

export async function deleteApiChatCloudRoomsByProviderByRoomid(input: ApplicationInput, dependencies: Pick<ChatApplicationDependencies, 'chatRoomDirectory' | 'chatProviderRegistry' | 'contractVersion' | 'logEvent'>): Promise<ApplicationReply> {
const { chatRoomDirectory, chatProviderRegistry, contractVersion, logEvent } = dependencies;


    try {
      const providerId = String(input.params.provider ?? '').trim().toLowerCase();
      const providerRoomId = String(input.params.roomId ?? '').trim();
      const provider = chatProviderRegistry.requireConfigured(providerId);
      if (!provider.deleteCloudRoom) {
        return fail(
          400,
          'unsupported-feature',
          'This chat provider does not expose cloud room deletion.',
        );
      }
      if (!providerRoomId) {
        return fail(
          400,
          'invalid-argument',
          'A provider room id is required.',
        );
      }

      await provider.deleteCloudRoom(providerRoomId);
      const removedRoomCodes: string[] = [];
      for (const entry of chatRoomDirectory.list()) {
        if (
          entry.chatProvider === providerId &&
          entry.chatRoomArn === providerRoomId
        ) {
          chatRoomDirectory.remove(entry.roomCode);
          removedRoomCodes.push(entry.roomCode);
        }
      }
      logEvent(
        'chat-room-close-force',
        `cloud chat room ${providerRoomId} deleted from ${providerId}`,
      );
      return reply({
        contractVersion: contractVersion,
        deleted: true,
        provider: providerId,
        providerRoomId,
        removedRoomCodes,
      });
    } catch (error) {
      if (error instanceof ProviderOperationError) throw error;
      console.error('admin cloud chat room delete failed', error);
      fail(
        500,
        'chat-cloud-room-delete-failed',
        'Unable to delete the cloud chat room.',
      );
    }

}
