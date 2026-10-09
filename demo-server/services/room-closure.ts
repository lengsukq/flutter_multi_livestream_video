import type { RoomEntry } from '../types.ts';
import type { ProviderRegistry } from '../providers/provider-registry.ts';
import type { ChatProviderRegistry } from '../chat/chat-provider-registry.ts';
import type { RoomDirectory } from '../providers/room-directory.ts';
import type { ClassroomStateDirectory } from '../classroom/classroom-state.ts';
import type { LiveInteractionDirectory } from '../live/live-interactions.ts';

export interface RoomClosureDependencies {
  providerRegistry: ProviderRegistry;
  chatProviderRegistry: ChatProviderRegistry;
  roomDirectory: RoomDirectory;
  classroomDirectory: ClassroomStateDirectory;
  liveInteractionDirectory: LiveInteractionDirectory;
  logEvent(type: string, message: string): void;
}

/**
 * Closes chat and media independently, preserving partially closed state for
 * a safe retry. Caller must hold the room operation queue lock.
 */
export function createRoomClosure(deps: RoomClosureDependencies) {
  const { providerRegistry, chatProviderRegistry, roomDirectory,
    classroomDirectory, liveInteractionDirectory, logEvent } = deps;
return async function closeRoomUnlocked(entry: RoomEntry, reason: string): Promise<void> {
  const provider = providerRegistry.require(entry.provider);
  entry.closePending = true;
  let chatError: unknown;
  if (entry.chatProvider && !entry.chatClosed) {
    try {
      await chatProviderRegistry.require(entry.chatProvider).closeRoom(entry);
      entry.chatClosed = true;
    } catch (error) {
      chatError = error;
    }
  }
  let mediaError: unknown;
  if (!entry.mediaClosed) {
    try {
      await provider.closeRoom({ entry, reason });
      entry.mediaClosed = true;
    } catch (error) {
      mediaError = error;
    }
  }
  if (mediaError || chatError) {
    logEvent(
      'error',
      `room ${entry.roomCode} close incomplete (${reason}); retry remains possible`,
    );
    if (mediaError) throw mediaError;
    throw chatError;
  }
  roomDirectory.remove(entry);
  classroomDirectory.forget(entry);
  liveInteractionDirectory.forget(entry);
  const suffix = entry.provider === 'chime' ? ' — billing for future joins stops' : '';
  logEvent('delete', `room ${entry.roomCode} closed (${reason})${suffix}`);
}

}
