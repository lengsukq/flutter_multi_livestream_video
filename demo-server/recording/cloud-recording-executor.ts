import type {NamedRoomEntry} from '../types.ts';

export type RecordingLayout = 'grid' | 'speaker';
export type RecordingPreset = 'H264_720P_30' | 'H264_1080P_30';

/** A recording backend is selected by the trusted room provider, never by Flutter. */
export interface CloudRecordingExecutor {
  /** Configuration preflight only; successful media recording is not implied. */
  readiness?(): Promise<{available: boolean; reason?: string}> | {available: boolean; reason?: string};
  start(room: NamedRoomEntry, layout: RecordingLayout, preset: RecordingPreset): Promise<unknown>;
  stop(room: NamedRoomEntry): Promise<unknown>;
  status(room: NamedRoomEntry): Promise<unknown>;
  download(room: NamedRoomEntry): Promise<unknown>;
  consumeExport(roomCode: string, ticket: string): Promise<RecordingExport>;
}

export type RecordingExport =
  | {kind: 'local'; absolutePath: string; filename: string}
  | {kind: 'remote'; url: string; filename: string}
  | {kind: 'stream'; body: AsyncIterable<Uint8Array>; filename: string; afterDownload?: () => Promise<void>};
