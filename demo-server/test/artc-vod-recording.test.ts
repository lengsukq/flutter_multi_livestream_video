import assert from 'node:assert/strict';
import test from 'node:test';

import {ArtcVodRecording} from '../recording/artc-vod-recording.ts';
import {RecordingConfigurationError, RecordingProviderError} from '../recording/livekit-cloud-recording.ts';
import type {NamedRoomEntry} from '../types.ts';

const env = {
  ARTC_APP_ID: 'app-id',
  ALIBABA_CLOUD_ACCESS_KEY_ID: 'key',
  ALIBABA_CLOUD_ACCESS_KEY_SECRET: 'secret',
  ARTC_RECORDING_VOD_REGION: 'cn-shanghai',
  ARTC_RECORDING_VOD_STORAGE_LOCATION: 'outin-recording.oss-cn-shanghai.aliyuncs.com',
  ARTC_RECORDING_VOD_TRANSCODE_GROUP_ID: 'mp4-group',
  ARTC_RECORDING_VOD_HOSTS: 'video.example.test',
};
const room: NamedRoomEntry = {
  provider: 'artc', roomCode: 'R1234', providerRoomName: 'media-R1234',
  createdAt: new Date().toISOString(), lastHeartbeatMs: Date.now(),
  attendees: [{attendeeId: 'publisher-1', externalUserId: 'Host',
    joinedAt: new Date().toISOString(), role: 'host'}],
};

test('ARTC VOD missing storage config fails with explicit instructions (no OSS or S3 required)', async () => {
  const recorder = new ArtcVodRecording({ARTC_APP_ID: 'app-id'});
  assert.equal(recorder.readiness().available, false);
  assert.match(recorder.readiness().reason ?? '', /ARTC_RECORDING_VOD_STORAGE_LOCATION/);
  await assert.rejects(recorder.start(room, 'grid', 'H264_720P_30'), RecordingConfigurationError);
});

test('ARTC VOD refreshes recording subscriptions on status and preserves pinned host', async () => {
  const updates: Array<{subscribed: string[]; panes: string[]}> = [];
  const live = {
    async startRtcCloudRecording(req: any) {
      assert.equal(req.subscribeParams.subscribeUserIdList.length, 1);
      assert.equal(req.mixLayoutParams.userPanes[0].userId, 'publisher-1');
      assert.equal(req.mixTranscodeParams.videoWidth, 1920);
      assert.equal(req.mixTranscodeParams.videoFramerate, 30);
      return {body: {taskId: 'task-live-members'}};
    },
    async updateRtcCloudRecording(req: any) {
      assert.equal(req.taskId, 'task-live-members');
      updates.push({
        subscribed: req.subscribeParams.subscribeUserIdList.map((v: any) => v.userId),
        panes: req.mixLayoutParams.userPanes.map((v: any) => v.userId),
      });
      return {body: {taskId: 'task-live-members'}};
    },
    async describeRtcCloudRecordingFiles() {
      return {body: {taskInfo: {taskId: 'task-live-members', status: 'RECORDING'}}};
    },
  };
  const recorder = new ArtcVodRecording(env, live as never, {} as never);
  const changingRoom: NamedRoomEntry = {...room, attendees: [...room.attendees]};
  await recorder.start(changingRoom, 'speaker', 'H264_1080P_30');
  changingRoom.attendees.push({attendeeId: 'publisher-2', externalUserId: 'Student',
    joinedAt: new Date().toISOString(), role: 'participant'});
  await recorder.status(changingRoom);
  assert.deepEqual(updates[0], {
    subscribed: ['publisher-1', 'publisher-2'], panes: ['publisher-1'],
  });
  // Once the host leaves, the remaining publisher becomes the featured one.
  changingRoom.attendees = changingRoom.attendees.filter((user) => user.attendeeId !== 'publisher-1');
  await recorder.status(changingRoom);
  assert.deepEqual(updates[1], {subscribed: ['publisher-2'], panes: ['publisher-2']});
  await recorder.status(changingRoom);
  assert.equal(updates.length, 2, 'unchanged membership must not cause repeated vendor charges');
});

