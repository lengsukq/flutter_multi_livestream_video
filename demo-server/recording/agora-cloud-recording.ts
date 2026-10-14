import crypto from 'node:crypto';

import {buildAgoraRtcToken} from '../agora-token.ts';
import type {NamedRoomEntry} from '../types.ts';
import type {
  CloudRecordingExecutor, RecordingLayout, RecordingPreset,
} from './cloud-recording-executor.ts';
import {RecordingConfigurationError, RecordingProviderError} from './livekit-cloud-recording.ts';
import {
  s3RecordingReader, type RecordingObjectReader,
} from './s3-recording-storage.ts';

type State = 'starting' | 'recording' | 'processing' | 'completed' | 'failed';
type Job = {
  id: string; resourceId: string; uid: string; roomName: string;
  roomCode: string; layout: RecordingLayout; state: State;
  bucket: string; prefix: string[]; fileKey: string | null;
  stopped: boolean; error: string | null;
};

/**
 * Agora's hosted Cloud Recording REST service. Does not execute any recording
 * process in the Demo Server. S3 storage config is server-owned and optional
 * until real recording is requested.
 */
export class AgoraCloudRecording implements CloudRecordingExecutor {
  // Native floating video: highlights the first publisher, not voice activity.
  readonly supportedLayouts = ['grid', 'featuredParticipant'] as const;
  private readonly jobs = new Map<string, Job>();
  private readonly tickets = new Map<string, {roomCode: string; id: string; expires: number}>();
  private readonly appId: string;
  private readonly certificate: string;
  private readonly customerId: string;
  private readonly customerSecret: string;
  private readonly bucket: string;
  private readonly storageRegionCode: number;
  private readonly s3Region: string;
  private readonly accessKey: string;
  private readonly secretKey: string;
  private readonly transport: typeof fetch;
  private readonly objectReader: RecordingObjectReader;

  constructor(
    env: NodeJS.ProcessEnv = process.env,
    transport: typeof fetch = fetch,
    reader?: RecordingObjectReader,
  ) {
    this.appId = env.AGORA_APP_ID?.trim() ?? '';
    this.certificate = env.AGORA_APP_CERTIFICATE?.trim() ?? '';
    this.customerId = env.AGORA_CUSTOMER_ID?.trim() ?? '';
    this.customerSecret = env.AGORA_CUSTOMER_SECRET?.trim() ?? '';
    this.bucket = env.AGORA_RECORDING_S3_BUCKET?.trim() ?? '';
    this.s3Region = env.AGORA_RECORDING_S3_REGION?.trim() ?? '';
    this.storageRegionCode = Number(env.AGORA_RECORDING_S3_REGION_CODE ?? NaN);
    this.accessKey = env.AGORA_RECORDING_S3_ACCESS_KEY?.trim() ?? '';
    this.secretKey = env.AGORA_RECORDING_S3_SECRET_KEY?.trim() ?? '';
    this.transport = transport;
    this.objectReader = reader ?? s3RecordingReader({
      region: this.s3Region || 'us-east-1',
      accessKeyId: this.accessKey, secretAccessKey: this.secretKey,
    });
  }

  get configured(): boolean {
    return Boolean(
      /^[a-f0-9]{32}$/i.test(this.appId) &&
      this.certificate && this.customerId && this.customerSecret &&
      /^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$/.test(this.bucket) &&
      this.s3Region && this.accessKey && this.secretKey &&
      Number.isInteger(this.storageRegionCode) &&
      this.storageRegionCode >= 0 && this.storageRegionCode <= 100,
    );
  }

  readiness() {
    return this.configured ? {available: true} : {
      available: false,
      reason: 'Agora Cloud Recording needs AGORA_CUSTOMER_ID/SECRET and ' +
        'AGORA_RECORDING_S3_BUCKET/REGION/REGION_CODE/ACCESS_KEY/SECRET_KEY. ' +
        'Leave storage blank until ready; no Linux Recording SDK is needed.',
    };
  }

  private ensureConfigured() {
    if (!this.configured) throw new RecordingConfigurationError(this.readiness().reason ??
      'Agora Cloud Recording is not configured.');
  }

