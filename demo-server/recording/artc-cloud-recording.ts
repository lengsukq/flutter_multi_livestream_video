import crypto from 'node:crypto';
import OSS from 'ali-oss';
import AliRtc, {
  DescribeAppRecordingFilesRequest, DescribeCloudRecordStatusRequest,
  StartCloudRecordRequest, StartCloudRecordRequestStorageConfig,
  StopCloudRecordRequest,
} from '@alicloud/rtc20180111';
import {Config} from '@alicloud/openapi-client';

import type {NamedRoomEntry} from '../types.ts';
import type {
  CloudRecordingExecutor, RecordingLayout, RecordingPreset,
} from './cloud-recording-executor.ts';
import {RecordingConfigurationError, RecordingProviderError} from './livekit-cloud-recording.ts';
import type {RecordingObjectReader} from './s3-recording-storage.ts';

type State = 'recording' | 'processing' | 'completed' | 'failed';
type Task = {
  id: string; channel: string; layout: RecordingLayout; state: State;
  stopped: boolean; key: string | null; size: number; error: string | null;
};

type Api = Pick<InstanceType<typeof AliRtc.default>,
  'startCloudRecord' | 'stopCloudRecord' |
  'describeCloudRecordStatus' | 'describeAppRecordingFiles'>;

/** Alibaba ARTC hosted RTC Cloud Recording, backed by user OSS only. */
export class ArtcCloudRecording implements CloudRecordingExecutor {
  // Older OSS API requires separately provisioned templates for each layout.
  readonly supportedLayouts: readonly ('grid' | 'featuredParticipant')[];
  private readonly jobs = new Map<string, Task>();
  private readonly tickets = new Map<string, {code: string; id: string; expires: number}>();
  private readonly appId: string;
  private readonly templateId: string;
  private readonly speakerTemplateId: string;
  private readonly apiAccess: string;
  private readonly apiSecret: string;
  private readonly bucket: string;
  private readonly region: string;
  private readonly regionCode: number;
  private readonly ossAccess: string;
  private readonly ossSecret: string;
  private readonly api: Api | null;
  private readonly reader: RecordingObjectReader | null;

  constructor(
    env: NodeJS.ProcessEnv = process.env,
    injectedApi?: Api,
    injectedReader?: RecordingObjectReader,
  ) {
    this.appId = env.ARTC_APP_ID?.trim() ?? '';
    this.templateId = env.ARTC_RECORDING_TEMPLATE_ID_GRID?.trim() ||
      env.ARTC_RECORDING_TEMPLATE_ID?.trim() || '';
    this.speakerTemplateId = env.ARTC_RECORDING_TEMPLATE_ID_SPEAKER?.trim() ?? '';
    this.supportedLayouts = this.speakerTemplateId
      ? ['grid', 'featuredParticipant'] : ['grid'];
    this.apiAccess = env.ALIBABA_CLOUD_ACCESS_KEY_ID?.trim() ?? '';
    this.apiSecret = env.ALIBABA_CLOUD_ACCESS_KEY_SECRET?.trim() ?? '';
    this.bucket = env.ARTC_RECORDING_OSS_BUCKET?.trim() ?? '';
    this.region = env.ARTC_RECORDING_OSS_REGION?.trim() ?? '';
    this.regionCode = Number(env.ARTC_RECORDING_OSS_REGION_CODE ?? NaN);
    this.ossAccess = env.ARTC_RECORDING_OSS_ACCESS_KEY?.trim() ?? '';
    this.ossSecret = env.ARTC_RECORDING_OSS_SECRET_KEY?.trim() ?? '';
    this.api = injectedApi ?? (this.apiAccess && this.apiSecret
      ? new AliRtc.default(new Config({
        accessKeyId: this.apiAccess, accessKeySecret: this.apiSecret,
        endpoint: 'rtc.aliyuncs.com',
      })) : null);
    this.reader = injectedReader ?? (this.region && this.bucket && this.ossAccess && this.ossSecret
      ? this.createReader() : null);
  }

  private createReader(): RecordingObjectReader {
    const configuredBucket = this.bucket;
    const client = new OSS({
      region: this.region, bucket: this.bucket,
      accessKeyId: this.ossAccess, accessKeySecret: this.ossSecret,
    });
    return {
      async exists(bucket, key) {
        if (bucket !== configuredBucket) return false;
        try {await client.head(key); return true;}
        catch (error) {
          if (error && typeof error === 'object' &&
              'status' in error && error.status === 404) return false;
          throw new RecordingProviderError('Cannot verify ARTC recorded MP4 in OSS.');
        }
      },
      async open(bucket, key) {
        if (bucket !== configuredBucket) {
          throw new RecordingProviderError('ARTC recording bucket mismatch.');
        }
        const file = await client.getStream(key);
        return file.stream;
      },
      async remove(bucket, key) {
        if (bucket !== configuredBucket) {
          throw new RecordingProviderError('ARTC recording bucket mismatch.');
        }
        await client.delete(key);
      },
    };
  }

  get configured() {
    return Boolean(
      this.appId && this.templateId && this.apiAccess && this.apiSecret &&
      this.api && this.reader && this.bucket && this.region &&
      Number.isInteger(this.regionCode) && this.regionCode >= 0 &&
      this.ossAccess && this.ossSecret,
    );
  }

