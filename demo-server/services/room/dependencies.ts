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

export interface RoomApplicationDependencies {

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
  mediaManagementCapabilities(provider: ProviderAdapter): {
    listParticipants: boolean; removeParticipant: boolean; closeRoom: boolean;
    muteParticipant: boolean; stopParticipantVideo: boolean; changeParticipantRole: boolean;
  };
  chatManagementCapabilities(provider: ChatProviderAdapter, canManage: boolean): {
    listMembers: boolean; removeMember: boolean; closeRoom: boolean; muteMember: boolean;
    banMember: boolean; recallMessage: boolean; manageRoles: boolean;
  };
  logEvent(type: string, message: string): void;
}
