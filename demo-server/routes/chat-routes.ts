import crypto from 'node:crypto';
import type { Express, RequestHandler, Response } from 'express';
import type { RoomEntry, ChatRoomEntry, RoomAttendee, ChatProviderAdapter, MediaRole } from '../types.ts';
import type { ChatRoomDirectory } from '../chat/chat-room-directory.ts';
import type { ChatProviderRegistry } from '../chat/chat-provider-registry.ts';
import { ProviderOperationError } from '../providers/provider-registry.ts';
import { requireParticipantCredential, issueParticipantCredential } from '../participant-credential.ts';
import { requireRoomManager } from '../room-access.ts';

export interface ChatRouteDependencies {
  chatRoomDirectory: ChatRoomDirectory;
  chatProviderRegistry: ChatProviderRegistry;
  currentChatProvider(): string | null;
  contractVersion: number;
  resolveRoom(ref: unknown): Promise<RoomEntry | null>;
  contractError(res: Response, status: number, code: string, message: string, details?: unknown): Response;
  sendProviderError(res: Response, error: unknown): Response | false;
  chatManagementCapabilities(provider: ChatProviderAdapter, canManage: boolean): {
    listMembers: boolean; removeMember: boolean; closeRoom: boolean; muteMember: boolean;
    banMember: boolean; recallMessage: boolean; manageRoles: boolean;
  };
  closeRoom(entry: RoomEntry, reason: string): Promise<void>;
  normalizeUserId(raw: unknown): string;
  normalizeDisplayName(raw: unknown): string;
  generateRoomCode(): string;
  logEvent(type: string, message: string): void;
  requireSameOrigin: RequestHandler;
  requireAdmin: RequestHandler;
}