  private async call(method: 'GET' | 'POST', route: string, payload?: object) {
    this.ensureConfigured();
    const response = await this.transport(
      `https://api.agora.io/v1/apps/${this.appId}/cloud_recording/${route}`,
      {
        method,
        headers: {
          Authorization: 'Basic ' + Buffer.from(
            `${this.customerId}:${this.customerSecret}`,
          ).toString('base64'),
          'Content-Type': 'application/json',
        },
        ...(payload ? {body: JSON.stringify(payload)} : {}),
        redirect: 'error',
        signal: AbortSignal.timeout(15_000),
      },
    );
    if (!response.ok) throw new RecordingProviderError(
      `Agora Cloud Recording ${method} ${route.split('/').at(-1)} failed (HTTP ${response.status}).`,
    );
    const data: unknown = await response.json();
    if (!data || typeof data !== 'object' || Array.isArray(data)) {
      throw new RecordingProviderError('Agora Cloud Recording returned invalid JSON.');
    }
    return data as Record<string, unknown>;
  }

  private view(job: Job) {
    return {
      provider: 'agora', recordingId: job.id, state: job.state,
      layout: job.layout, canDownload: job.state === 'completed' && Boolean(job.fileKey),
      fileName: job.fileKey?.split('/').at(-1) ?? null,
      fileSizeBytes: 0, error: job.error,
    };
  }

  async start(room: NamedRoomEntry, layout: RecordingLayout, preset: RecordingPreset) {
    this.ensureConfigured();
    if (!room.providerRoomName) throw new RecordingProviderError('Agora channel is missing.');
    const existing = this.jobs.get(room.roomCode);
    if (existing && !['completed', 'failed'].includes(existing.state)) {
      throw new RecordingProviderError('Another Agora cloud recording is active.');
    }
    const uid = String(crypto.randomInt(1, 0x7fffffff));
    const prefix = ['flutter-realtime-demo', crypto.randomUUID()];
    const job: Job = {
      id: '', resourceId: '', uid, roomName: room.providerRoomName, roomCode: room.roomCode,
      layout, state: 'starting', bucket: this.bucket, prefix, fileKey: null,
      stopped: false, error: null,
    };
    this.jobs.set(room.roomCode, job);
    try {
      const acquired = await this.call('POST', 'acquire', {
        cname: job.roomName, uid, clientRequest: {},
      });
      if (typeof acquired.resourceId !== 'string' || !acquired.resourceId) {
        throw new RecordingProviderError('Agora acquire did not return resourceId.');
      }
      job.resourceId = acquired.resourceId;
      const token = buildAgoraRtcToken({
        appId: this.appId, appCertificate: this.certificate,
        channelName: job.roomName, uid: Number(uid), role: 'viewer',
        ttlSeconds: 24 * 60 * 60,
      });
      // Agora's REST path uses composite; the recording service does mixing.
      const response = await this.call('POST',
        `resourceid/${encodeURIComponent(job.resourceId)}/mode/composite/start`, {
          cname: job.roomName, uid,
          clientRequest: {
            token,
            recordingConfig: {
              channelType: 1,
              streamTypes: 2,
              maxIdleTime: 30,
              audioProfile: 1,
              videoStreamType: 0,
              subscribeAudioUids: ['#allstream#'],
              subscribeVideoUids: ['#allstream#'],
              transcodingConfig: {
                width: preset === 'H264_1080P_30' ? 1920 : 1280,
                height: preset === 'H264_1080P_30' ? 1080 : 720,
                fps: 30,
                bitrate: preset === 'H264_1080P_30' ? 4000 : 1800,
                // 1 = Agora's adaptive grid, 0 = floating layout.
                // Neither mode guarantees active-speaker detection.
                mixedVideoLayout: layout === 'speaker' ? 0 : 1,
                backgroundColor: '#000000',
              },
            },
            // The Demo promises one downloadable MP4 containing both audio
            // and video; enabling HLS alongside MP4 can produce an MP4 whose
            // audio is emitted separately as AAC.
            recordingFileConfig: {avFileType: ['mp4']},
            storageConfig: {
              vendor: 1, region: this.storageRegionCode, bucket: this.bucket,
              accessKey: this.accessKey, secretKey: this.secretKey,
              fileNamePrefix: prefix,
            },
          },
        });
      if (typeof response.sid !== 'string' || !response.sid ||
          response.resourceId !== job.resourceId) {
        throw new RecordingProviderError('Agora start did not confirm the resource and sid.');
      }
      job.id = response.sid;
      job.state = 'recording';
      return this.view(job);
    } catch (error) {
      job.state = 'failed';
      job.error = 'Agora Cloud Recording did not start.';
      throw error;
    }
  }

