import crypto from 'node:crypto';

import {buildTrtcCredentials} from '../trtc-token.ts';
import type {NamedRoomEntry} from '../types.ts';
import type {
  CloudRecordingExecutor, RecordingLayout, RecordingPreset,
} from './cloud-recording-executor.ts';
import {RecordingConfigurationError, RecordingProviderError} from './livekit-cloud-recording.ts';
import {s3RecordingReader, type RecordingObjectReader} from './s3-recording-storage.ts';

const S3_PREFIX = ['flutter_realtime_demo', 'trtc'] as const;
type Storage = 'vod' | 's3';

type TrtcState = 'recording' | 'processing' | 'completed' | 'failed';
type Job = {
  id: string;
  roomName: string;
  state: TrtcState;
  layout: RecordingLayout;
  stopRequested: boolean;
  videoUrl: string | null;
  s3Key: string | null;
  storage: Storage;
  error: string | null;
};

/**
 * Mixed cloud recording supports Tencent VOD or native AWS S3 output.
 * Signed 311 (VOD) / 310 (S3) callbacks identify the exported artifact.
 */
export class TrtcCloudRecording implements CloudRecordingExecutor {
  private readonly jobs = new Map<string, Job>();
  private readonly tickets = new Map<string, {roomCode: string; jobId: string; expires: number}>();
  private readonly sdkAppId: number;
  private readonly sdkSecret: string;
  private readonly secretId: string;
  private readonly secretKey: string;
  private readonly callbackKey: string;
  private readonly allowedVodHosts: Set<string>;
  private readonly region: string;
  private readonly apiHost: string;
  private readonly transport: typeof fetch;
  private readonly storage: Storage;
  private readonly s3Bucket: string;
  private readonly s3Region: string;
  private readonly s3AccessKey: string;
  private readonly s3SecretKey: string;
  private readonly reader: RecordingObjectReader;

  constructor(env: NodeJS.ProcessEnv = process.env, transport: typeof fetch = fetch,
    reader?: RecordingObjectReader) {
    this.sdkAppId = Number(env.TRTC_SDK_APP_ID ?? 0);
    this.sdkSecret = env.TRTC_SDK_SECRET_KEY?.trim() ?? '';
    this.secretId = env.TENCENTCLOUD_SECRET_ID?.trim() ?? '';
    this.secretKey = env.TENCENTCLOUD_SECRET_KEY?.trim() ?? '';
    this.callbackKey = env.TRTC_RECORDING_CALLBACK_KEY?.trim() ?? '';
    this.allowedVodHosts = new Set(
      (env.TRTC_RECORDING_VOD_HOSTS ?? '').split(',').map((host) =>
        host.trim().toLowerCase()).filter(Boolean),
    );
    this.region = env.TRTC_RECORDING_REGION?.trim() || 'ap-guangzhou';
    this.apiHost = 'trtc.tencentcloudapi.com';
    this.transport = transport;
    this.storage = env.TRTC_RECORDING_STORAGE === 's3' ? 's3' : 'vod';
    this.s3Bucket = env.TRTC_RECORDING_S3_BUCKET?.trim() ?? '';
    this.s3Region = env.TRTC_RECORDING_S3_REGION?.trim() ?? '';
    this.s3AccessKey = env.TRTC_RECORDING_S3_ACCESS_KEY?.trim() ?? '';
    this.s3SecretKey = env.TRTC_RECORDING_S3_SECRET_KEY?.trim() ?? '';
    this.reader = reader ?? s3RecordingReader({
      region: this.s3Region || 'us-east-1',
      accessKeyId: this.s3AccessKey, secretAccessKey: this.s3SecretKey,
    });
  }

  readiness() {
    return this.configured
      ? {available: true}
      : {available: false, reason: this.configurationReason()};
  }

  get configured(): boolean {
    return Number.isSafeInteger(this.sdkAppId) && this.sdkAppId > 0 &&
      Boolean(this.sdkSecret && this.secretId && this.secretKey && this.callbackKey) &&
      (this.storage === 'vod' ? this.allowedVodHosts.size > 0 : Boolean(
        this.s3Bucket && this.s3Region && this.s3AccessKey && this.s3SecretKey)) &&
      ['ap-beijing', 'ap-guangzhou', 'ap-shanghai'].includes(this.region);
  }

