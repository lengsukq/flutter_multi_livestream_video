import crypto from 'node:crypto';
import type { RoomEntry, ChatRoomEntry, RoomAttendee, ChatProviderAdapter, MediaRole } from '../../types.ts';
import type { ChatRoomDirectory } from '../../chat/chat-room-directory.ts';
import type { ChatProviderRegistry } from '../../chat/chat-provider-registry.ts';
import { ProviderOperationError } from '../../providers/provider-registry.ts';
import { requireParticipantCredential, issueParticipantCredential } from '../../participant-credential.ts';
import { requireRoomManager } from '../../room-access.ts';

export interface ChatApplicationDependencies {

  chatRoomDirectory: ChatRoomDirectory;
  chatProviderRegistry: ChatProviderRegistry;
  currentChatProvider(): string | null;
  contractVersion: number;
  resolveRoom(ref: unknown): Promise<RoomEntry | null>;
  chatManagementCapabilities(provider: ChatProviderAdapter, canManage: boolean): {
    listMembers: boolean; removeMember: boolean; closeRoom: boolean; muteMember: boolean;
    banMember: boolean; recallMessage: boolean; manageRoles: boolean;
  };
  closeRoom(entry: RoomEntry, reason: string): Promise<void>;
  normalizeUserId(raw: unknown): string;
  normalizeDisplayName(raw: unknown): string;
  generateRoomCode(): string;
  logEvent(type: string, message: string): void;
}
