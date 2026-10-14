import crypto from 'node:crypto';
import { promises as fs } from 'node:fs';
import path from 'node:path';
import {s3RecordingReader, type RecordingObjectReader} from './s3-recording-storage.ts';

import type { NamedRoomEntry } from '../types.ts';

type EgressState = 'starting' | 'recording' | 'processing' | 'completed' | 'failed';
type Layout = 'grid' | 'speaker';
type EncodingPreset = 'H264_720P_30' | 'H264_1080P_30';
type RemoteEgress = {
  egress_id?: string;
  room_name?: string;
  status?: string | number;
  error?: string;
  file_results?: Array<{filename?: string; location?: string; size?: string | number}>;
};
type Job = {
  id: string;
  roomName: string;
  state: EgressState;
  layout: Layout;
  fileKey: string | null;
  expectedKey: string;
  stopRequested: boolean;
  fileSize: number;
  observedSize: number;
  observedAt: number;
  error: string | null;
};

export class RecordingConfigurationError extends Error {}
export class RecordingProviderError extends Error {}

function b64(value: object) {
  return Buffer.from(JSON.stringify(value)).toString('base64url');
}

function recordingToken(apiKey: string, apiSecret: string): string {
  const now = Math.floor(Date.now() / 1000);
  const unsigned = `${b64({alg: 'HS256', typ: 'JWT'})}.${b64({
    iss: apiKey,
    sub: 'demo-cloud-recording',
    nbf: now - 5,
    exp: now + 180,
    video: {roomRecord: true},
  })}`;
  return `${unsigned}.${crypto.createHmac('sha256', apiSecret).update(unsigned).digest('base64url')}`;
}

function parseState(value: string | number | undefined): EgressState {
  const normalized = String(value ?? '').toUpperCase();
  if (normalized === 'EGRESS_COMPLETE' || normalized === '3') return 'completed';
  if (/FAILED|ABORTED|LIMIT_REACHED/.test(normalized) || ['4', '5', '6'].includes(normalized)) return 'failed';
  if (normalized === 'EGRESS_ACTIVE' || normalized === '1') return 'recording';
  if (normalized === 'EGRESS_ENDING' || normalized === '2') return 'processing';
  return 'starting';
}

/**
 * Server-side LiveKit Egress orchestrator. It must never trust caller-supplied
 * storage configuration, API endpoints, arbitrary egress IDs or output paths.
 * Room managers are authenticated by the HTTP route before invoking this.
 */
export class LiveKitCloudRecording {
  readonly supportedLayouts = ['grid', 'activeSpeaker'] as const;
  private readonly jobs = new Map<string, Job>();
  private readonly url: string;
  private readonly apiKey: string;
  private readonly apiSecret: string;
  private readonly egressOutputDir: string;
  private readonly exportDir: string;
  private readonly hosted: boolean;
  private readonly s3Bucket: string;
  private readonly s3Region: string;
  private readonly s3Key: string;
  private readonly s3Secret: string;
  private readonly reader: RecordingObjectReader;
  private readonly transport: typeof fetch;
  private readonly exportTickets = new Map<string, {roomCode: string; filename: string; expires: number}>();

  constructor(
    env: NodeJS.ProcessEnv = process.env,
    transport: typeof fetch = fetch,
    reader?: RecordingObjectReader,
  ) {
    this.transport = transport;
    this.url = env.LIVEKIT_URL?.trim() ?? '';
    this.apiKey = env.LIVEKIT_API_KEY?.trim() ?? '';
    this.apiSecret = env.LIVEKIT_API_SECRET?.trim() ?? '';
    this.egressOutputDir = env.LIVEKIT_EGRESS_OUTPUT_DIR?.trim() ?? '';
    this.exportDir = env.LIVEKIT_RECORDING_EXPORT_DIR?.trim() ?? '';
    this.hosted = env.LIVEKIT_RECORDING_MODE === 'cloud' ||
      (env.LIVEKIT_RECORDING_MODE !== 'local' &&
        !(this.egressOutputDir && this.exportDir));
    this.s3Bucket = env.LIVEKIT_RECORDING_S3_BUCKET?.trim() ?? '';
    this.s3Region = env.LIVEKIT_RECORDING_S3_REGION?.trim() ?? '';
    this.s3Key = env.LIVEKIT_RECORDING_S3_ACCESS_KEY?.trim() ?? '';
    this.s3Secret = env.LIVEKIT_RECORDING_S3_SECRET_KEY?.trim() ?? '';
    this.reader = reader ?? s3RecordingReader({
      region: this.s3Region || 'us-east-1',
      accessKeyId: this.s3Key, secretAccessKey: this.s3Secret,
    });
  }

  private async refreshRecordedFile(job: Job) {
    if (this.hosted) {
      if (job.stopRequested && job.state !== 'failed' && !job.fileKey &&
          await this.reader.exists(this.s3Bucket, job.expectedKey)) {
        job.fileKey = job.expectedKey;
        job.state = 'completed';
      }
      return;
    }
    await this.refreshLocalFile(job);
  }

