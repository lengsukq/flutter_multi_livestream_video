import type { RoomEntry } from '../types.ts';

/** Serialize authoritative changes per room, including remote RTC calls. */
export class RoomOperationQueue {
  private readonly tails = new WeakMap<RoomEntry, Promise<void>>();

  isBusy(entry: RoomEntry): boolean { return this.tails.has(entry); }

  run<T>(entry: RoomEntry, operation: () => Promise<T> | T): Promise<T> {
    const result = (this.tails.get(entry) ?? Promise.resolve()).then(operation);
    const tail = result.then(() => {}, () => {});
    this.tails.set(entry, tail);
    void tail.then(() => {
      if (this.tails.get(entry) === tail) this.tails.delete(entry);
    });
    return result;
  }
}