  readiness() {
    return this.configured ? {available: true} : {
      available: false,
      reason: 'Alibaba ARTC cloud recording needs ALIBABA_CLOUD_ACCESS_KEY_ID/SECRET, ' +
        'ARTC_RECORDING_TEMPLATE_ID, and ARTC_RECORDING_OSS_BUCKET/REGION/REGION_CODE/ACCESS_KEY/SECRET_KEY.',
    };
  }

  private ensureConfigured(): void {
    if (!this.configured) throw new RecordingConfigurationError(
      this.readiness().reason ?? 'ARTC cloud recording is not configured.',
    );
  }

  private view(job: Task) {
    return {
      provider: 'artc', recordingId: job.id, state: job.state,
      layout: job.layout, canDownload: job.state === 'completed' && Boolean(job.key),
      fileName: job.key?.split('/').at(-1) ?? null,
      fileSizeBytes: job.size, error: job.error,
    };
  }

  async start(room: NamedRoomEntry, layout: RecordingLayout, _preset: RecordingPreset) {
    this.ensureConfigured();
    if (layout === 'speaker' && !this.speakerTemplateId) {
      throw new RecordingConfigurationError('ARTC OSS speaker layout requires ARTC_RECORDING_TEMPLATE_ID_SPEAKER.');
    }
    const old = this.jobs.get(room.roomCode);
    if (old && old.state !== 'completed' && old.state !== 'failed') {
      throw new RecordingProviderError('An ARTC cloud recording is already running.');
    }
    const job: Task = {
      id: crypto.randomUUID(), channel: room.providerRoomName, layout,
      state: 'recording', stopped: false, key: null, size: 0, error: null,
    };
    try {
      const response = await this.api!.startCloudRecord(new StartCloudRecordRequest({
        appId: this.appId, channelId: room.providerRoomName,
        templateId: layout === 'speaker' ? this.speakerTemplateId : this.templateId,
        taskId: job.id,
        storageConfig: new StartCloudRecordRequestStorageConfig({
          vendor: 1, region: this.regionCode, bucket: this.bucket,
          accessKey: this.ossAccess, secretKey: this.ossSecret,
        }),
        // The template owns encoding/compositing. Never silently reuse grid
        // when the caller specifically requested featuredParticipant.
      }));
      if (response.body?.taskId !== job.id) {
        throw new RecordingProviderError('ARTC did not confirm the expected recording TaskId.');
      }
      this.jobs.set(room.roomCode, job);
      return this.view(job);
    } catch (error) {
      if (error instanceof RecordingProviderError) throw error;
      throw new RecordingProviderError('ARTC StartCloudRecord failed.');
    }
  }

  async stop(room: NamedRoomEntry) {
    this.ensureConfigured();
    const job = this.jobs.get(room.roomCode);
    if (!job) throw new RecordingProviderError('No ARTC cloud recording is active.');
    if (!job.stopped) {
      try {
        await this.api!.stopCloudRecord(new StopCloudRecordRequest({
          appId: this.appId, channelId: job.channel, taskId: job.id,
        }));
      } catch {
        throw new RecordingProviderError('ARTC StopCloudRecord failed.');
      }
      job.stopped = true;
      job.state = 'processing';
    }
    return this.view(job);
  }

  async status(room: NamedRoomEntry) {
    const job = this.jobs.get(room.roomCode);
    if (!job) return {
      provider: 'artc', recordingId: null, state: 'idle',
      layout: null, canDownload: false, fileName: null, fileSizeBytes: 0, error: null,
    };
    this.ensureConfigured();
    if (!job.stopped) {
      await this.api!.describeCloudRecordStatus(new DescribeCloudRecordStatusRequest({
        appId: this.appId, channelId: job.channel, taskId: job.id,
      }));
    } else if (!job.key) {
      const listing = await this.api!.describeAppRecordingFiles(
        new DescribeAppRecordingFilesRequest({
          appId: this.appId, channelId: job.channel, taskIds: [job.id],
          pageNo: 1, pageSize: 50,
        }),
      );
      const file = listing.body?.items?.find((entry) =>
        entry.taskId === job.id && entry.channelId === job.channel &&
        entry.bucket === this.bucket && entry.filePath?.endsWith('.mp4') &&
        entry.filePath.startsWith('record/') &&
        !entry.filePath.split('/').some((piece) => !piece || piece === '.' || piece === '..'));
      if (file?.filePath && await this.reader!.exists(this.bucket, file.filePath)) {
        job.key = file.filePath;
        job.size = file.fileSize ?? 0;
        job.state = 'completed';
      }
    }
    return this.view(job);
  }

  async download(room: NamedRoomEntry) {
    const status = await this.status(room);
    const job = this.jobs.get(room.roomCode);
    if (!job?.key || job.state !== 'completed') {
      throw new RecordingProviderError('ARTC cloud recording MP4 is not available in OSS yet.');
    }
    const ticket = crypto.randomBytes(32).toString('base64url');
    this.tickets.set(ticket, {code: room.roomCode, id: job.id, expires: Date.now() + 60_000});
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
    if (!item || !job || item.code !== roomCode || item.id !== job.id ||
        item.expires < Date.now() || !job.key || job.state !== 'completed' || !this.reader) {
      throw new RecordingProviderError('ARTC download ticket is invalid or expired.');
    }
    return {
      kind: 'stream' as const,
      filename: job.key.split('/').at(-1)!,
      body: await this.reader.open(this.bucket, job.key),
      ...(this.reader.remove ? {afterDownload: async () => {
        await this.reader!.remove!(this.bucket, job.key!);
        job.key = null;
      }} : {}),
    };
  }
}
