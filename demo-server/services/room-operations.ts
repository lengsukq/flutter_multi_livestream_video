import type { Request } from 'express';
import type { RoomEntry, RoomSummary } from '../types.ts';
import { ProviderOperationError } from '../providers/provider-registry.ts';
import type { ProviderRegistry } from '../providers/provider-registry.ts';
import type { RoomDirectory } from '../providers/room-directory.ts';
import type { RoomOperationQueue } from '../classroom/room-operation-queue.ts';
import { AWS_VENDOR_ID, isAwsEngine, publicVendorForEngine } from '../providers/aws.ts';

export interface RoomOperationsDependencies {
  roomDirectory: RoomDirectory;
  providerRegistry: ProviderRegistry;
  roomOperations: RoomOperationQueue;
  participantStaleAfterMs: number;
  closeRoomUnlocked(entry: RoomEntry, reason: string): Promise<void>;
}

/** Room locking, lifecycle gates, membership expiry and public summaries. */
export function createRoomOperations(deps: RoomOperationsDependencies) {
  const {
    roomDirectory, providerRegistry, roomOperations,
    participantStaleAfterMs: PARTICIPANT_STALE_AFTER_MS, closeRoomUnlocked,
  } = deps;
  const publicProviderId = publicVendorForEngine;
function pruneStaleAttendees(entry: RoomEntry, now: number, insideOperation = false): void {
  // Dashboard reads must not replace membership during an awaited RTC update.
  if (!insideOperation && roomOperations.isBusy(entry)) return;
  entry.attendees = entry.attendees.filter((attendee) => {
    const lastSeen = attendee.lastHeartbeatMs;
    return lastSeen == null || now - lastSeen <= PARTICIPANT_STALE_AFTER_MS;
  });
}

function withRoomOperation<T>(entry: RoomEntry, operation: () => Promise<T> | T): Promise<T> {
  return roomOperations.run(entry, () => {
    if (roomDirectory.get(entry.roomCode) !== entry) {
      throw new ProviderOperationError(404, 'room-not-found', 'The requested room was not found.');
    }
    return operation();
  });
}

function assertRoomOpen(entry: RoomEntry): void {
  if (isRoomPartiallyClosed(entry)) {
    throw new ProviderOperationError(409, 'room-closing', 'The room is closing.');
  }
}

async function closeRoom(entry: RoomEntry, reason: string): Promise<void> {
  await withRoomOperation(entry, () => closeRoomUnlocked(entry, reason));
}

function summarizeRoom(entry: RoomEntry, req?: Request): RoomSummary {
  pruneStaleAttendees(entry, Date.now());
  const provider = providerRegistry.require(entry.provider);
  const host = req ? `${req.protocol}://${req.get('host')}` : '';
  const providerSummary = provider.summarizeRoom(entry, { host });
  return {
    ...providerSummary,
    provider: publicProviderId(entry.provider),
    ...(isAwsEngine(entry.provider)
      ? { vendor: AWS_VENDOR_ID, engine: entry.provider }
      : {}),
    attendees: providerSummary.attendees.map((attendee) => ({
      attendeeId: attendee.attendeeId,
      ...(attendee.providerParticipantId
        ? { providerParticipantId: attendee.providerParticipantId }
        : {}),
      externalUserId: attendee.externalUserId,
      ...(attendee.userId ? { userId: attendee.userId } : {}),
      ...(attendee.displayName ? { displayName: attendee.displayName } : {}),
      joinedAt: attendee.joinedAt,
      ...(attendee.lastHeartbeatMs != null
        ? { lastHeartbeatMs: attendee.lastHeartbeatMs }
        : {}),
      ...(attendee.role ? { role: attendee.role } : {}),
      ...(attendee.deviceId ? { deviceId: attendee.deviceId } : {}),
    })),
    ...(entry.roomMode ? { roomMode: entry.roomMode } : {}),
    ...(entry.chatProvider ? { chatProvider: entry.chatProvider } : {}),
  };
}

function isRoomPartiallyClosed(entry: RoomEntry): boolean {
  return (
    entry.closePending === true ||
    entry.mediaClosed === true ||
    entry.chatClosed === true
  );
}

return { pruneStaleAttendees, withRoomOperation, assertRoomOpen, closeRoom,
  summarizeRoom, isRoomPartiallyClosed };
}