/** Both standalone and media-attached Chat use the same credential checks. */
export function registerChatRoutes(app: Express, deps: ChatRouteDependencies): void {
  const {
    chatRoomDirectory, chatProviderRegistry, currentChatProvider, contractVersion,
    resolveRoom, contractError, sendProviderError, chatManagementCapabilities,
    closeRoom, normalizeUserId, normalizeDisplayName, generateRoomCode, logEvent,
    requireSameOrigin, requireAdmin,
  } = deps;

function requireStandaloneChatHost(entry: ChatRoomEntry, body: Record<string, unknown>): RoomAttendee {
  const participantId = String(body.requesterParticipantId ?? '').trim();
  const attendee = requireParticipantCredential(
    entry,
    participantId,
    body.participantCredential,
  );
  if (attendee.role !== 'host') {
    throw new ProviderOperationError(403, 'forbidden', 'Chat management requires the host role.');
  }
  return attendee;
}

function chatMemberPayload(item: RoomAttendee) {
  return {
    userId: item.userId ?? item.externalUserId,
    displayName: item.displayName ?? item.externalUserId,
    role: item.role ?? 'participant',
  };
}

function findChatMemberByUserId(
  entry: ChatRoomEntry,
  userId: unknown,
): RoomAttendee | null {
  const target = String(userId ?? '').trim();
  if (!target) return null;
  return (
    entry.attendees.find(
      (item) => (item.userId ?? item.externalUserId) === target,
    ) ?? null
  );
}

app.post('/chat/rooms/:code/members', (req, res) => {
  try {
    const entry = chatRoomDirectory.get(req.params.code);
    if (!entry) {
      return contractError(res, 404, 'room-not-found', 'The requested chat room was not found.');
    }
    requireStandaloneChatHost(entry, req.body ?? {});
    res.json({
      contractVersion: contractVersion,
      roomCode: entry.roomCode,
      members: entry.attendees.map(chatMemberPayload),
    });
  } catch (error) {
    if (sendProviderError(res, error) !== false) return;
    throw error;
  }
});

app.post('/rooms/:code/chat/members', async (req, res) => {
  try {
    const entry = await resolveRoom(req.params.code);
    if (!entry || !entry.chatProvider) {
      return contractError(
        res,
        404,
        'room-not-found',
        'The requested room or attached chat was not found.',
      );
    }
    if (
      !requireRoomManager(
        entry,
        req.body?.requesterParticipantId,
        req.body?.participantCredential,
        req.body?.roomOwnerCredential,
      )
    ) {
      return contractError(res, 403, 'forbidden', 'Room owner permission is required.');
    }
    res.json({
      contractVersion: contractVersion,
      roomCode: entry.roomCode,
      members: entry.attendees
        .filter((item) => !item.chatRemoved)
        .map(chatMemberPayload),
    });
  } catch (error) {
    if (sendProviderError(res, error) !== false) return;
    console.error('attached chat member list failed', error);
    contractError(res, 500, 'chat-member-list-failed', 'Unable to list chat members.');
  }
});

app.post('/rooms/:code/chat/manage/remove', async (req, res) => {
  try {
    const entry = await resolveRoom(req.params.code);
    if (!entry || !entry.chatProvider) {
      return contractError(
        res,
        404,
        'room-not-found',
        'The requested room or attached chat was not found.',
      );
    }
    const manager = requireRoomManager(
      entry,
      req.body?.requesterParticipantId,
      req.body?.participantCredential,
      req.body?.roomOwnerCredential,
    );
    if (!manager) {
      return contractError(res, 403, 'forbidden', 'Room owner permission is required.');
    }
    const target = findChatMemberByUserId(entry, req.body?.targetUserId);
    if (!target || target.chatRemoved) {
      return contractError(
        res,
        404,
        'participant-not-found',
        'The requested chat member was not found.',
      );
    }
    if (target.attendeeId === manager.attendeeId) {
      return contractError(
        res,
        400,
        'invalid-argument',
        'The room owner cannot remove itself from attached chat.',
      );
    }
    const provider = chatProviderRegistry.requireConfigured(entry.chatProvider);
    const providerEnforced = req.body?.providerEnforced === true;
    if (!providerEnforced) {
      if (!provider.removeMember) {
        return contractError(
          res,
          400,
          'unsupported-feature',
          'This chat provider does not support member removal.',
        );
      }
      await provider.removeMember(entry, target);
    }
    target.chatRemoved = true;
    res.json({
      contractVersion: contractVersion,
      ok: true,
      roomCode: entry.roomCode,
      userId: target.userId ?? target.externalUserId,
    });
  } catch (error) {
    if (sendProviderError(res, error) !== false) return;
    console.error('attached chat member removal failed', error);
    contractError(
      res,
      500,
      'chat-member-remove-failed',
      'Unable to remove the attached chat member.',
    );
  }
});

app.post('/rooms/:code/chat/manage/close', async (req, res) => {
  try {
    const entry = await resolveRoom(req.params.code);
    if (!entry || !entry.chatProvider) {
      return contractError(
        res,
        404,
        'room-not-found',
        'The requested room or attached chat was not found.',
      );
    }
    if (
      !requireRoomManager(
        entry,
        req.body?.requesterParticipantId,
        req.body?.participantCredential,
        req.body?.roomOwnerCredential,
      )
    ) {
      return contractError(res, 403, 'forbidden', 'Room owner permission is required.');
    }
    if (!entry.chatClosed) {
      const provider = chatProviderRegistry.requireConfigured(entry.chatProvider);
      await provider.closeRoom(entry);
      entry.chatClosed = true;
    }
    res.json({
      contractVersion: contractVersion,
      ok: true,
      roomCode: entry.roomCode,
    });
  } catch (error) {
    if (sendProviderError(res, error) !== false) return;
    console.error('attached chat close failed', error);
    contractError(res, 500, 'chat-room-close-failed', 'Unable to close attached chat.');
  }
});

app.post('/chat/rooms/:code/manage/remove', async (req, res) => {
  try {
    const entry = chatRoomDirectory.get(req.params.code);
    if (!entry || !entry.chatProvider) {
      return contractError(
        res,
        404,
        'room-not-found',
        'The requested chat room was not found.',
      );
    }
    const host = requireStandaloneChatHost(entry, req.body ?? {});
    const target = findChatMemberByUserId(entry, req.body?.targetUserId);
    if (!target) {
      return contractError(
        res,
        404,
        'participant-not-found',
        'The requested chat member was not found.',
      );
    }
    if (target.attendeeId === host.attendeeId) {
      return contractError(
        res,
        400,
        'invalid-argument',
        'The host cannot remove itself; close the chat room instead.',
      );
    }
    const provider = chatProviderRegistry.requireConfigured(entry.chatProvider);
    const providerEnforced = req.body?.providerEnforced === true;
    if (!providerEnforced) {
      if (!provider.removeMember) {
        return contractError(
          res,
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
    res.json({
      contractVersion: contractVersion,
      ok: true,
      roomCode: entry.roomCode,
      userId: target.userId ?? target.externalUserId,
    });
  } catch (error) {
    if (sendProviderError(res, error) !== false) return;
    console.error('standalone chat member removal failed', error);
    contractError(
      res,
      500,
      'chat-member-remove-failed',
      'Unable to remove the chat member.',
    );
  }
});

app.post('/chat/rooms/:code/manage/close', async (req, res) => {
  try {
    const entry = chatRoomDirectory.get(req.params.code);
    if (!entry || !entry.chatProvider) {
      return contractError(res, 404, 'room-not-found', 'The requested chat room was not found.');
    }
    requireStandaloneChatHost(entry, req.body ?? {});
    const provider = chatProviderRegistry.requireConfigured(entry.chatProvider);
    await provider.closeRoom(entry);
    chatRoomDirectory.remove(entry.roomCode);
    res.json({ contractVersion: contractVersion, ok: true, roomCode: entry.roomCode });
  } catch (error) {
    if (sendProviderError(res, error) !== false) return;
    console.error('standalone chat close failed', error);
    contractError(res, 500, 'chat-room-close-failed', 'Unable to close the chat room.');
  }
});

app.delete('/api/chat/rooms/:code', requireSameOrigin, requireAdmin, async (req, res) => {
  try {
    const entry = chatRoomDirectory.get(String(req.params.code ?? ''));
    if (!entry || !entry.chatProvider) {
      return contractError(res, 404, 'room-not-found', 'The requested chat room was not found.');
    }
    const provider = chatProviderRegistry.requireConfigured(entry.chatProvider);
    await provider.closeRoom(entry);
    chatRoomDirectory.remove(entry.roomCode);
    logEvent(
      'chat-room-close-force',
      `standalone chat room ${entry.roomCode} closed by dashboard admin`,
    );
    res.json({
      contractVersion: contractVersion,
      deleted: true,
      roomCode: entry.roomCode,
    });
  } catch (error) {
    if (sendProviderError(res, error) !== false) return;
    console.error('admin standalone chat close failed', error);
    contractError(res, 500, 'chat-room-close-failed', 'Unable to close the chat room.');
  }
});

app.get('/api/chat/cloud-rooms', requireAdmin, async (req, res) => {
  try {
    const providerId = String(
      req.query.provider ?? currentChatProvider() ?? '',
    ).trim().toLowerCase();
    if (!providerId) {
      return res.json({
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
      return res.json({
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
    res.json({
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
    if (sendProviderError(res, error) !== false) return;
    console.error('admin cloud chat room list failed', error);
    contractError(
      res,
      500,
      'chat-cloud-room-list-failed',
      'Unable to list cloud chat rooms.',
    );
  }
});

app.delete(
  '/api/chat/cloud-rooms/:provider/:roomId',
  requireSameOrigin,
  requireAdmin,
  async (req, res) => {
    try {
      const providerId = String(req.params.provider ?? '').trim().toLowerCase();
      const providerRoomId = String(req.params.roomId ?? '').trim();
      const provider = chatProviderRegistry.requireConfigured(providerId);
      if (!provider.deleteCloudRoom) {
        return contractError(
          res,
          400,
          'unsupported-feature',
          'This chat provider does not expose cloud room deletion.',
        );
      }
      if (!providerRoomId) {
        return contractError(
          res,
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
      res.json({
        contractVersion: contractVersion,
        deleted: true,
        provider: providerId,
        providerRoomId,
        removedRoomCodes,
      });
    } catch (error) {
      if (sendProviderError(res, error) !== false) return;
      console.error('admin cloud chat room delete failed', error);
      contractError(
        res,
        500,
        'chat-cloud-room-delete-failed',
        'Unable to delete the cloud chat room.',
      );
    }
  },
);

app.post('/chat/rooms/:code/credentials', async (req, res) => {
  try {
    const entry = chatRoomDirectory.get(req.params.code);
    if (!entry || !entry.chatProvider) {
      return contractError(res, 404, 'room-not-found', 'The requested chat room was not found.');
    }
    const participantId = String(req.body?.participantId ?? '').trim();
    const attendee = requireParticipantCredential(
      entry,
      participantId,
      req.body?.participantCredential,
    );
    const provider = chatProviderRegistry.requireConfigured(entry.chatProvider);
    const response = await provider.issueToken({ entry, attendee });
    res.json({
      ...response,
      participantCredential: String(req.body?.participantCredential ?? '').trim(),
      context: 'standalone',
      management: chatManagementCapabilities(provider, attendee.role === 'host'),
    });
  } catch (error) {
    if (sendProviderError(res, error) !== false) return;
    console.error('standalone chat credential refresh failed', error);
    contractError(res, 500, 'chat-credential-refresh-failed', 'Unable to refresh chat credentials.');
  }
});

app.get('/chat/rooms', (_req, res) => {
  res.json({
    contractVersion: contractVersion,
    rooms: chatRoomDirectory.list().map((entry) => ({
      roomCode: entry.roomCode,
      chatProvider: entry.chatProvider,
      context: 'standalone',
      createdAt: entry.createdAt,
    })),
  });
});

app.post('/chat/rooms', async (req, res) => {
  try {
    const providerId = String(
      req.body?.chatProvider ?? currentChatProvider() ?? '',
    ).trim().toLowerCase();
    if (!providerId) {
      return contractError(
        res,
        400,
        'provider-not-configured',
        'Select a configured chat provider before creating a chat room.',
      );
    }
    const provider = chatProviderRegistry.requireConfigured(providerId);
    const requestedCode = String(req.body?.roomCode ?? '').trim();
    const roomCode = requestedCode || generateRoomCode();
    if (chatRoomDirectory.get(roomCode)) {
      return contractError(res, 409, 'room-exists', 'The chat room code is already in use.');
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
    const userId = String(req.body?.userId ?? '').trim();
    if (userId) {
      const displayName = normalizeDisplayName(req.body?.displayName ?? userId);
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
      return res.status(201).json({
        ...response,
        participantCredential,
        context: 'standalone',
        management: chatManagementCapabilities(provider, attendee.role === 'host'),
      });
    }
    res.status(201).json({
      contractVersion: contractVersion,
      roomCode: entry.roomCode,
      chatProvider: entry.chatProvider,
      context: 'standalone',
    });
  } catch (error) {
    if (sendProviderError(res, error) !== false) return;
    console.error('standalone chat room create failed', error);
    contractError(res, 500, 'chat-room-create-failed', 'Unable to create the chat room.');
  }
});

app.post('/chat/rooms/:code/join', async (req, res) => {
  try {
    const entry = chatRoomDirectory.get(req.params.code);
    if (!entry || !entry.chatProvider) {
      return contractError(res, 404, 'room-not-found', 'The requested chat room was not found.');
    }
    const provider = chatProviderRegistry.requireConfigured(entry.chatProvider);
    const userId = normalizeUserId(req.body?.userId);
    const displayName = normalizeDisplayName(req.body?.displayName ?? userId);
    // Public joins are never allowed to self-promote to host. The creator gets
    // host credentials atomically from POST /chat/rooms.
    const role: MediaRole = 'participant';
    const participantId = `chat-${crypto.randomUUID()}`;
    const attendee: RoomAttendee = {
      attendeeId: participantId,
      externalUserId: userId,
      userId,
      displayName,
      role,
      joinedAt: new Date().toISOString(),
      lastHeartbeatMs: Date.now(),
    };
    entry.attendees.push(attendee);
    entry.lastHeartbeatMs = Date.now();
    const response = await provider.issueToken({ entry, attendee });
    const participantCredential = issueParticipantCredential(entry, participantId);
    res.json({
      ...response,
      participantCredential,
      context: 'standalone',
      management: chatManagementCapabilities(provider, attendee.role === 'host'),
    });
  } catch (error) {
    if (sendProviderError(res, error) !== false) return;
    console.error('standalone chat join failed', error);
    contractError(res, 500, 'chat-join-failed', 'Unable to join the chat room.');
  }
});

}