  private configurationReason(): string {
    const storage = this.storage === 's3'
      ? 'TRTC_RECORDING_S3_BUCKET/REGION/ACCESS_KEY/SECRET_KEY'
      : 'TRTC_RECORDING_VOD_HOSTS';
    return 'TRTC cloud recording requires TRTC_SDK_APP_ID/SECRET_KEY, ' +
      'TENCENTCLOUD_SECRET_ID/SECRET_KEY, TRTC_RECORDING_CALLBACK_KEY, ' +
      storage + ' and a supported TRTC_RECORDING_REGION.';
  }

  private ensureConfigured(): void {
    if (!this.configured) throw new RecordingConfigurationError(
      this.configurationReason(),
    );
  }

  private async call(action: string, payload: object): Promise<Record<string, unknown>> {
    this.ensureConfigured();
    const body = JSON.stringify(payload);
    const timestamp = Math.floor(Date.now() / 1000);
    const date = new Date(timestamp * 1000).toISOString().slice(0, 10);
    const contentType = 'application/json; charset=utf-8';
    const canonicalHeaders = `content-type:${contentType}\nhost:${this.apiHost}\nx-tc-action:${action.toLowerCase()}\n`;
    const canonicalRequest = [
      'POST', '/', '', canonicalHeaders, 'content-type;host;x-tc-action',
      crypto.createHash('sha256').update(body).digest('hex'),
    ].join('\n');
    const scope = `${date}/trtc/tc3_request`;
    const stringToSign = [
      'TC3-HMAC-SHA256', String(timestamp), scope,
      crypto.createHash('sha256').update(canonicalRequest).digest('hex'),
    ].join('\n');
    const hmac = (key: Buffer | string, data: string) =>
      crypto.createHmac('sha256', key).update(data).digest();
    const secretDate = hmac(`TC3${this.secretKey}`, date);
    const secretService = hmac(secretDate, 'trtc');
    const secretSigning = hmac(secretService, 'tc3_request');
    const signature = crypto.createHmac('sha256', secretSigning)
      .update(stringToSign).digest('hex');
    const authorization = `TC3-HMAC-SHA256 Credential=${this.secretId}/${scope}, SignedHeaders=content-type;host;x-tc-action, Signature=${signature}`;
    const response = await this.transport(`https://${this.apiHost}`, {
      method: 'POST',
      headers: {
        Authorization: authorization, 'Content-Type': contentType,
        Host: this.apiHost, 'X-TC-Action': action,
        'X-TC-Version': '2019-07-22', 'X-TC-Region': this.region,
        'X-TC-Timestamp': String(timestamp),
      },
      body, signal: AbortSignal.timeout(15_000),
    });
    if (!response.ok) throw new RecordingProviderError(
      `TRTC ${action} returned HTTP ${response.status}.`);
    const data: unknown = await response.json();
    if (!data || typeof data !== 'object' || !('Response' in data)) {
      throw new RecordingProviderError('TRTC returned an invalid API response.');
    }
    const detail = (data as {Response: Record<string, unknown>}).Response;
    if (detail?.Error) {
      throw new RecordingProviderError(`TRTC ${action} rejected the request.`);
    }
    return detail;
  }

  private view(job: Job) {
    const canDownload = job.state === 'completed' && Boolean(job.videoUrl || job.s3Key);
    return {
      provider: 'trtc', recordingId: job.id, state: job.state,
      layout: job.layout, canDownload,
      fileName: canDownload ? `trtc-${job.id.replace(/[^a-zA-Z0-9-]/g, '').slice(0, 48)}.mp4` : null,
      fileSizeBytes: 0, error: job.error,
    };
  }

