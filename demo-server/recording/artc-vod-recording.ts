import crypto from 'node:crypto';

import Live, {
  DescribeRtcCloudRecordingFilesRequest,
  StartRtcCloudRecordingRequest,
  StartRtcCloudRecordingRequestMixLayoutParams,
  StartRtcCloudRecordingRequestMixLayoutParamsUserPanes,
  StartRtcCloudRecordingRequestMixTranscodeParams,
  StartRtcCloudRecordingRequestRecordParams,
  StartRtcCloudRecordingRequestStorageParams,
  StartRtcCloudRecordingRequestStorageParamsVodParams,
  StartRtcCloudRecordingRequestSubscribeParams,
  StartRtcCloudRecordingRequestSubscribeParamsSubscribeUserIdList,
  StopRtcCloudRecordingRequest,
} from '@alicloud/live20161101';
import Vod, {GetPlayInfoRequest} from '@alicloud/vod20170321';
import {Config} from '@alicloud/openapi-client';

import type {NamedRoomEntry} from '../types.ts';
import type {CloudRecordingExecutor, RecordingLayout, RecordingPreset} from './cloud-recording-executor.ts';
import {RecordingConfigurationError, RecordingProviderError} from './livekit-cloud-recording.ts';

type LiveApi = Pick<InstanceType<typeof Live.default>,
  'startRtcCloudRecording' | 'stopRtcCloudRecording' | 'describeRtcCloudRecordingFiles'>;
type VodApi = Pick<InstanceType<typeof Vod.default>, 'getPlayInfo'>;
type Task = {
  id: string;
  channel: string;
  layout: RecordingLayout;
  state: 'recording' | 'processing' | 'completed' | 'failed';
  stopped: boolean;
  mediaId: string | null;
  videoUrl: string | null;
  size: number;
  error: string | null;
};

/**
 * ARTC VOD uses the Live 2016-11-01 RTC recording API, *not* the older
 * RTC 2018 StartCloudRecord (which only supports OSS storageConfig).
 * Media is recorded by Alibaba and served from Alibaba VOD without AWS S3.
 */
export class ArtcVodRecording implements CloudRecordingExecutor {
  private readonly jobs = new Map<string, Task>();
  private readonly tickets = new Map<string, {roomCode: string; id: string; expires: number}>();
  private readonly appId: string;
  private readonly storageLocation: string;
  private readonly transcodeGroupId: string;
  private readonly region: string;
  private readonly allowedHosts: Set<string>;
  private readonly live: LiveApi | null;
  private readonly vod: VodApi | null;

  constructor(env: NodeJS.ProcessEnv = process.env, liveApi?: LiveApi, vodApi?: VodApi) {
    this.appId = env.ARTC_APP_ID?.trim() ?? '';
    this.storageLocation = env.ARTC_RECORDING_VOD_STORAGE_LOCATION?.trim() ?? '';
    this.transcodeGroupId = env.ARTC_RECORDING_VOD_TRANSCODE_GROUP_ID?.trim() ?? '';
    this.region = env.ARTC_RECORDING_VOD_REGION?.trim() || 'cn-shanghai';
    this.allowedHosts = new Set((env.ARTC_RECORDING_VOD_HOSTS ?? '')
      .split(',').map((h) => h.trim().toLowerCase()).filter(Boolean));
    const key = env.ALIBABA_CLOUD_ACCESS_KEY_ID?.trim();
    const secret = env.ALIBABA_CLOUD_ACCESS_KEY_SECRET?.trim();
    const endpoint = this.region === 'cn-shanghai'
      ? 'live.aliyuncs.com' : `live.${this.region}.aliyuncs.com`;
    this.live = liveApi ?? (key && secret ? new Live.default(new Config({
      accessKeyId: key, accessKeySecret: secret, regionId: this.region, endpoint,
    })) : null);
    this.vod = vodApi ?? (key && secret ? new Vod.default(new Config({
      accessKeyId: key, accessKeySecret: secret, regionId: this.region,
      endpoint: `vod.${this.region}.aliyuncs.com`,
    })) : null);
  }

  private async getMp4(mediaId: string) {
    const reply = await this.vod!.getPlayInfo(new GetPlayInfoRequest({
      videoId: mediaId, formats: 'mp4', authTimeout: 300,
    }));
    return reply.body?.playInfoList?.playInfo?.find((item) =>
      item.format?.toLowerCase() === 'mp4' && item.encrypt !== 1 &&
      item.status === 'Normal' && typeof item.playURL === 'string' &&
      this.acceptsVideoUrl(item.playURL));
  }

