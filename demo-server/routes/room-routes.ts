import type { Express, Request, RequestHandler, Response } from 'express';
import type { ProviderAdapter, ChatProviderAdapter, RoomEntry, RoomAttendee, MediaRole, RoomMode } from '../types.ts';
import type { ProviderRegistry } from '../providers/provider-registry.ts';
import type { RoomDirectory } from '../providers/room-directory.ts';
import type { ChatProviderRegistry } from '../chat/chat-provider-registry.ts';
import type { ChatRoomDirectory } from '../chat/chat-room-directory.ts';
import type { ClassroomStateDirectory } from '../classroom/classroom-state.ts';
import { requireParticipantCredential, issueParticipantCredential } from '../participant-credential.ts';
import { matchesRoomOwnerCredential } from '../room-owner-credential.ts';
import { ProviderOperationError } from '../providers/provider-registry.ts';
import { requireRoomManager } from '../room-access.ts';
import { createRoomProvisioner } from '../services/room-creation.ts';

export interface RoomRouteDependencies {
  roomDirectory: RoomDirectory;
  providerRegistry: ProviderRegistry;
  chatProviderRegistry: ChatProviderRegistry;
  chatRoomDirectory: ChatRoomDirectory;
  classroomDirectory: ClassroomStateDirectory;
  currentProvider(): string;
  currentChatProvider(): string | null;
  contractVersion: number;
  resolveRoom(ref: unknown): Promise<RoomEntry | null>;
  withRoomOperation: <T>(entry: RoomEntry, action: () => Promise<T> | T) => Promise<T>;
  assertRoomOpen(entry: RoomEntry): void;
  isRoomPartiallyClosed(entry: RoomEntry): boolean;
  pruneStaleAttendees(entry: RoomEntry, now: number, insideOperation?: boolean): void;
  bindLogicalIdentity(entry: RoomEntry, participantId: string, userId: string, displayName: string, deviceId: string | null, role: MediaRole): void;
  normalizeRoomCode(raw: unknown): string | null;
  normalizeDeviceId(raw: unknown): string | null;
  normalizeDisplayName(raw: unknown): string;
  normalizeUserId(raw: unknown): string;
  parseRole(raw: unknown): MediaRole | null;
  parseRoomMode(raw: unknown): RoomMode | null;
  creatorRoleForMode(mode: RoomMode): MediaRole;
  joinRoleForRoom(entry: RoomEntry, ownerCredential: unknown): MediaRole;
  generateRoomCode(): string;
  engineProviderForSelection(providerId: string, mode: RoomMode): ProviderAdapter;
  publicProviderId(engineId: string): string;
  exposeVendorResponse: <T extends {provider: string; [key: string]: unknown}>(response: T) => T;
  registerRoom(provider: ProviderAdapter, entry: RoomEntry): RoomEntry;
  assertRole(provider: ProviderAdapter, role: MediaRole, entry?: RoomEntry | null): void;
  closeRoom(entry: RoomEntry, reason: string): Promise<void>;
  closeRoomUnlocked(entry: RoomEntry, reason: string): Promise<void>;
  contractError(res: Response, status: number, code: string, message: string, details?: unknown): Response;
  sendProviderError(res: Response, error: unknown): Response | false;
  mediaManagementCapabilities(provider: ProviderAdapter): {
    listParticipants: boolean; removeParticipant: boolean; closeRoom: boolean;
    muteParticipant: boolean; stopParticipantVideo: boolean; changeParticipantRole: boolean;
  };
  chatManagementCapabilities(provider: ChatProviderAdapter, canManage: boolean): {
    listMembers: boolean; removeMember: boolean; closeRoom: boolean; muteMember: boolean;
    banMember: boolean; recallMessage: boolean; manageRoles: boolean;
  };
  logEvent(type: string, message: string): void;
  requireSameOrigin: RequestHandler;
  requireAdmin: RequestHandler;
}

