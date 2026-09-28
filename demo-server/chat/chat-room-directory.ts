import type { ChatRoomEntry } from '../types.ts';

export class ChatRoomDirectory {
  private readonly rooms = new Map<string, ChatRoomEntry>();

  get(roomCode: string): ChatRoomEntry | null {
    return this.rooms.get(roomCode.trim()) ?? null;
  }

  list(): ChatRoomEntry[] {
    return [...this.rooms.values()];
  }

  add(entry: ChatRoomEntry): ChatRoomEntry {
    this.rooms.set(entry.roomCode, entry);
    return entry;
  }

  remove(roomCode: string): ChatRoomEntry | null {
    const entry = this.get(roomCode);
    if (entry) this.rooms.delete(entry.roomCode);
    return entry;
  }
}
