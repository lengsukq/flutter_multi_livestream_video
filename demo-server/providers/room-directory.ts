import type { RoomEntry } from '../types.ts';

export class RoomDirectory {
  private readonly byCode: Map<string, RoomEntry>;
  private readonly aliasToCode: Map<string, string>;

  constructor() {
    this.byCode = new Map<string, RoomEntry>();
    this.aliasToCode = new Map<string, string>();
  }

  has(roomCode: unknown): boolean {
    return this.byCode.has(String(roomCode ?? '').trim());
  }

  get(ref: unknown): RoomEntry | null {
    const key = String(ref ?? '').trim();
    if (!key) return null;
    const direct = this.byCode.get(key);
    if (direct) return direct;
    const code = this.aliasToCode.get(key);
    return code ? this.byCode.get(code) ?? null : null;
  }

  register(entry: RoomEntry, aliases: string[] = []): RoomEntry {
    if (!entry?.roomCode || !entry?.provider) {
      throw new TypeError('Room entry requires roomCode and provider.');
    }
    this.byCode.set(entry.roomCode, entry);
    for (const alias of aliases) {
      const value = String(alias ?? '').trim();
      if (value) this.aliasToCode.set(value, entry.roomCode);
    }
    return entry;
  }

  addAlias(entry: RoomEntry, alias: unknown): void {
    const value = String(alias ?? '').trim();
    if (entry?.roomCode && value) this.aliasToCode.set(value, entry.roomCode);
  }

  remove(entryOrCode: RoomEntry | string): boolean {
    const entry = typeof entryOrCode === 'string' ? this.get(entryOrCode) : entryOrCode;
    if (!entry) return false;
    this.byCode.delete(entry.roomCode);
    for (const [alias, code] of this.aliasToCode.entries()) {
      if (code === entry.roomCode) this.aliasToCode.delete(alias);
    }
    return true;
  }

  entries(): RoomEntry[] {
    return [...this.byCode.values()];
  }

  get size(): number {
    return this.byCode.size;
  }
}
