import crypto from 'node:crypto';
import {
  mkdirSync, readFileSync, renameSync, rmSync, writeFileSync,
} from 'node:fs';
import path from 'node:path';
import type { RoomEntry } from '../types.ts';

export interface ClassroomStoredState {
  version: 1;
  revision: number;
  nextRaiseOrder?: number;
  handRaisesTotal?: number;
  raised: Array<[string, number]>;
  grants: string[];
  /** Grants are bound to a media participant, never just a public user ID. */
  grantParticipants?: Array<[string, string]>;
  questions: Array<[string, {
    id: string; userId: string; displayName: string; text: string;
    status: 'pending' | 'answered' | 'resolved'; createdAt: string;
    answer?: string;
  }]>;
  handledIds: Array<[string, string]>;
  questionTimes: Array<[string, number[]]>;
  seenStudents: Array<[string, {
    userId: string; participantId: string; displayName: string; avatarUrl?: string;
    lastSeenMs: number; online: boolean;
  }]>;
  speakGrants: number;
  feedback?: Array<{
    id: string; userId: string; displayName: string; avatarUrl?: string;
    kind: 'understood' | 'great' | 'idea' | 'question' | 'clap';
    createdAt: string;
  }>;
  feedbackTimes?: Array<[string, number[]]>;
  notes?: Array<{
    id: string; text: string; kind: 'note' | 'chapter';
    authorUserId: string; createdAt: string; elapsedSeconds: number;
  }>;
}

/** Replaceable state adapter. For multiple app instances use a shared
 * transactional/CAS-backed implementation; FileClassroomStore is single-node. */
export interface ClassroomStore {
  load(entry: RoomEntry): ClassroomStoredState | null;
  save(entry: RoomEntry, state: ClassroomStoredState): void;
  delete?(entry: RoomEntry): void;
}

/** Optional single-host demo persistence, isolated by provider, room and
 * creation epoch to prevent reusing classroom data across recreated rooms. */
export class FileClassroomStore implements ClassroomStore {
  private readonly directory: string;
  constructor(directory: string) {
    this.directory = directory;
    mkdirSync(directory, { recursive: true, mode: 0o700 });
  }

  private filename(entry: RoomEntry): string {
    const identity = JSON.stringify([
      entry.provider, entry.roomCode, entry.createdAt,
    ]);
    return path.join(
      this.directory,
      crypto.createHash('sha256').update(identity).digest('hex') + '.json',
    );
  }

  load(entry: RoomEntry): ClassroomStoredState | null {
    let content: string;
    try {
      content = readFileSync(this.filename(entry), 'utf8');
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code === 'ENOENT') return null;
      throw error;
    }
    const persisted: unknown = JSON.parse(content);
    if (!persisted || typeof persisted !== 'object' ||
        !('version' in persisted) || persisted.version !== 1 ||
        !('revision' in persisted) ||
        !Number.isSafeInteger(persisted.revision)) {
      throw new Error('Invalid classroom persistence version or revision.');
    }
    return persisted as ClassroomStoredState;
  }

  save(entry: RoomEntry, state: ClassroomStoredState): void {
    const file = this.filename(entry);
    const tmp = file + '.' + crypto.randomUUID() + '.tmp';
    try {
      writeFileSync(tmp, JSON.stringify(state), { mode: 0o600, flag: 'wx' });
      renameSync(tmp, file);
    } finally {
      rmSync(tmp, { force: true });
    }
  }

  delete(entry: RoomEntry): void {
    rmSync(this.filename(entry), { force: true });
  }
}
