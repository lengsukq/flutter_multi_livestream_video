import type { RoomEntry } from '../types.ts';

interface IdleRoomSweepDependencies {
  intervalMs: number;
  rooms(): Iterable<RoomEntry>;
  sweep(entry: RoomEntry): Promise<void>;
  reportError(entry: RoomEntry, error: unknown): void;
}

/** Explicit timer owner; importing or creating an app never starts a sweep. */
export function createIdleRoomSweeper(dependencies: IdleRoomSweepDependencies) {
  let timer: ReturnType<typeof setInterval> | null = null;
  const pending = new Set<Promise<void>>();
  let stopping: Promise<void> | null = null;
  function run(): void {
    for (const entry of dependencies.rooms()) {
      const operation = dependencies.sweep(entry).catch((error: unknown) => dependencies.reportError(entry, error));
      pending.add(operation);
      void operation.finally(() => pending.delete(operation));
    }
  }
  function start(): void {
    if (stopping) throw new Error('Room sweeper is stopping');
    timer ??= setInterval(run, dependencies.intervalMs);
  }
  function stop(): Promise<void> {
    return stopping ??= (async () => {
      if (timer) clearInterval(timer);
      timer = null;
      await Promise.allSettled([...pending]);
    })();
  }
  return { start, stop };
}
