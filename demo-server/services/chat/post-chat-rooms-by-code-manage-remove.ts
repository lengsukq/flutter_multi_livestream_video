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

export async function postChatRoomsByCodeManageRemove(input: ApplicationInput, dependencies: Pick<ChatApplicationDependencies, 'chatRoomDirectory' | 'chatProviderRegistry' | 'contractVersion'>): Promise<ApplicationReply> {
const { chatRoomDirectory, chatProviderRegistry, contractVersion } = dependencies;


  try {
    const entry = chatRoomDirectory.get(input.params.code ?? '');
    if (!entry || !entry.chatProvider) {
      return fail(
        404,
        'room-not-found',
        'The requested chat room was not found.',
      );
    }
    const host = requireStandaloneChatHost(entry, input.body ?? {});
    const target = findChatMemberByUserId(entry, input.body?.targetUserId);
    if (!target) {
      return fail(
        404,
        'participant-not-found',
        'The requested chat member was not found.',
      );
    }
    if (target.attendeeId === host.attendeeId) {
      return fail(
        400,
        'invalid-argument',
        'The host cannot remove itself; close the chat room instead.',
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
    entry.attendees = entry.attendees.filter(
      (item) => item.attendeeId !== target.attendeeId,
    );
    return reply({
      contractVersion: contractVersion,
      ok: true,
      roomCode: entry.roomCode,
      userId: target.userId ?? target.externalUserId,
    });
  } catch (error) {
    if (error instanceof ProviderOperationError) throw error;
    console.error('standalone chat member removal failed', error);
    fail(
      500,
      'chat-member-remove-failed',
      'Unable to remove the chat member.',
    );
  }

}