/** Media room contract endpoints; all SDK and provider details are injected. */
export function registerRoomRoutes(app: Express, dependencies: RoomRouteDependencies): void {
  const {
    roomDirectory, providerRegistry, chatProviderRegistry, chatRoomDirectory,
    classroomDirectory, currentProvider, currentChatProvider, contractVersion,
    resolveRoom, withRoomOperation, assertRoomOpen, isRoomPartiallyClosed,
    pruneStaleAttendees, bindLogicalIdentity, normalizeRoomCode, normalizeDeviceId,
    normalizeDisplayName, normalizeUserId, parseRole, parseRoomMode,
    creatorRoleForMode, joinRoleForRoom, generateRoomCode, engineProviderForSelection,
    publicProviderId, exposeVendorResponse, registerRoom, assertRole,
    closeRoom, closeRoomUnlocked, contractError, sendProviderError,
    mediaManagementCapabilities, chatManagementCapabilities, logEvent,
    requireSameOrigin, requireAdmin,
  } = dependencies;
  const provisionRoom = createRoomProvisioner({
    chatProviderRegistry,
    publicProviderId,
    mediaManagementCapabilities,
    registerRoom,
    logEvent,
  });


app.post('/rooms', async (req, res) => {
  try {
    let roomCode = normalizeRoomCode(req.body?.roomCode);
    if (req.body?.roomCode && !roomCode) {
      return contractError(res, 400, 'bad-room-code', 'roomCode must be 4-12 letters/digits.');
    }
    if (roomCode && roomDirectory.has(roomCode)) {
      return contractError(res, 409, 'room-exists', 'The room code is already in use.');
    }
    roomCode ??= generateRoomCode();

    const requestedRole = req.body?.role == null ? null : parseRole(req.body.role);
    if (req.body?.role != null && !requestedRole) {
      return contractError(res, 400, 'invalid-argument', 'role must be participant, host, or viewer.');
    }
    const requestedRoomMode = parseRoomMode(req.body?.roomMode);
    if (req.body?.roomMode != null && !requestedRoomMode) {
      return contractError(res, 400, 'invalid-argument', 'roomMode must be meeting or broadcast.');
    }
    const roomMode: RoomMode =
      requestedRoomMode ?? (requestedRole === 'host' || requestedRole === 'viewer' ? 'broadcast' : 'meeting');
    const derivedCreatorRole = creatorRoleForMode(roomMode);
    if (requestedRoomMode && requestedRole && requestedRole !== derivedCreatorRole) {
      return contractError(
        res,
        400,
        'invalid-argument',
        `role is assigned by roomMode; ${roomMode} rooms are created as ${derivedCreatorRole}.`,
      );
    }
    const role = requestedRoomMode ? derivedCreatorRole : requestedRole ?? derivedCreatorRole;
    const deviceId = normalizeDeviceId(req.body?.deviceId);
    if (req.body?.deviceId != null && !deviceId) {
      return contractError(
        res,
        400,
        'invalid-argument',
        'deviceId must be 8-128 letters, digits, dots, underscores, colons, or hyphens.',
      );
    }

    const provider = engineProviderForSelection(currentProvider(), roomMode);
    assertRole(provider, role);
    if (roomMode === 'broadcast') {
      assertRole(provider, 'viewer');
    }
    const rawNickname = req.body?.displayName?.trim() || req.body?.nickname?.trim() || null;
    const { created, roomOwnerCredential } = await provisionRoom({
      roomCode, roomMode, role, provider,
      selectedChatProvider: currentChatProvider(),
    });

    return await withRoomOperation(created.entry, async () => {
      assertRoomOpen(created.entry);
      if (!rawNickname) return res.json(exposeVendorResponse(created.response));

      const userId = normalizeUserId(
        req.body?.userId ?? deviceId ?? rawNickname,
      );
      if (roomMode === 'meeting') created.entry.classroomTeacherUserId = userId;
      const response = await provider.joinRoom({
        entry: created.entry,
        rawName: rawNickname,
        role,
        userId,
        deviceId,
        classroomMicrophoneAllowed: true,
    });
    if (created.entry.chatProvider) response.chatProvider = created.entry.chatProvider;
    response.roomMode = roomMode;
    if (roomMode === 'broadcast') response.liveInteractions = true;
    if (roomOwnerCredential) {
      response.roomOwnerCredential = roomOwnerCredential;
    }
    bindLogicalIdentity(
      created.entry,
      response.participantId,
      userId,
      rawNickname,
      deviceId,
      'host',
    );
    response.participantCredential = issueParticipantCredential(
      created.entry,
      response.participantId,
    );
    roomDirectory.flush();
    if (roomMode === 'meeting') {
      classroomDirectory.snapshot(created.entry, true, userId);
    }
    logEvent('join', `${response.displayName} created+joined room ${roomCode} via ${provider.displayName}`);
    res.json(exposeVendorResponse(response));
    });
  } catch (error) {
    if (sendProviderError(res, error) !== false) return;
    console.error('create room failed', error);
    const name = error instanceof Error ? error.name : String(error);
    logEvent('error', `create room failed: ${name}`);
    contractError(res, 500, 'create-room-failed', 'Unable to create the room.');
  }
});

app.post('/rooms/:code/join', async (req, res) => {
  try {
    const entry = await resolveRoom(req.params.code);
    if (!entry) {
      logEvent('error', `join ${req.params.code} failed: not found`);
      return contractError(res, 404, 'room-not-found', 'The requested room was not found.');
    }
    return await withRoomOperation(entry, async () => {
      assertRoomOpen(entry);
      if (isRoomPartiallyClosed(entry)) {
        return contractError(
          res,
          409,
          'room-closing',
          'The room is partially closed and is waiting for cleanup retry.',
        );
      }
      const provider = providerRegistry.requireConfigured(entry.provider);
      const deviceId = normalizeDeviceId(req.body?.deviceId);
      if (req.body?.deviceId != null && !deviceId) {
        return contractError(
          res,
          400,
          'invalid-argument',
          'deviceId must be 8-128 letters, digits, dots, underscores, colons, or hyphens.',
        );
      }
      const displayName = normalizeDisplayName(
        req.body?.displayName ?? req.body?.nickname ?? req.body?.userId,
      );
      if (!displayName) {
        return contractError(res, 400, 'invalid-argument', 'displayName or userId is required.');
      }
      const userId = normalizeUserId(req.body?.userId ?? deviceId ?? displayName);
      const requestedRole = req.body?.role == null ? null : parseRole(req.body.role);
      if (req.body?.role != null && !requestedRole) {
        return contractError(res, 400, 'invalid-argument', 'role must be participant, host, or viewer.');
      }
      const role = entry.roomMode
        ? joinRoleForRoom(entry, req.body?.roomOwnerCredential)
        : requestedRole ?? 'participant';
      assertRole(provider, role, entry);
      if (entry.roomMode === 'meeting') {
        const previous = new Set(entry.attendees.filter(person =>
          person.userId !== entry.classroomTeacherUserId && person.role !== 'host' &&
          (person.userId === userId || (deviceId && person.deviceId === deviceId)))
          .map(person => person.attendeeId));
        // Losing the reference heartbeat is not proof the RTC stream stopped.
        const remembered = classroomDirectory.previousParticipantId(entry, userId);
        if (remembered && userId !== entry.classroomTeacherUserId) previous.add(remembered);
        for (const participantId of previous) {
          if (provider.setClassroomMicrophonePermission) {
            try {
              await provider.setClassroomMicrophonePermission(entry, participantId, false);
            } catch {
              throw new ProviderOperationError(502, 'classroom-control-failed',
                'Unable to revoke the previous participant microphone. Please retry joining.');
            }
          }
          classroomDirectory.resetParticipant(entry, participantId);
        }
      }
      const response = await provider.joinRoom({
        entry,
        rawName: displayName,
        role,
        userId,
        deviceId,
        classroomMicrophoneAllowed: entry.roomMode !== 'meeting' ||
          Boolean(
            String(req.body?.roomOwnerCredential ?? '').trim() &&
            matchesRoomOwnerCredential(entry, String(req.body.roomOwnerCredential).trim()),
          ),
    });
    if (entry.chatProvider) response.chatProvider = entry.chatProvider;
    if (entry.roomMode) response.roomMode = entry.roomMode;
    if (entry.roomMode === 'broadcast') response.liveInteractions = true;
    response.management = mediaManagementCapabilities(provider);
    const presentedOwnerCredential = String(
      req.body?.roomOwnerCredential ?? '',
    ).trim();
    if (
      presentedOwnerCredential &&
      matchesRoomOwnerCredential(entry, presentedOwnerCredential)
    ) {
      response.roomOwnerCredential = presentedOwnerCredential;
      if (entry.roomMode === 'meeting') entry.classroomTeacherUserId = userId;
    }
    bindLogicalIdentity(
      entry,
      response.participantId,
      userId,
      displayName,
      deviceId,
      role,
    );
    response.participantCredential = issueParticipantCredential(
      entry,
      response.participantId,
    );
    roomDirectory.flush();
    if (entry.roomMode === 'meeting') {
      classroomDirectory.snapshot(
        entry, Boolean(response.roomOwnerCredential), userId,
      );
    }
    logEvent('join', `${response.displayName} joined room ${entry.roomCode} via ${provider.displayName}`);
    res.json(exposeVendorResponse(response));
    });
  } catch (error) {
    if (sendProviderError(res, error) !== false) return;
    console.error('room join failed', error);
    const name = error instanceof Error ? error.name : String(error);
    logEvent('error', `join room failed: ${name}`);
    contractError(res, 500, 'join-failed', 'Unable to join the room.');
  }
});

app.post('/rooms/:code/chat/token', async (req, res) => {
  try {
    const entry = await resolveRoom(req.params.code);
    if (!entry) {
      return contractError(res, 404, 'room-not-found', 'The requested room was not found.');
    }
    if (isRoomPartiallyClosed(entry)) {
      return contractError(
        res,
        409,
        'room-closing',
        'The room is partially closed and cannot issue chat credentials.',
      );
    }
    if (!entry.chatProvider || !entry.chatRoomArn) {
      return contractError(
        res,
        400,
        'unsupported-feature',
        'This room does not have a chat provider.',
      );
    }
    const participantId = String(req.body?.participantId ?? '').trim();
    if (!participantId) {
      return contractError(res, 400, 'invalid-argument', 'participantId is required.');
    }
    pruneStaleAttendees(entry, Date.now());
    const attendee = requireParticipantCredential(
      entry,
      participantId,
      req.body?.participantCredential,
    );
    if (attendee.chatRemoved) {
      return contractError(
        res,
        403,
        'forbidden',
        'This participant has been removed from the attached chat.',
      );
    }
    const ownerCredential = String(
      req.body?.roomOwnerCredential ?? '',
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
    res.json({
      ...response,
      participantCredential: String(
        req.body?.participantCredential ?? '',
      ).trim(),
      roomOwnerCredential: ownerCredential,
      context: 'attached',
      management: chatManagementCapabilities(chatProvider, canManageChat),
    });
  } catch (error) {
    if (sendProviderError(res, error) !== false) return;
    console.error('chat token failed', error);
    contractError(res, 500, 'chat-token-failed', 'Unable to issue chat credentials.');
  }
});

app.post('/rooms/:code/credentials/refresh', async (req, res) => {
  try {
    const entry = await resolveRoom(req.params.code);
    if (!entry) return contractError(res, 404, 'room-not-found', 'The requested room was not found.');
    if (isRoomPartiallyClosed(entry)) {
      return contractError(
        res,
        409,
        'room-closing',
        'The room is partially closed and cannot refresh credentials.',
      );
    }
    const participantId = String(req.body?.participantId ?? '').trim();
    if (!participantId) {
      return contractError(res, 400, 'invalid-argument', 'participantId is required.');
    }
    pruneStaleAttendees(entry, Date.now());
    const attendee = requireParticipantCredential(
      entry,
      participantId,
      req.body?.participantCredential,
    );
    const role = attendee.role ?? 'participant';
    const requestedRole = req.body?.role == null ? null : parseRole(req.body.role);
    if (req.body?.role != null && requestedRole == null) {
      return contractError(res, 400, 'invalid-argument', 'role must be participant, host, or viewer.');
    }
    if (requestedRole != null && requestedRole !== role) {
      return contractError(
        res,
        403,
        'forbidden',
        'Credential refresh cannot change the participant role.',
      );
    }
    const provider = providerRegistry.requireConfigured(entry.provider);
    if (typeof provider.refreshCredentials !== 'function') {
      return contractError(
        res,
        400,
        'unsupported-provider',
        'Credential refresh is not supported by this room provider.',
      );
    }
    const response = await provider.refreshCredentials({ entry, participantId, role });
    res.json(exposeVendorResponse(response));
  } catch (error) {
    if (sendProviderError(res, error) !== false) return;
    console.error('credential refresh failed', error);
    contractError(res, 500, 'credential-refresh-failed', 'Unable to refresh provider credentials.');
  }
});

app.post('/rooms/:code/heartbeat', async (req, res) => {
  const entry = await resolveRoom(req.params.code);
  if (!entry) return contractError(res, 404, 'room-not-found', 'The requested room was not found.');
  const participantId = String(req.body?.participantId ?? '').trim();
  if (participantId) {
    const attendee = entry.attendees.find((item) => item.attendeeId === participantId);
    if (!attendee) {
      return contractError(
        res,
        404,
        'participant-not-found',
        'The participant is no longer registered in this room.',
      );
    }
    attendee.lastHeartbeatMs = Date.now();
  }
  entry.lastHeartbeatMs = Date.now();
  res.json({ contractVersion: contractVersion, ok: true, roomCode: entry.roomCode });
});

app.post('/rooms/:code/leave', async (req, res) => {
  try {
    const entry = await resolveRoom(req.params.code);
    if (!entry) return contractError(res, 404, 'room-not-found', 'The requested room was not found.');
    return await withRoomOperation(entry, async () => {
      const provider = providerRegistry.require(entry.provider);
      const who = req.body?.participantId ?? req.body?.attendeeId ?? req.body?.userId ?? 'someone';
      const result = typeof provider.removeAttendee === 'function'
        ? provider.removeAttendee(entry, who)
        : { removed: false, closeWhenEmpty: false };
      if (result.closeWhenEmpty) {
        await closeRoomUnlocked(entry, 'last attendee left');
        return res.json({ contractVersion: contractVersion, ok: true, roomCode: entry.roomCode, closed: true });
      }
      if (entry.roomMode === 'meeting') classroomDirectory.snapshot(entry, false);
      logEvent('leave', `${who} left room ${entry.roomCode} (auto-close in ~90s if empty)`);
      res.json({ contractVersion: contractVersion, ok: true, roomCode: entry.roomCode });
    });
  } catch (error) {
    if (sendProviderError(res, error) !== false) return;
    console.error('leave failed', error);
    contractError(res, 500, 'leave-failed', 'Unable to leave the room.');
  }
});

app.post('/rooms/:code/participants', async (req, res) => {
  const entry = await resolveRoom(req.params.code);
  if (!entry) {
    return contractError(res, 404, 'room-not-found', 'The requested room was not found.');
  }
  if (!requireRoomManager(
    entry,
    req.body?.requesterParticipantId,
    req.body?.participantCredential,
    req.body?.roomOwnerCredential,
  )) {
    return contractError(res, 403, 'forbidden', 'Host permission is required.');
  }
  res.json({
    contractVersion: contractVersion,
    roomCode: entry.roomCode,
    participants: entry.attendees.map((attendee) => ({
      participantId: attendee.attendeeId,
      userId: attendee.userId ?? attendee.externalUserId,
      displayName: attendee.displayName ?? attendee.externalUserId,
      role: attendee.role ?? 'participant',
      joinedAt: attendee.joinedAt,
    })),
  });
});

app.post('/rooms/:code/participants/remove', async (req, res) => {
  try {
    const entry = await resolveRoom(req.params.code);
    if (!entry) {
      return contractError(res, 404, 'room-not-found', 'The requested room was not found.');
    }
    return await withRoomOperation(entry, async () => {
      assertRoomOpen(entry);
      const host = requireRoomManager(
        entry,
        req.body?.requesterParticipantId,
        req.body?.participantCredential,
        req.body?.roomOwnerCredential,
      );
      if (!host) {
        return contractError(res, 403, 'forbidden', 'Host permission is required.');
      }
      const targetParticipantId = String(req.body?.targetParticipantId ?? '').trim();
      if (!targetParticipantId) {
        return contractError(res, 400, 'invalid-argument', 'targetParticipantId is required.');
      }
      if (host.attendeeId === targetParticipantId) {
        return contractError(res, 400, 'invalid-argument', 'Use leave or closeRoom for the host.');
      }
      const provider = providerRegistry.requireConfigured(entry.provider);
      if (typeof provider.moderateRemoveParticipant !== 'function') {
        return contractError(
          res,
          400,
          'unsupported-feature',
          'This provider does not support server-enforced participant removal.',
        );
      }
      const removed = await provider.moderateRemoveParticipant(entry, targetParticipantId);
      if (!removed) {
        return contractError(res, 404, 'participant-not-found', 'Participant was not found.');
      }
      if (entry.roomMode === 'meeting') classroomDirectory.snapshot(entry, false);
      logEvent('moderate', `${host.attendeeId} removed ${targetParticipantId} from room ${entry.roomCode}`);
      res.json({
        contractVersion: contractVersion,
        ok: true,
        roomCode: entry.roomCode,
        participantId: targetParticipantId,
    });
    });
  } catch (error) {
    if (sendProviderError(res, error) !== false) return;
    console.error('participant removal failed', error);
    contractError(res, 500, 'moderation-failed', 'Unable to remove the participant.');
  }
});

app.post('/rooms/:code/close', async (req, res) => {
  try {
    const entry = await resolveRoom(req.params.code);
    if (!entry) {
      return contractError(res, 404, 'room-not-found', 'The requested room was not found.');
    }
    return await withRoomOperation(entry, async () => {
      if (!requireRoomManager(
        entry,
        req.body?.requesterParticipantId,
        req.body?.participantCredential,
        req.body?.roomOwnerCredential,
      )) {
        return contractError(res, 403, 'forbidden', 'Host permission is required.');
      }
      await closeRoomUnlocked(entry, 'host close');
      res.json({
        contractVersion: contractVersion,
        ok: true,
        closed: true,
        roomCode: entry.roomCode,
    });
    });
  } catch (error) {
    if (sendProviderError(res, error) !== false) return;
    console.error('host room close failed', error);
    contractError(res, 500, 'close-failed', 'Unable to close the room.');
  }
});

app.delete('/rooms/:code', requireSameOrigin, requireAdmin, async (req, res) => {
  try {
    const entry = await resolveRoom(req.params.code);
    if (!entry) return contractError(res, 404, 'room-not-found', 'The requested room was not found.');
    await closeRoom(entry, 'force close');
    res.json({ contractVersion: contractVersion, deleted: true, roomCode: entry.roomCode });
  } catch (error) {
    if (sendProviderError(res, error) !== false) return;
    if (error instanceof Error && error.name === 'NotFoundException') {
      const stale = roomDirectory.get(req.params.code);
      if (stale) roomDirectory.remove(stale);
      return contractError(res, 404, 'room-not-found', 'The requested room was not found.');
    }
    console.error('room delete failed', error);
    contractError(res, 500, 'delete-failed', 'Unable to close the room.');
  }
});


}
