import crypto from 'node:crypto';
import {
  ChimeSDKMediaPipelinesClient, CreateMediaCapturePipelineCommand,
  CreateMediaConcatenationPipelineCommand, DeleteMediaCapturePipelineCommand,
  GetMediaPipelineCommand,
} from '@aws-sdk/client-chime-sdk-media-pipelines';

import type {NamedRoomEntry} from '../types.ts';
import type {
  CloudRecordingExecutor, RecordingLayout, RecordingPreset,
} from './cloud-recording-executor.ts';
import {RecordingConfigurationError, RecordingProviderError} from './livekit-cloud-recording.ts';
import {s3RecordingReader, type RecordingObjectReader} from './s3-recording-storage.ts';

type Job = {
  id: string; captureArn: string; sourceArn: string;
  concatId: string | null; key: string | null;
  captureStopped: boolean;
  layout: RecordingLayout; state: 'recording' | 'processing' | 'completed' | 'failed';
  error: string | null;
};
type CloudApi = {
  start(meetingArn: string, bucketArn: string): Promise<{id: string; arn: string}>;
  concatenate(captureArn: string, destinationArn: string): Promise<string>;
  stopCapture(id: string): Promise<void>;
  concatenationStatus(id: string): Promise<string>;
};

/** AWS Chime hosted capture + concatenation: Chime creates the MP4 in S3. */
export class ChimeCloudRecording implements CloudRecordingExecutor {
  private readonly jobs = new Map<string, Job>();
  private readonly tickets = new Map<string, {roomCode: string; id: string; expires: number}>();
  private readonly bucket: string;
  private readonly region: string;
  private readonly api: CloudApi;
  private readonly reader: RecordingObjectReader;

  constructor(
    env: NodeJS.ProcessEnv = process.env,
    injectedApi?: CloudApi,
    injectedReader?: RecordingObjectReader,
  ) {
    this.bucket = env.CHIME_RECORDING_S3_BUCKET?.trim() ?? '';
    this.region = env.CHIME_RECORDING_S3_REGION?.trim() ||
      env.AWS_REGION?.trim() || 'us-east-1';
    const client = new ChimeSDKMediaPipelinesClient({region: this.region});
    this.api = injectedApi ?? {
      async start(meetingArn, bucketArn) {
        const reply = await client.send(new CreateMediaCapturePipelineCommand({
          SourceType: 'ChimeSdkMeeting', SourceArn: meetingArn,
          SinkType: 'S3Bucket', SinkArn: bucketArn,
          ChimeSdkMeetingConfiguration: {
            ArtifactsConfiguration: {
              Audio: {MuxType: 'AudioWithCompositedVideo'},
              Video: {State: 'Disabled'},
              Content: {State: 'Disabled'},
              CompositedVideo: {
                Layout: 'GridView', Resolution: 'HD',
                GridViewConfiguration: {ContentShareLayout: 'PresenterOnly'},
              },
            },
          },
          ClientRequestToken: crypto.randomUUID(),
        }));
        if (!reply.MediaCapturePipeline?.MediaPipelineId ||
            !reply.MediaCapturePipeline.MediaPipelineArn) {
          throw new RecordingProviderError('Chime did not return a capture pipeline ID and ARN.');
        }
        return {
          id: reply.MediaCapturePipeline.MediaPipelineId,
          arn: reply.MediaCapturePipeline.MediaPipelineArn,
        };
      },
      async concatenate(captureArn, destinationArn) {
        const reply = await client.send(new CreateMediaConcatenationPipelineCommand({
          Sources: [{
            Type: 'MediaCapturePipeline',
            MediaCapturePipelineSourceConfiguration: {
              MediaPipelineArn: captureArn,
              ChimeSdkMeetingConfiguration: {
                ArtifactsConfiguration: {
                  Audio: {State: 'Enabled'},
                  Video: {State: 'Disabled'},
                  Content: {State: 'Disabled'},
                  DataChannel: {State: 'Disabled'},
                  TranscriptionMessages: {State: 'Disabled'},
                  MeetingEvents: {State: 'Disabled'},
                  CompositedVideo: {State: 'Enabled'},
                },
              },
            },
          }],
          Sinks: [{
            Type: 'S3Bucket',
            S3BucketSinkConfiguration: {Destination: destinationArn},
          }],
          ClientRequestToken: crypto.randomUUID(),
        }));
        const id = reply.MediaConcatenationPipeline?.MediaPipelineId;
        if (!id) throw new RecordingProviderError('Chime did not return concatenation pipeline ID.');
        return id;
      },
      async stopCapture(id) {
        await client.send(new DeleteMediaCapturePipelineCommand({MediaPipelineId: id}));
      },
      async concatenationStatus(id) {
        const reply = await client.send(new GetMediaPipelineCommand({MediaPipelineId: id}));
        return reply.MediaPipeline?.MediaConcatenationPipeline?.Status ?? 'Unknown';
      },
    };
    this.reader = injectedReader ?? s3RecordingReader({region: this.region});
  }