test('ARTC VOD uses Live RTC API and VOD MP4 with private one-time HTTP export', async () => {
  const calls: string[] = [];
  const live = {
    async startRtcCloudRecording(req: any) {
      calls.push('start');
      assert.equal(req.appId, 'app-id');
      assert.equal(req.channelId, 'media-R1234');
      assert.equal(req.recordParams.recordMode, 1);
      assert.equal(req.storageParams.storageType, 0);
      assert.equal(req.storageParams.vodParams.storageLocation,
        'outin-recording.oss-cn-shanghai.aliyuncs.com');
      assert.equal(req.storageParams.OSSParams, undefined);
      assert.equal(req.subscribeParams.subscribeUserIdList[0].userId, 'publisher-1');
      assert.equal(req.mixLayoutParams.userPanes.length, 1);
      return {body: {taskId: 'task-vod-1'}};
    },
    async stopRtcCloudRecording(req: any) {
      calls.push('stop');
      assert.equal(req.taskId, 'task-vod-1');
      return {body: {taskId: 'task-vod-1'}};
    },
    async describeRtcCloudRecordingFiles(req: any) {
      calls.push('status');
      assert.equal(req.taskId, 'task-vod-1');
      return {body: {taskInfo: {
        taskId: 'task-vod-1', status: 'STOPPED',
        recordFileList: {vodMediaList: [{
          stream: 'Mix', mediaIds: ['media-1'], mergedIds: [],
        }]},
      }}};
    },
  };
  const vod = {
    async getPlayInfo(req: any) {
      calls.push('play');
      assert.equal(req.videoId, 'media-1');
      assert.equal(req.formats, 'mp4');
      return {body: {playInfoList: {playInfo: [{
        format: 'mp4', playURL: 'https://video.example.test/recording.mp4?auth=test',
        encrypt: 0, status: 'Normal', size: 12000,
      }]}}};
    },
  };
  const recorder = new ArtcVodRecording(env, live as never, vod as never);
  assert.equal(recorder.readiness().available, true);
  assert.equal((await recorder.start(room, 'grid', 'H264_720P_30')).state, 'recording');
  assert.equal((await recorder.stop(room)).state, 'processing');
  const status = await recorder.status(room);
  assert.equal(status.state, 'completed');
  assert.equal(status.fileSizeBytes, 12000);
  const ticket = (await recorder.download(room)).downloadUrl.split('/').at(-1)!;
  assert.equal((await recorder.consumeExport('R1234', ticket)).kind, 'remote');
  await assert.rejects(recorder.consumeExport('R1234', ticket), RecordingProviderError);
  const another = (await recorder.download(room)).downloadUrl.split('/').at(-1)!;
  await assert.rejects(recorder.consumeExport('room-other', another), RecordingProviderError);
  assert.deepEqual(calls, ['start', 'stop', 'status', 'play', 'play']);
});

test('ARTC VOD rejects URL on unknown host or encrypted/non-MP4 playback', async () => {
  const live = {
    async startRtcCloudRecording() {return {body: {taskId: 'task-vod-2'}};},
    async stopRtcCloudRecording() {return {body: {taskId: 'task-vod-2'}};},
    async describeRtcCloudRecordingFiles() {return {body: {taskInfo: {
      taskId: 'task-vod-2', status: 'STOPPED',
      recordFileList: {vodMediaList: [{stream: 'Mix', mediaIds: ['video-2']}]},
    }}};},
  };
  const vod = {async getPlayInfo() {return {body: {playInfoList: {playInfo: [
    {format: 'mp4', encrypt: 1, status: 'Normal', playURL: 'https://video.example.test/encrypted.mp4'},
    {format: 'mp4', encrypt: 0, status: 'Normal', playURL: 'https://video.example.test.evil.invalid/x.mp4'},
    {format: 'm3u8', encrypt: 0, status: 'Normal', playURL: 'https://video.example.test/x.m3u8'},
  ]}}};}};
  const recorder = new ArtcVodRecording(env, live as never, vod as never);
  await recorder.start(room, 'grid', 'H264_720P_30');
  await recorder.stop(room);
  assert.equal((await recorder.status(room)).state, 'processing');
  await assert.rejects(recorder.download(room), RecordingProviderError);
});
