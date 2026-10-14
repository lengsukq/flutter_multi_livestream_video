import type { ProviderAdapter, ChatProviderAdapter, RoomEntry, RoomAttendee, MediaRole, RoomMode } from '../../types.ts';
import type { ProviderRegistry } from '../../providers/provider-registry.ts';
import type { RoomDirectory } from '../../providers/room-directory.ts';
import type { ChatProviderRegistry } from '../../chat/chat-provider-registry.ts';
import type { ChatRoomDirectory } from '../../chat/chat-room-directory.ts';
import type { ClassroomStateDirectory } from '../../classroom/classroom-state.ts';
import { requireParticipantCredential, issueParticipantCredential } from '../../participant-credential.ts';
import { matchesRoomOwnerCredential } from '../../room-owner-credential.ts';
import { ProviderOperationError } from '../../providers/provider-registry.ts';
import { requireRoomManager } from '../../room-access.ts';
import { createRoomProvisioner } from '../../services/room-creation.ts';

import type { RoomApplicationDependencies } from './dependencies.ts';
import { fail, reply, replyStatus, type ApplicationInput, type ApplicationReply } from '../application-protocol.ts';

export async function postRoomsByCodeChatToken(input: ApplicationInput, dependencies: Pick<RoomApplicationDependencies, 'chatProviderRegistry' | 'resolveRoom' | 'isRoomPartiallyClosed' | 'pruneStaleAttendees' | 'chatManagementCapabilities'>): Promise<ApplicationReply> {
const { chatProviderRegistry, resolveRoom, isRoomPartiallyClosed, pruneStaleAttendees, chatManagementCapabilities } = dependencies;


  try {
    const entry = await resolveRoom(input.params.code);
    if (!entry) {
      return fail( 404, 'room-not-found', 'The requested room was not found.');
    }
    if (isRoomPartiallyClosed(entry)) {
      return fail(
        409,
        'room-closing',
        'The room is partially closed and cannot issue chat credentials.',
      );
    }
    if (!entry.chatProvider || !entry.chatRoomArn) {
      return fail(
        400,
        'unsupported-feature',
        'This room does not have a chat provider.',
      );
    }
    const participantId = String(input.body?.participantId ?? '').trim();
    if (!participantId) {
      return fail( 400, 'invalid-argument', 'participantId is required.');
    }
    pruneStaleAttendees(entry, Date.now());
    const attendee = requireParticipantCredential(
      entry,
      participantId,
      input.body?.participantCredential,
    );
    if (attendee.chatRemoved) {
      return fail(
        403,
        'forbidden',
        'This participant has been removed from the attached chat.',
      );
    }
    const ownerCredential = String(
      input.body?.roomOwnerCredential ?? '',
    ).trim();
    const canManageChat =
      attendee.role === 'host' ||
      (ownerCredential.length > 0 &&
        matchesRoomOwnerCredential(entry, ownerCredential));
    const chatAttendee =
      canManageChat && attendee.role !== 'host'
        ? { ...attendee, role: 'host' as const }
        : attendee;
    const chatProvider = chatProviderRegistry.requireConfigured(entry.chatProvider);
    const response = await chatProvider.issueToken({
      entry,
      attendee: chatAttendee,
    });
    return reply({
      ...response,
      avatarUrl: attendee.avatarUrl,
      participantCredential: String(
        input.body?.participantCredential ?? '',
      ).trim(),
      roomOwnerCredential: ownerCredential,
      context: 'attached',
      management: chatManagementCapabilities(chatProvider, canManageChat),
    });
  } catch (error) {
    if (error instanceof ProviderOperationError) throw error;
    console.error('chat token failed', error);
    fail( 500, 'chat-token-failed', 'Unable to issue chat credentials.');
  }

}