  get configured(): boolean {
    return Boolean(
      this.url && this.apiKey && this.apiSecret &&
      (this.hosted
        ? Boolean(this.s3Bucket && this.s3Region && this.s3Key && this.s3Secret)
        : path.posix.isAbsolute(this.egressOutputDir) && path.isAbsolute(this.exportDir)),
    );
  }

  readiness() {
    return this.configured
      ? {available: true}
      : {available: false, reason: this.hosted
        ? 'LiveKit Cloud Egress needs LIVEKIT_RECORDING_S3_BUCKET/REGION/ACCESS_KEY/SECRET_KEY; bucket settings may remain blank until recording is enabled.'
        : 'Self-hosted LiveKit Egress needs shared recording directories.'};
  }

  private ensureConfigured() {
    if (!this.configured) throw new RecordingConfigurationError(
      this.readiness().reason ?? 'LiveKit Egress configuration is incomplete.',
    );
  }

  private async egress(method: 'StartEgress' | 'StopEgress' | 'ListEgress', payload: object): Promise<Record<string, unknown>> {
    this.ensureConfigured();
    const endpoint = new URL(this.url);
    if (endpoint.protocol === 'wss:') endpoint.protocol = 'https:';
    if (endpoint.protocol === 'ws:') endpoint.protocol = 'http:';
    if (endpoint.protocol !== 'https:' && endpoint.protocol !== 'http:') {
      throw new RecordingConfigurationError('Unsupported LiveKit server URL protocol.');
    }
    endpoint.pathname = `/twirp/livekit.Egress/${method}`;
    endpoint.search = '';
    const response = await this.transport(endpoint.toString(), {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${recordingToken(this.apiKey, this.apiSecret)}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
      signal: AbortSignal.timeout(15_000),
    });
    if (!response.ok) {
      throw new RecordingProviderError(`LiveKit Egress ${method} returned HTTP ${response.status}.`);
    }
    const data: unknown = await response.json();
    if (!data || typeof data !== 'object') {
      throw new RecordingProviderError('LiveKit Egress returned an invalid response.');
    }
    return data as Record<string, unknown>;
  }

  private job(room: NamedRoomEntry): Job | null {
    return this.jobs.get(room.roomCode) ?? null;
  }

  async start(
    room: NamedRoomEntry,
    layout: Layout,
    preset: EncodingPreset = 'H264_720P_30',
  ) {
    if (!['grid', 'speaker'].includes(layout)) {
      throw new RangeError('Only grid or speaker layouts are supported in V1.');
    }
    if (!['H264_720P_30', 'H264_1080P_30'].includes(preset)) {
      throw new RangeError('Unsupported cloud recording encoding preset.');
    }
    this.ensureConfigured();
    if (this.job(room) && !['completed', 'failed'].includes(this.job(room)!.state)) {
      throw new RecordingProviderError('A recording is already in progress in this room.');
    }
    const expectedKey = this.hosted
      ? `flutter-realtime-demo/${crypto.randomUUID()}.mp4`
      : `${crypto.randomUUID()}.mp4`;
    const payload = {
      room_name: room.providerRoomName,
      template: {layout},
      preset,
      outputs: [{
        file: {
          file_type: 'MP4',
          filepath: this.hosted ? expectedKey : path.posix.join(this.egressOutputDir, expectedKey),
        },
      }],
      ...(this.hosted ? {storage: {s3: {
        access_key: this.s3Key, secret: this.s3Secret,
        bucket: this.s3Bucket, region: this.s3Region,
      }}} : {}),
    };
    const response = await this.egress('StartEgress', payload) as RemoteEgress;
    if (!response.egress_id || response.room_name !== room.providerRoomName) {
      throw new RecordingProviderError('LiveKit did not confirm the expected room and recording id.');
    }
    const job: Job = {
      id: response.egress_id,
      roomName: room.providerRoomName,
      layout,
      state: parseState(response.status),
      fileKey: null,
      expectedKey,
      stopRequested: false,
      fileSize: 0,
      observedSize: 0,
      observedAt: 0,
      error: null,
    };
    this.jobs.set(room.roomCode, job);
    return this.view(job);
  }

  async stop(room: NamedRoomEntry) {
    const job = this.job(room);
    if (!job) throw new RecordingProviderError('No cloud recording exists for this room.');
    if (job.state === 'completed' || job.state === 'failed') return this.view(job);
    job.stopRequested = true;
    const remote = await this.egress('StopEgress', {egress_id: job.id}) as RemoteEgress;
    job.state = 'processing';
    this.applyRemote(job, remote);
    await this.refreshRecordedFile(job);
    return this.view(job);
  }

