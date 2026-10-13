import crypto from 'node:crypto';
import {mkdirSync, readFileSync, renameSync, rmSync, writeFileSync} from 'node:fs';
import path from 'node:path';
import type {NamedRoomEntry} from '../types.ts';

/**
 * Optional, single-process Demo checkpoint store. Never stores access tokens,
 * S3 credentials or download tickets. Shared deployments need a DB instead.
 */
export class FileRecordingJobStore<T extends {id: string}> {
  private readonly directory: string | undefined;
  private readonly provider: 'chime' | 'ivs';
  constructor(
    directory: string | undefined,
    provider: 'chime' | 'ivs',
  ) {
    this.directory = directory;
    this.provider = provider;
    if (directory) mkdirSync(directory, {recursive: true, mode: 0o700});
  }

  private file(room: NamedRoomEntry): string {
    const identity = JSON.stringify([
      this.provider, room.roomCode, room.createdAt,
    ]);
    return path.join(this.directory!, crypto.createHash('sha256')
      .update(identity).digest('hex') + '.json');
  }

  load(room: NamedRoomEntry): T | null {
    if (!this.directory) return null;
    let raw: string;
    try {
      raw = readFileSync(this.file(room), 'utf8');
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code === 'ENOENT') return null;
      throw error;
    }
    const decoded: unknown = JSON.parse(raw);
    if (!decoded || typeof decoded !== 'object' || !('version' in decoded) ||
        decoded.version !== 1 || !('job' in decoded) || !decoded.job ||
        typeof decoded.job !== 'object' || !('id' in decoded.job) ||
        typeof decoded.job.id !== 'string') {
      throw new Error('Invalid persisted recording checkpoint.');
    }
    return decoded.job as T;
  }

  save(room: NamedRoomEntry, job: T): void {
    if (!this.directory) return;
    const file = this.file(room);
    const tmp = file + '.' + crypto.randomUUID() + '.tmp';
    try {
      writeFileSync(tmp, JSON.stringify({version: 1, job}),
        {mode: 0o600, flag: 'wx'});
      renameSync(tmp, file);
    } finally {
      rmSync(tmp, {force: true});
    }
  }
}