  async start(room: NamedRoomEntry, layout: RecordingLayout, _preset: RecordingPreset) {
    this.ensureConfigured();
    const active = this.jobs.get(room.roomCode);
    if (active && active.state !== 'completed' && active.state !== 'failed') {
      throw new RecordingProviderError('A cloud recording is already running.');
    }
    const userId = `rec_${crypto.randomBytes(10).toString('hex')}`;
    const credentials = buildTrtcCredentials({
      sdkAppId: this.sdkAppId, secretKey: this.sdkSecret,
      userId, strRoomId: room.providerRoomName,
      ttlSeconds: 24 * 60 * 60, role: 'host',
    });
    const response = await this.call('CreateCloudRecording', {
      SdkAppId: this.sdkAppId, RoomId: room.providerRoomName,
      // All Demo TRTC provider room IDs are strings (media-<roomCode>).
      RoomIdType: 0, UserId: userId, UserSig: credentials.userSig,
      RecordParams: {RecordMode: 2, StreamType: 0, MaxIdleTime: 60},
      MixTranscodeParams: {
        VideoParams: {Width: 1280, Height: 720, Fps: 15, BitRate: 1500000, Gop: 10},
      },
      MixLayoutParams: {MixLayoutMode: layout === 'speaker' ? 1 : 3},
      StorageParams: this.storage === 'vod'
        ? {CloudVod: {TencentVod: {ExpireTime: 0}}}
        : {CloudStorage: {
          Vendor: 1, Region: this.s3Region, Bucket: this.s3Bucket,
          AccessKey: this.s3AccessKey, SecretKey: this.s3SecretKey,
          FileNamePrefix: [...S3_PREFIX],
        }},
    });
    if (typeof response.TaskId !== 'string' || !response.TaskId) {
      throw new RecordingProviderError('TRTC did not return a cloud recording TaskId.');
    }
    const job: Job = {
      id: response.TaskId, roomName: room.providerRoomName, state: 'recording',
      layout, stopRequested: false, videoUrl: null, s3Key: null,
      storage: this.storage, error: null,
    };
    this.jobs.set(room.roomCode, job);
    return this.view(job);
  }

  private async refreshS3(job: Job): Promise<void> {
    if (job.storage !== 's3' || !job.stopRequested || !job.s3Key ||
        job.state === 'failed' || job.state === 'completed') return;
    if (await this.reader.exists(this.s3Bucket, job.s3Key)) job.state = 'completed';
  }

  async stop(room: NamedRoomEntry) {
    const job = this.jobs.get(room.roomCode);
    if (!job) throw new RecordingProviderError('No cloud recording exists for this room.');
    if (!job.stopRequested) {
      await this.call('DeleteCloudRecording', {
        SdkAppId: this.sdkAppId, TaskId: job.id,
      });
      job.stopRequested = true;
      if (job.state !== 'failed') job.state = job.videoUrl ? 'completed' : 'processing';
    }
    await this.refreshS3(job);
    return this.view(job);
  }

  async status(room: NamedRoomEntry) {
    const job = this.jobs.get(room.roomCode);
    if (!job) return {
      provider: 'trtc', recordingId: null, state: 'idle', layout: null,
      canDownload: false, fileName: null, fileSizeBytes: 0, error: null,
    };
    if (!job.stopRequested && job.state === 'recording') {
      const response = await this.call('DescribeCloudRecording', {
        SdkAppId: this.sdkAppId, TaskId: job.id,
      });
      if (response.Status === 'Exited') job.state = 'processing';
    }
    await this.refreshS3(job);
    return this.view(job);
  }

