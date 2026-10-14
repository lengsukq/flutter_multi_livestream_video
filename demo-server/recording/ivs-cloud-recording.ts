import crypto from 'node:crypto';
import {
  IVSRealTimeClient,
  StartCompositionCommand, GetCompositionCommand, StopCompositionCommand,
} from '@aws-sdk/client-ivs-realtime';
import {
  MediaConvertClient, CreateJobCommand, GetJobCommand,
} from '@aws-sdk/client-mediaconvert';

import type {IvsRoomEntry, NamedRoomEntry} from '../types.ts';
import type {
  CloudRecordingExecutor, RecordingLayout, RecordingPreset,
} from './cloud-recording-executor.ts';
import {RecordingConfigurationError, RecordingProviderError} from './livekit-cloud-recording.ts';
import {s3RecordingReader, type RecordingObjectReader} from './s3-recording-storage.ts';
import {FileRecordingJobStore} from './file-recording-job-store.ts';

type IvsCloudApi = {
  start(stageArn: string, encoderArn: string, storageArn: string,
    layout: RecordingLayout): Promise<{arn: string; prefix?: string}>;
  get(arn: string): Promise<{state: string; prefix?: string}>;
  stop(arn: string): Promise<void>;
  convert(input: string, output: string, role: string): Promise<string>;
  conversionStatus(id: string): Promise<string>;
};
type Job = {
  id: string; prefix: string | null; key: string | null;
  outputKey: string | null; convertId: string | null;
  stopped: boolean; layout: RecordingLayout; preset: RecordingPreset;
  state: 'recording' | 'processing' | 'completed' | 'failed';
  error: string | null;
};

/** IVS does not expose voice-activity-based composition; featured grid
 * highlights the participant whose token has isFeatured=true (the host). */
export function ivsCompositionLayout(layout: RecordingLayout) {
  return layout === 'speaker'
    ? {grid: {featuredParticipantAttribute: 'isFeatured'}}
    : {grid: {}};
}

/**
 * Fully provider-hosted IVS RT stage composition (HLS) + AWS MediaConvert MP4.
 * The Demo Server does not transcode audio/video or run FFmpeg.
 */
export class IvsCloudRecording implements CloudRecordingExecutor {
  // isFeatured comes from the host's IVS participant token.
  readonly supportedLayouts = ['grid', 'featuredParticipant'] as const;
  private readonly bucket: string;
  private readonly encoderArn: string;
  private readonly encoder1080Arn: string;
  private readonly storageArn: string;
  private readonly convertRoleArn: string;
  private readonly api: IvsCloudApi;
  private readonly reader: RecordingObjectReader;
  private readonly jobs = new Map<string, Job>();
  private readonly rooms = new Map<string, NamedRoomEntry>();
  private readonly store: FileRecordingJobStore<Job>;
  private readonly tickets = new Map<string, {roomCode: string; id: string; expires: number}>();