  get configured(): boolean {
    return Boolean(this.appId && this.storageLocation && this.transcodeGroupId &&
      this.allowedHosts.size && this.live && this.vod &&
      ['cn-shanghai', 'ap-southeast-1'].includes(this.region));
  }

  readiness() {
    return this.configured ? {available: true} : {
      available: false,
      reason: 'ARTC VOD recording requires ARTC_APP_ID, ALIBABA_CLOUD_ACCESS_KEY_ID/SECRET, ' +
        'ARTC_RECORDING_VOD_REGION (cn-shanghai/ap-southeast-1), ' +
        'ARTC_RECORDING_VOD_STORAGE_LOCATION, ARTC_RECORDING_VOD_TRANSCODE_GROUP_ID ' +
        'and ARTC_RECORDING_VOD_HOSTS. VOD MP4 output must be enabled in the transcoding template.',
    };
  }

  private ensureConfigured() {
    if (!this.configured) throw new RecordingConfigurationError(this.readiness().reason!);
  }

  private view(job: Task) {
    const ready = job.state === 'completed' && Boolean(job.videoUrl);
    return {
      provider: 'artc', recordingId: job.id, state: job.state,
      layout: job.layout, canDownload: ready,
      fileName: ready ? `artc-${job.id}.mp4` : null,
      fileSizeBytes: job.size, error: job.error,
    };
  }

  private acceptsVideoUrl(url: string): boolean {
    try {
      const target = new URL(url);
      return target.protocol === 'https:' && !target.username && !target.password &&
        !target.port && target.pathname.toLowerCase().endsWith('.mp4') &&
        this.allowedHosts.has(target.hostname.toLowerCase());
    } catch { return false; }
  }

  async start(room: NamedRoomEntry, layout: RecordingLayout, _preset: RecordingPreset) {
    this.ensureConfigured();
    const previous = this.jobs.get(room.roomCode);
    if (previous && previous.state !== 'completed' && previous.state !== 'failed') {
      throw new RecordingProviderError('An ARTC VOD recording is already running.');
    }
    const ids = [...new Set(room.attendees
      .filter((person) => person.role !== 'viewer')
      .map((person) => person.attendeeId))];
    if (ids.length === 0 || ids.length > 16) {
      throw new RecordingProviderError('ARTC VOD recording needs 1 to 16 active publishing participants.');
    }
    // RTC Live API requires an explicit subscription list and video panes.
    // Capture participants present at start; no arbitrary client IDs accepted.
    const count = ids.length;
    const columns = layout === 'speaker' ? 1 : Math.ceil(Math.sqrt(count));
    const rows = Math.ceil(count / columns);
    const panes = ids.map((userId, index) => {
      const x = layout === 'speaker' ? 0 : (index % columns) / columns;
      const y = layout === 'speaker' ? 0 : Math.floor(index / columns) / rows;
      return new StartRtcCloudRecordingRequestMixLayoutParamsUserPanes({
        userId,
        x: String(x), y: String(y),
        width: String(layout === 'speaker' ? 1 : 1 / columns),
        height: String(layout === 'speaker' ? 1 : 1 / rows),
        ZOrder: index,
      });
    });
    // Speaker is a single focused pane in V1; all audio participants are still
    // subscribed. Full active-speaker layout switching requires Update API.
    if (layout === 'speaker') panes.splice(1);
    const request = new StartRtcCloudRecordingRequest({
      appId: this.appId,
      channelId: room.providerRoomName,
      subscribeParams: new StartRtcCloudRecordingRequestSubscribeParams({
        subscribeUserIdList: ids.map((userId) =>
          new StartRtcCloudRecordingRequestSubscribeParamsSubscribeUserIdList({userId, streamType: 0})),
      }),
      recordParams: new StartRtcCloudRecordingRequestRecordParams({
        recordMode: 1, streamType: 0, maxFileDuration: 7200,
      }),
      storageParams: new StartRtcCloudRecordingRequestStorageParams({
        storageType: 0,
        vodParams: new StartRtcCloudRecordingRequestStorageParamsVodParams({
          storageLocation: this.storageLocation,
          vodTranscodeGroupId: this.transcodeGroupId,
          autoCompose: 0,
        }),
      }),
      mixTranscodeParams: new StartRtcCloudRecordingRequestMixTranscodeParams({
        audioBitrate: 128, audioChannels: 2, audioSampleRate: 48000,
        videoCodec: 'H.264', videoBitrate: 1600, videoFramerate: 15,
        videoGop: 30, videoHeight: 720, videoWidth: 1280,
      }),
      mixLayoutParams: new StartRtcCloudRecordingRequestMixLayoutParams({userPanes: panes}),
      maxIdleTime: 60,
    });
    let id: string | undefined;
    try {
      id = (await this.live!.startRtcCloudRecording(request)).body?.taskId;
    } catch (error) {
      throw new RecordingProviderError(`ARTC VOD StartRtcCloudRecording failed: ${
        error instanceof Error ? error.name : 'vendor error'}`);
    }
    if (!id || !/^[a-zA-Z0-9_-]{1,100}$/.test(id)) {
      throw new RecordingProviderError('ARTC VOD did not return a valid recording TaskId.');
    }
    const job: Task = {
      id, channel: room.providerRoomName, layout, state: 'recording', stopped: false,
      mediaId: null, videoUrl: null, size: 0, error: null,
    };
    this.jobs.set(room.roomCode, job);
    return this.view(job);
  }