  async status(room: NamedRoomEntry) {
    const job = this.job(room);
    if (!job) return {
      provider: 'livekit', recordingId: null, state: 'idle',
      layout: null, canDownload: false, fileName: null,
      fileSizeBytes: 0, error: null,
    };
    if (job.state !== 'completed' && job.state !== 'failed') {
      // ListEgress intentionally omits completed tasks. After StopEgress,
      // the server-owned shared-volume path is the artifact locator.
      if (!job.stopRequested) {
        const response = await this.egress('ListEgress', {egress_id: job.id});
        const remote = (response.items as RemoteEgress[] | undefined)?.find(
          (candidate) => candidate.egress_id === job.id &&
            candidate.room_name === job.roomName,
        );
        if (remote) this.applyRemote(job, remote);
      }
      await this.refreshRecordedFile(job);
    }
    return this.view(job);
  }

  private applyRemote(job: Job, remote: RemoteEgress) {
    if (remote.egress_id !== job.id || remote.room_name !== job.roomName) return;
    job.state = parseState(remote.status);
    job.error = typeof remote.error === 'string' ? remote.error.slice(0, 240) : null;
    if (job.stopRequested && job.state !== 'failed') {
      job.state = 'processing';
    }
    if (job.state !== 'completed') return;
    // Never blindly trust filenames returned by the provider.
    job.state = 'processing';
  }

  private async refreshLocalFile(job: Job): Promise<void> {
    if (!job.stopRequested || job.state === 'failed' || job.fileKey) return;
    try {
      const filename = path.join(this.exportDir, job.expectedKey);
      const stats = await fs.lstat(filename);
      if (!stats.isFile() || stats.isSymbolicLink() || stats.size <= 128) return;
      if (stats.size !== job.observedSize) {
        job.observedSize = stats.size;
        job.observedAt = Date.now();
        return;
      }
      if (Date.now() - job.observedAt < 1500) return;
      // MP4's ftyp + moov boxes distinguish a finalized container from a
      // growing/empty recording, without loading large videos into memory.
      const handle = await fs.open(filename, 'r');
      let valid = false;
      try {
        const head = Buffer.alloc(Math.min(256 * 1024, stats.size));
        const tail = Buffer.alloc(Math.min(256 * 1024, stats.size));
        await handle.read(head, 0, head.length, 0);
        await handle.read(tail, 0, tail.length, stats.size - tail.length);
        valid = head.subarray(4, 8).toString('ascii') === 'ftyp' &&
          (head.includes(Buffer.from('moov')) || tail.includes(Buffer.from('moov')));
      } finally {
        await handle.close();
      }
      if (valid) {
        job.fileKey = job.expectedKey;
        job.fileSize = stats.size;
        job.state = 'completed';
      }
    } catch (error) {
      // The Egress worker may still be finalizing its local MP4.
      if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error;
    }
  }

  async download(room: NamedRoomEntry) {
    await this.status(room);
    const job = this.job(room);
    if (!job || job.state !== 'completed' || !job.fileKey) {
      throw new RecordingProviderError('The cloud recording has not completed with a valid MP4 file.');
    }
    const ticket = crypto.randomBytes(32).toString('base64url');
    this.exportTickets.set(ticket, {
      roomCode: room.roomCode,
      filename: job.fileKey,
      expires: Date.now() + 60_000,
    });
    const downloadUrl =
      `/rooms/${encodeURIComponent(room.roomCode)}/recording/export/${ticket}`;
    return {...this.view(job), downloadUrl, expiresInSeconds: 60};
  }

  async consumeExport(roomCode: string, ticket: string) {
    const item = this.exportTickets.get(ticket);
    this.exportTickets.delete(ticket); // single use; no authentication in GET URL
    const job = this.jobs.get(roomCode);
    if (!item || !job || item.roomCode !== roomCode ||
        item.expires < Date.now() || job.state !== 'completed' ||
        job.fileKey !== item.filename) {
      throw new RecordingProviderError('Download link is invalid or has expired.');
    }
    const filename = path.basename(item.filename);
    if (!/^[0-9a-f-]{36}\.mp4$/.test(filename)) {
      throw new RecordingProviderError('Recording file name is invalid.');
    }
    if (this.hosted) {
      if (job.fileKey !== item.filename || !job.fileKey.startsWith('flutter-realtime-demo/')) {
        throw new RecordingProviderError('Recording storage key mismatch.');
      }
      return {
        kind: 'stream' as const, filename,
        body: await this.reader.open(this.s3Bucket, item.filename),
        ...(this.reader.remove ? {afterDownload: async () => {
          await this.reader.remove!(this.s3Bucket, item.filename);
          job.fileKey = null;
        }} : {}),
      };
    }
    const absolutePath = path.join(this.exportDir, filename);
    const stats = await fs.lstat(absolutePath);
    if (!stats.isFile() || stats.isSymbolicLink() || stats.size !== job.fileSize) {
      throw new RecordingProviderError('Completed recording file is unavailable.');
    }
    return {kind: 'local' as const, absolutePath, filename};
  }

  private view(job: Job) {
    return {
      provider: 'livekit',
      recordingId: job.id,
      state: job.state,
      layout: job.layout,
      canDownload: job.state === 'completed' && Boolean(job.fileKey),
      fileName: job.fileKey?.split('/').at(-1) ?? null,
      fileSizeBytes: job.fileSize,
      error: job.error,
    };
  }
}