  /**
   * Tencent sends Sign = base64(HMAC-SHA256(callbackKey, rawBody)).
   * Do not parse and reserialize the body before verifying the signature.
   */
  receiveCallback(rawBody: Buffer, sign: string, sdkAppId: string): boolean {
    if (!this.configured || sdkAppId !== String(this.sdkAppId) ||
        !sign || rawBody.length > 64 * 1024) return false;
    const actual = crypto.createHmac('sha256', this.callbackKey)
      .update(rawBody).digest();
    const supplied = Buffer.from(sign, 'base64');
    if (actual.length !== supplied.length || !crypto.timingSafeEqual(actual, supplied)) {
      return false;
    }
    let callback: Record<string, unknown>;
    try { callback = JSON.parse(rawBody.toString('utf8')) as Record<string, unknown>; }
    catch { return false; }
    const ts = callback.CallbackTs;
    if (typeof ts !== 'number' || Math.abs(Date.now() - ts) > 10 * 60 * 1000) {
      return false;
    }
    if (callback.EventGroupId !== 3) return false;
    const info = callback.EventInfo as Record<string, unknown> | undefined;
    const payload = info?.Payload as Record<string, unknown> | undefined;
    if (!info || !payload || typeof info.TaskId !== 'string') return false;
    const job = [...this.jobs.values()].find((current) =>
      current.id === info.TaskId && current.roomName === String(info.RoomId));
    if (!job) return false;
    if (callback.EventType === 311 && job.storage === 'vod') {
      const vod = payload.TencentVod as Record<string, unknown> | undefined;
      const url = vod?.VideoUrl;
      if (payload.Status === 0 && typeof url === 'string' && this.acceptsVodUrl(url)) {
        job.videoUrl = url;
        if (job.stopRequested) job.state = 'completed';
      } else {
        job.state = 'failed';
        job.error = 'TRTC VOD recording upload failed or returned an invalid media URL.';
      }
    } else if (callback.EventType === 312 && job.storage === 'vod' &&
        payload.Status !== 0 && !job.videoUrl) {
      job.state = 'failed';
      job.error = 'TRTC VOD recording task failed.';
    } else if (callback.EventType === 310 && job.storage === 's3') {
      const files = Array.isArray(payload.FileList) ? payload.FileList : [];
      const filename = files.find((item): item is string =>
        typeof item === 'string' && /^[a-zA-Z0-9_-][a-zA-Z0-9_.-]*\.mp4$/i.test(item) &&
        !item.includes('..'));
      // Names are supplied by the vendor only after a verified callback.
      // Accept a basename, never a path or a customer-supplied bucket/key.
      if (payload.Status === 0 && filename && /^[a-zA-Z0-9_.-]{1,256}$/.test(job.id)) {
        job.s3Key = [...S3_PREFIX, job.id, filename].join('/');
      } else {
        job.state = 'failed';
        job.error = 'TRTC S3 recording failed or returned an unsafe MP4 filename.';
      }
    } else if (callback.EventType === 305 && job.storage === 's3' &&
        payload.LeaveCode === 1) {
      job.state = 'failed';
      job.error = 'TRTC could not upload every recording file to S3.';
    }
    return true;
  }

  private acceptsVodUrl(url: string): boolean {
    try {
      const parsed = new URL(url);
      return parsed.protocol === 'https:' && parsed.username === '' &&
        parsed.password === '' && parsed.port === '' &&
        this.allowedVodHosts.has(parsed.hostname.toLowerCase());
    } catch { return false; }
  }

  async download(room: NamedRoomEntry) {
    const job = this.jobs.get(room.roomCode);
    if (!job || job.state !== 'completed' || (!job.videoUrl && !job.s3Key)) {
      throw new RecordingProviderError('TRTC recording MP4 has not completed uploading.');
    }
    const ticket = crypto.randomBytes(32).toString('base64url');
    this.tickets.set(ticket, {
      roomCode: room.roomCode, jobId: job.id, expires: Date.now() + 60_000,
    });
    return {
      ...this.view(job),
      downloadUrl: `/rooms/${encodeURIComponent(room.roomCode)}/recording/export/${ticket}`,
      expiresInSeconds: 60,
    };
  }

  async consumeExport(roomCode: string, ticket: string) {
    const value = this.tickets.get(ticket);
    this.tickets.delete(ticket);
    const job = this.jobs.get(roomCode);
    if (!value || !job || value.roomCode !== roomCode ||
        value.jobId !== job.id || value.expires < Date.now() ||
        job.state !== 'completed' || !(job.videoUrl || job.s3Key)) {
      throw new RecordingProviderError('Invalid TRTC recording export ticket.');
    }
    if (job.storage === 's3') {
      if (!job.s3Key || !job.s3Key.startsWith(`${S3_PREFIX.join('/')}/${job.id}/`) ||
          !await this.reader.exists(this.s3Bucket, job.s3Key)) {
        throw new RecordingProviderError('TRTC S3 recording is missing.');
      }
      return {
        kind: 'stream' as const,
        filename: this.view(job).fileName ?? 'recording.mp4',
        body: await this.reader.open(this.s3Bucket, job.s3Key),
      };
    }
    if (!job.videoUrl || !this.acceptsVodUrl(job.videoUrl)) {
      throw new RecordingProviderError('TRTC VOD recording URL is invalid.');
    }
    return {
      kind: 'remote' as const, url: job.videoUrl,
      filename: this.view(job).fileName ?? 'recording.mp4',
    };
  }
}