  async stop(room: NamedRoomEntry) {
    const job = this.jobs.get(room.roomCode);
    if (!job) throw new RecordingProviderError('No ARTC VOD recording exists for this room.');
    if (!job.stopped) {
      this.ensureConfigured();
      try {
        await this.live!.stopRtcCloudRecording(new StopRtcCloudRecordingRequest({taskId: job.id}));
      } catch {
        throw new RecordingProviderError('ARTC VOD StopRtcCloudRecording failed.');
      }
      job.stopped = true;
      job.state = 'processing';
    }
    return this.view(job);
  }

  async status(room: NamedRoomEntry) {
    const job = this.jobs.get(room.roomCode);
    if (!job) return {
      provider: 'artc', recordingId: null, state: 'idle', layout: null,
      canDownload: false, fileName: null, fileSizeBytes: 0, error: null,
    };
    if (job.state === 'failed' || job.state === 'completed') return this.view(job);
    this.ensureConfigured();
    const result = await this.live!.describeRtcCloudRecordingFiles(
      new DescribeRtcCloudRecordingFilesRequest({taskId: job.id}),
    );
    const task = result.body?.taskInfo;
    if (task?.taskId !== job.id) {
      throw new RecordingProviderError('ARTC VOD returned a different recording TaskId.');
    }
    if (!job.stopped) return this.view(job);
    const finished = task.status === 'STOPPED';
    const file = task.recordFileList?.vodMediaList?.find((item) =>
      item.stream === 'Mix' && (item.mergedIds?.length || item.mediaIds?.length));
    const ids = file?.mergedIds?.length ? file.mergedIds : file?.mediaIds;
    // V1 exports only a single finalized MP4. Do not silently download a
    // random fragment if the vendor produced multiple media resources.
    if (finished && ids?.length === 1 && !job.videoUrl) {
      const mediaId = ids[0]!;
      const video = await this.getMp4(mediaId);
      if (video?.playURL) {
        job.videoUrl = video.playURL;
        job.mediaId = mediaId;
        job.size = video.size ?? 0;
        job.state = 'completed';
      }
    } else if (finished && (ids?.length ?? 0) > 1) {
      job.state = 'failed';
      job.error = 'ARTC VOD produced multiple segments; configure an MP4 merge/transcoding template.';
    }
    return this.view(job);
  }

  async download(room: NamedRoomEntry) {
    await this.status(room);
    const job = this.jobs.get(room.roomCode);
    if (!job?.videoUrl || job.state !== 'completed') {
      throw new RecordingProviderError('ARTC VOD MP4 is still being processed.');
    }
    const ticket = crypto.randomBytes(32).toString('base64url');
    this.tickets.set(ticket, {roomCode: room.roomCode, id: job.id, expires: Date.now() + 60_000});
    return {
      ...this.view(job),
      downloadUrl: `/rooms/${encodeURIComponent(room.roomCode)}/recording/export/${ticket}`,
      expiresInSeconds: 60,
    };
  }

  async consumeExport(roomCode: string, ticket: string) {
    const item = this.tickets.get(ticket);
    this.tickets.delete(ticket);
    const job = this.jobs.get(roomCode);
    if (!item || !job || item.roomCode !== roomCode || item.id !== job.id ||
        item.expires < Date.now() || job.state !== 'completed' ||
        !job.videoUrl || !this.acceptsVideoUrl(job.videoUrl)) {
      throw new RecordingProviderError('ARTC VOD download ticket invalid or expired.');
    }
    // Playback URLs are short-lived. Resolve again at download time instead
    // of returning the potentially expired URL discovered after recording.
    const fresh = job.mediaId ? await this.getMp4(job.mediaId) : null;
    if (!fresh?.playURL) {
      throw new RecordingProviderError('ARTC VOD MP4 download URL is no longer available.');
    }
    return {kind: 'remote' as const, url: fresh.playURL, filename: `artc-${job.id}.mp4`};
  }
}