  constructor(
    env: NodeJS.ProcessEnv = process.env,
    injectedApi?: IvsCloudApi,
    injectedReader?: RecordingObjectReader,
  ) {
    const region = env.IVS_RECORDING_AWS_REGION?.trim() ?? env.AWS_REGION?.trim() ?? 'us-east-1';
    this.bucket = env.IVS_RECORDING_S3_BUCKET?.trim() ?? '';
    this.storageArn = env.IVS_RECORDING_STORAGE_CONFIGURATION_ARN?.trim() ?? '';
    this.encoderArn = env.IVS_RECORDING_ENCODER_CONFIGURATION_ARN?.trim() ?? '';
    this.encoder1080Arn = env.IVS_RECORDING_ENCODER_CONFIGURATION_ARN_1080P?.trim() ?? '';
    this.convertRoleArn = env.IVS_RECORDING_MEDIACONVERT_ROLE_ARN?.trim() ?? '';
    const ivs = new IVSRealTimeClient({region});
    const mc = new MediaConvertClient({region});
    this.api = injectedApi ?? {
      async start(stageArn, encoderArn, storageArn, layout) {
        const response = await ivs.send(new StartCompositionCommand({
          stageArn,
          destinations: [{
            s3: {
              storageConfigurationArn: storageArn,
              encoderConfigurationArns: [encoderArn],
            },
          }],
          // IVS has grid/featured layouts, but no automatic audio-active-speaker
          // composition. The speaker mode highlights an explicitly featured host.
          layout: ivsCompositionLayout(layout),
        }));
        const composition = response.composition;
        const arn = composition?.arn;
        if (!arn) throw new RecordingProviderError('IVS did not return a Composition ARN.');
        return {
          arn,
          prefix: composition!.destinations?.find((d) => d.detail?.s3?.recordingPrefix)
            ?.detail?.s3?.recordingPrefix,
        };
      },
      async get(arn) {
        const reply = await ivs.send(new GetCompositionCommand({arn}));
        return {
          state: reply.composition?.state ?? 'UNKNOWN',
          prefix: reply.composition?.destinations?.find((d) => d.detail?.s3?.recordingPrefix)
            ?.detail?.s3?.recordingPrefix,
        };
      },
      async stop(arn) {await ivs.send(new StopCompositionCommand({arn}));},
      async convert(input, output, role) {
        const reply = await mc.send(new CreateJobCommand({
          Role: role,
          Settings: {
            Inputs: [{
              FileInput: input,
              AudioSelectors: {'Audio Selector 1': {DefaultSelection: 'DEFAULT'}},
            }],
            OutputGroups: [{
              Name: 'File Group',
              OutputGroupSettings: {
                Type: 'FILE_GROUP_SETTINGS',
                FileGroupSettings: {Destination: output},
              },
              Outputs: [{
                NameModifier: '_demo',
                ContainerSettings: {Container: 'MP4'},
                VideoDescription: {
                  CodecSettings: {
                    Codec: 'H_264',
                    H264Settings: {
                      RateControlMode: 'QVBR',
                      QvbrSettings: {QvbrQualityLevel: 7},
                    },
                  },
                },
                AudioDescriptions: [{
                  AudioSourceName: 'Audio Selector 1',
                  CodecSettings: {
                    Codec: 'AAC',
                    AacSettings: {Bitrate: 96000, CodingMode: 'CODING_MODE_2_0', SampleRate: 48000},
                  },
                }],
              }],
            }],
          },
        }));
        if (!reply.Job?.Id) throw new RecordingProviderError('MediaConvert did not return Job ID.');
        return reply.Job.Id;
      },
      async conversionStatus(id) {
        const result = await mc.send(new GetJobCommand({Id: id}));
        return result.Job?.Status ?? 'UNKNOWN';
      },
    };
    this.reader = injectedReader ?? s3RecordingReader({region});
    this.store = new FileRecordingJobStore(env.DEMO_RECORDING_STATE_DIR?.trim(), 'ivs');
  }
  private job(room: NamedRoomEntry): Job | null {
    this.rooms.set(room.roomCode, room);
    const cached = this.jobs.get(room.roomCode);
    if (cached) return cached;
    const restored = this.store.load(room);
    if (restored && restored.id.startsWith('arn:aws:ivs:')) {
      this.jobs.set(room.roomCode, restored);
      return restored;
    }
    return null;
  }

  get configured() {
    return Boolean(
      /^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$/.test(this.bucket) &&
      this.encoderArn.startsWith('arn:aws:ivs:') &&
      this.storageArn.startsWith('arn:aws:ivs:') &&
      this.convertRoleArn.startsWith('arn:aws:iam::'),
    );
  }
  readiness() {
    return this.configured ? {available: true} : {
      available: false,
      reason: 'IVS MP4 requires IVS_RECORDING_S3_BUCKET, ' +
        'IVS_RECORDING_STORAGE_CONFIGURATION_ARN, IVS_RECORDING_ENCODER_CONFIGURATION_ARN, ' +
        'IVS_RECORDING_MEDIACONVERT_ROLE_ARN and AWS IAM credentials. ' +
        'IVS records HLS; MediaConvert is the AWS-hosted MP4 conversion step.',
    };
  }
  private ensureConfigured() {
    if (!this.configured) throw new RecordingConfigurationError(
      this.readiness().reason ?? 'IVS cloud MP4 recording is not configured.',
    );
  }
  private view(job: Job) {
    return {
      provider: 'ivs', recordingId: job.id, layout: job.layout, state: job.state,
      preset: job.preset,
      canDownload: job.state === 'completed' && Boolean(job.outputKey),
      fileName: job.outputKey?.split('/').at(-1) ?? null,
      fileSizeBytes: 0, error: job.error,
    };
  }

  async start(room: NamedRoomEntry, layout: RecordingLayout, preset: RecordingPreset) {
    this.ensureConfigured();
    const stageArn = (room as IvsRoomEntry).stageArn;
    if (!stageArn?.startsWith('arn:aws:ivs:')) {
      throw new RecordingProviderError('IVS room stageArn is missing.');
    }
    const encoder = preset === 'H264_1080P_30' ? this.encoder1080Arn : this.encoderArn;
    if (!encoder.startsWith('arn:aws:ivs:')) {
      throw new RecordingConfigurationError(
        'IVS 1080p recording requires IVS_RECORDING_ENCODER_CONFIGURATION_ARN_1080P.',
      );
    }
    const old = this.job(room);
    if (old && !['completed', 'failed'].includes(old.state)) {
      throw new RecordingProviderError('An IVS recording is already active.');
    }
    const created = await this.api.start(stageArn, encoder, this.storageArn, layout);
    if (!created.arn.startsWith('arn:aws:ivs:')) {
      throw new RecordingProviderError('IVS returned an invalid Composition ARN.');
    }
    const job: Job = {
      id: created.arn, prefix: created.prefix ?? null, key: null,
      outputKey: null, convertId: null, stopped: false, layout, preset,
      state: 'recording', error: null,
    };
    this.jobs.set(room.roomCode, job);
    this.store.save(room, job);
    return this.view(job);
  }