  private route(job: Job, action: 'stop' | 'query') {
    return `resourceid/${encodeURIComponent(job.resourceId)}/sid/${encodeURIComponent(job.id)}/mode/composite/${action}`;
  }

  private applyFileList(job: Job, response: Record<string, unknown>) {
    const result = response.serverResponse as Record<string, unknown> | undefined;
    let files: unknown = result?.fileList;
    if (typeof files === 'string') {
      try { files = JSON.parse(files); } catch { files = []; }
    }
    if (!Array.isArray(files)) return;
    const file = files.find((entry: unknown) => {
      const name = entry && typeof entry === 'object'
        ? (entry as {fileName?: unknown}).fileName : null;
      return typeof name === 'string' && name.endsWith('.mp4') &&
        !name.split('/').some((piece) => !piece || piece === '.' || piece === '..');
    }) as {fileName: string} | undefined;
    if (!file) return;
    const name = file.fileName.replace(/^\/+/, '');
    const prefix = job.prefix.join('/');
    job.fileKey = name.startsWith(prefix + '/') ? name : `${prefix}/${name}`;
  }

  async stop(room: NamedRoomEntry) {
    const job = this.jobs.get(room.roomCode);
    if (!job?.id) throw new RecordingProviderError('No Agora cloud recording is active.');
    if (!job.stopped) {
      const response = await this.call('POST', this.route(job, 'stop'), {
        cname: job.roomName, uid: job.uid, clientRequest: {},
      });
      job.stopped = true;
      job.state = 'processing';
      this.applyFileList(job, response);
    }
    return this.status(room);
  }

  async status(room: NamedRoomEntry) {
    const job = this.jobs.get(room.roomCode);
    if (!job) return {
      provider: 'agora', recordingId: null, state: 'idle',
      layout: null, canDownload: false, fileName: null, fileSizeBytes: 0, error: null,
    };
    if (!job.stopped && job.id && job.state === 'recording') {
      const response = await this.call('GET', this.route(job, 'query'));
      this.applyFileList(job, response);
    }
    if (job.stopped && job.fileKey && job.state !== 'completed') {
      if (await this.objectReader.exists(job.bucket, job.fileKey)) job.state = 'completed';
    }
    return this.view(job);
  }

  async download(room: NamedRoomEntry) {
    const status = await this.status(room);
    const job = this.jobs.get(room.roomCode);
    if (!job || job.state !== 'completed' || !job.fileKey) {
      throw new RecordingProviderError('Agora MP4 has not yet been uploaded to S3.');
    }
    const ticket = crypto.randomBytes(32).toString('base64url');
    this.tickets.set(ticket, {roomCode: room.roomCode, id: job.id, expires: Date.now() + 60_000});
    return {
      ...status,
      downloadUrl: `/rooms/${encodeURIComponent(room.roomCode)}/recording/export/${ticket}`,
      expiresInSeconds: 60,
    };
  }

  async consumeExport(roomCode: string, ticket: string) {
    const item = this.tickets.get(ticket);
    this.tickets.delete(ticket);
    const job = this.jobs.get(roomCode);
    if (!item || !job || item.roomCode !== roomCode || item.id !== job.id ||
      item.expires < Date.now() || job.state !== 'completed' || !job.fileKey) {
      throw new RecordingProviderError('Recording download link is invalid or expired.');
    }
    const filename = job.fileKey.split('/').at(-1)!;
    return {
      kind: 'stream' as const,
      filename,
      body: await this.objectReader.open(job.bucket, job.fileKey),
      ...(this.objectReader.remove ? {afterDownload: async () => {
        await this.objectReader.remove!(job.bucket, job.fileKey!);
        job.fileKey = null;
      }} : {}),
    };
  }
}