  get configured() {
    return Boolean(/^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$/.test(this.bucket));
  }
  readiness() {
    return this.configured ? {available: true} : {
      available: false,
      reason: 'AWS Chime cloud recording requires CHIME_RECORDING_S3_BUCKET. AWS IAM and region credentials remain server-side.',
    };
  }
  private ensureConfigured() {
    if (!this.configured) throw new RecordingConfigurationError(
      this.readiness().reason ?? 'Chime capture storage is not configured.',
    );
  }
  private view(job: Job) {
    return {
      provider: 'chime', recordingId: job.id, state: job.state,
      layout: job.layout, canDownload: job.state === 'completed' && Boolean(job.key),
      fileName: job.key?.split('/').at(-1) ?? null, fileSizeBytes: 0, error: job.error,
    };
  }
  async start(room: NamedRoomEntry, layout: RecordingLayout, _preset: RecordingPreset) {
    this.ensureConfigured();
    const sourceArn = room.meeting?.MeetingArn;
    if (!sourceArn?.startsWith('arn:aws:chime:')) {
      throw new RecordingProviderError('AWS Chime meeting ARN is required for cloud media capture.');
    }
    const old = this.jobs.get(room.roomCode);
    if (old && !['completed', 'failed'].includes(old.state)) {
      throw new RecordingProviderError('Chime capture is already running.');
    }
    const created = await this.api.start(sourceArn, `arn:aws:s3:::${this.bucket}`);
    const job: Job = {
      id: created.id, captureArn: created.arn, sourceArn,
      concatId: null, key: null, captureStopped: false,
      layout, state: 'recording', error: null,
    };
    this.jobs.set(room.roomCode, job);
    return this.view(job);
  }
  async stop(room: NamedRoomEntry) {
    this.ensureConfigured();
    const job = this.jobs.get(room.roomCode);
    if (!job) throw new RecordingProviderError('No Chime cloud recording exists.');
    if (!job.concatId) {
      // Chime concatenation is created first; it waits for capture to stop.
      const prefix = `flutter-realtime-demo/${crypto.randomUUID()}`;
      const concatId = await this.api.concatenate(
        job.captureArn, `arn:aws:s3:::${this.bucket}/${prefix}`,
      );
      job.concatId = concatId;
      job.key = `${prefix}/composited-video/${concatId}.mp4`;
      job.state = 'processing';
    }
    if (!job.captureStopped) {
      // Retry stopping capture if an earlier network/API failure occurred
      // after the concatenation pipeline was already created.
      await this.api.stopCapture(job.id);
      job.captureStopped = true;
    }
    return this.view(job);
  }
  async status(room: NamedRoomEntry) {
    const job = this.jobs.get(room.roomCode);
    if (!job) return {
      provider: 'chime', recordingId: null, state: 'idle',
      layout: null, canDownload: false, fileName: null, fileSizeBytes: 0, error: null,
    };
    if (job.concatId && job.state === 'processing') {
      const state = await this.api.concatenationStatus(job.concatId);
      if (state === 'Failed') {
        job.state = 'failed';
        job.error = 'AWS Chime concatenation failed.';
      } else if (state === 'Stopped' && job.key &&
          await this.reader.exists(this.bucket, job.key)) {
        job.state = 'completed';
      }
    }
    return this.view(job);
  }
  async download(room: NamedRoomEntry) {
    const status = await this.status(room);
    const job = this.jobs.get(room.roomCode);
    if (!job?.key || job.state !== 'completed') {
      throw new RecordingProviderError('AWS Chime concatenation MP4 has not completed.');
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
    if (!item || !job || item.roomCode !== roomCode ||
        item.id !== job.id || item.expires < Date.now() ||
        job.state !== 'completed' || !job.key) {
      throw new RecordingProviderError('Chime recording download ticket is invalid.');
    }
    return {
      kind: 'stream' as const,
      filename: job.key.split('/').at(-1)!,
      body: await this.reader.open(this.bucket, job.key),
      ...(this.reader.remove ? {afterDownload: async () => {
        await this.reader.remove!(this.bucket, job.key!);
        job.key = null;
      }} : {}),
    };
  }
}