  async stop(room: NamedRoomEntry) {
    this.ensureConfigured();
    const job = this.job(room);
    if (!job) throw new RecordingProviderError('No IVS Composition recording exists.');
    if (!job.stopped) {
      // Capture the vendor-generated prefix *before* StopComposition deletes
      // the ephemeral Composition resource from the IVS control plane.
      if (!job.prefix) {
        const current = await this.api.get(job.id);
        job.prefix = current.prefix ?? null;
      }
      if (!job.prefix) {
        throw new RecordingProviderError(
          'IVS has not reported the cloud recording S3 prefix yet; retry stopping shortly.',
        );
      }
      await this.api.stop(job.id);
      job.stopped = true;
      job.state = 'processing';
      this.store.save(room, job);
    }
    return this.view(job);
  }

  async status(room: NamedRoomEntry) {
    const job = this.job(room);
    if (!job) return {
      provider: 'ivs', recordingId: null, layout: null, state: 'idle',
      canDownload: false, fileName: null, fileSizeBytes: 0, error: null,
    };
    this.ensureConfigured();
    if (!job.stopped && job.state === 'recording') {
      const remote = await this.api.get(job.id);
      job.prefix = remote.prefix ?? job.prefix;
      this.store.save(room, job);
      if (remote.state === 'FAILED') {
        job.state = 'failed';
        job.error = 'IVS Composition failed.';
        this.store.save(room, job);
      }
      return this.view(job);
    }
    if (job.stopped && job.state === 'processing' && !job.convertId) {
      if (!job.prefix || !/^[a-zA-Z0-9\/_-]+$/.test(job.prefix) ||
          job.prefix.includes('..')) {
        return this.view(job);
      }
      // IVS marks completion by uploading this event after the HLS segments.
      const root = job.prefix.replace(/\/$/, '');
      const done = `${root}/events/recording-ended.json`;
      if (!(await this.reader.exists(this.bucket, done))) return this.view(job);
      const manifestCandidates = [
        `${root}/media/hls/multivariant.m3u8`,
        `${root}/composite/media/hls/multivariant.m3u8`,
      ];
      for (const key of manifestCandidates) {
        if (await this.reader.exists(this.bucket, key)) {
          job.key = key;
          break;
        }
      }
      if (!job.key) return this.view(job);
      const destination = `flutter-realtime-demo/${crypto.randomUUID()}/`;
      const outputKey = `${destination}multivariant_demo.mp4`;
      const id = await this.api.convert(
        `s3://${this.bucket}/${job.key}`,
        `s3://${this.bucket}/${destination}`,
        this.convertRoleArn,
      );
      job.convertId = id;
      job.outputKey = outputKey;
      this.store.save(room, job);
    }
    if (job.convertId && job.state === 'processing') {
      const state = await this.api.conversionStatus(job.convertId);
      if (['ERROR', 'CANCELED'].includes(state)) {
        job.state = 'failed';
        job.error = 'AWS MediaConvert cloud MP4 conversion failed.';
        this.store.save(room, job);
      } else if (state === 'COMPLETE' && job.outputKey &&
          await this.reader.exists(this.bucket, job.outputKey)) {
        job.state = 'completed';
        this.store.save(room, job);
      }
    }
    return this.view(job);
  }

  async download(room: NamedRoomEntry) {
    const status = await this.status(room);
    const job = this.job(room);
    if (!job?.outputKey || job.state !== 'completed') {
      throw new RecordingProviderError('IVS/MediaConvert MP4 is still processing.');
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
        item.expires < Date.now() || job.state !== 'completed' || !job.outputKey) {
      throw new RecordingProviderError('IVS MP4 download link is invalid or expired.');
    }
    const key = job.outputKey;
    return {
      kind: 'stream' as const,
      filename: key.split('/').at(-1)!,
      body: await this.reader.open(this.bucket, key),
      ...(this.reader.remove ? {afterDownload: async () => {
        await this.reader.remove!(this.bucket, key);
        job.outputKey = null;
        const room = this.rooms.get(roomCode);
        if (room) this.store.save(room, job);
      }} : {}),
    };
  }
}
