import assert from 'node:assert/strict';
import test from 'node:test';

import {LiveKitCloudRecording, RecordingConfigurationError} from '../recording/livekit-cloud-recording.ts';
import {ChimeCloudRecording, chimeCompositedVideo} from '../recording/chime-cloud-recording.ts';
import {ArtcCloudRecording} from '../recording/artc-cloud-recording.ts';
import type {RecordingObjectReader} from '../recording/s3-recording-storage.ts';
import type {NamedRoomEntry} from '../types.ts';

const entry = (provider: string): NamedRoomEntry => ({
  provider, roomCode: 'R4567', providerRoomName: 'media-R4567',
  createdAt: new Date().toISOString(), lastHeartbeatMs: Date.now(),
  attendees: [],
});

test('Chime maps selected bitrate preset and speaker content-share layout to AWS configuration', () => {
  assert.equal(chimeCompositedVideo('grid', 'H264_720P_30').Resolution, 'HD');
  const layout = chimeCompositedVideo('speaker', 'H264_1080P_30');
  assert.equal(layout.Resolution, 'FHD');
  assert.equal(layout.GridViewConfiguration.ContentShareLayout, 'ActiveSpeakerOnly');
  assert.equal(layout.Layout, 'GridView');
});

test('ARTC official SDK client can be constructed with valid cloud env even before storage is used', () => {
  const recorder = new ArtcCloudRecording({
    ARTC_APP_ID: 'app-id', ARTC_RECORDING_TEMPLATE_ID: 'template-1',
    ALIBABA_CLOUD_ACCESS_KEY_ID: 'api-key', ALIBABA_CLOUD_ACCESS_KEY_SECRET: 'api-secret',
    ARTC_RECORDING_OSS_BUCKET: 'example-artc-recording',
    ARTC_RECORDING_OSS_REGION: 'oss-cn-shanghai',
    ARTC_RECORDING_OSS_REGION_CODE: '1',
    ARTC_RECORDING_OSS_ACCESS_KEY: 'oss-access',
    ARTC_RECORDING_OSS_SECRET_KEY: 'oss-secret',
  });
  assert.equal(recorder.readiness().available, true);
});

const media = Buffer.from('fake unit-test MP4');
const found = new Set<string>();
const objectReader: RecordingObjectReader = {
  async exists(bucket, key) {
    assert.ok(bucket);
    return found.has(key);
  },
  async open(_bucket, key) {
    assert.ok(found.has(key));
    return (async function* () {yield media;})();
  },
};

test('LiveKit Cloud mode requires cloud storage but not any local Egress worker', async () => {
  const env = {LIVEKIT_URL: 'wss://livekit.example.com', LIVEKIT_API_KEY: 'key', LIVEKIT_API_SECRET: 'secret'};
  const unavailable = new LiveKitCloudRecording(env, fetch, objectReader);
  assert.equal(unavailable.readiness().available, false);
  await assert.rejects(unavailable.start(entry('livekit'), 'grid'), RecordingConfigurationError);
});

test('LiveKit Cloud Egress receives S3 StorageConfig and streams MP4 after StopEgress', async () => {
  const sent: Array<{action: string; body: Record<string, any>}> = [];
  const transport = (async (uri: string | URL | Request, opts?: RequestInit) => {
    const action = String(uri).split('/').at(-1)!;
    const body = JSON.parse(String(opts?.body));
    sent.push({action, body});
    if (action === 'StartEgress') return Response.json({
      egress_id: 'EG_cloud', room_name: 'media-R4567', status: 'EGRESS_ACTIVE',
    });
    if (action === 'StopEgress') return Response.json({
      egress_id: 'EG_cloud', room_name: 'media-R4567', status: 'EGRESS_ENDING',
    });
    return Response.json({items: []});
  }) as typeof fetch;
  const recorder = new LiveKitCloudRecording({
    LIVEKIT_URL: 'wss://livekit.example.com',
    LIVEKIT_API_KEY: 'key', LIVEKIT_API_SECRET: 'secret',
    LIVEKIT_RECORDING_S3_BUCKET: 'recording-test-bucket',
    LIVEKIT_RECORDING_S3_REGION: 'us-east-1',
    LIVEKIT_RECORDING_S3_ACCESS_KEY: 'key-id',
    LIVEKIT_RECORDING_S3_SECRET_KEY: 'key-secret',
  }, transport, objectReader);
  assert.equal(recorder.readiness().available, true);
  const room = entry('livekit');
  const start = await recorder.start(room, 'grid');
  assert.equal(start.recordingId, 'EG_cloud');
  assert.equal(sent[0]!.body.storage.s3.bucket, 'recording-test-bucket');
  const key = sent[0]!.body.outputs[0].file.filepath as string;
  assert.match(key, /^flutter-realtime-demo\/[a-f\d-]{36}\.mp4$/);
  assert.equal(sent[0]!.body.storage.s3.secret, 'key-secret');
  assert.equal((await recorder.stop(room)).canDownload, false);
  found.add(key);
  assert.equal((await recorder.status(room)).state, 'completed');
  const ticket = (await recorder.download(room)).downloadUrl.split('/').at(-1)!;
  const result = await recorder.consumeExport(room.roomCode, ticket);
  assert.equal(result.kind, 'stream');
  await assert.rejects(recorder.consumeExport(room.roomCode, ticket));
});

test('Chime cloud capture -> concat -> S3 MP4 uses vendor APIs and no local recording', async () => {
  const calls: string[] = [];
  const recorder = new ChimeCloudRecording({CHIME_RECORDING_S3_BUCKET: 'recordings-chime'}, {
    async start(meetingArn, bucketArn) {
      assert.equal(meetingArn, 'arn:aws:chime:us-east-1:123:meeting/abc');
      assert.equal(bucketArn, 'arn:aws:s3:::recordings-chime');
      calls.push('capture');
      return {id: 'capture-id', arn: 'arn:aws:chime:us-east-1:123:media-pipeline/capture-id'};
    },
    async concatenate(_source, dest) {
      assert.match(dest, /^arn:aws:s3:::recordings-chime\/flutter-realtime-demo\/[a-f\d-]{36}$/);
      calls.push('concat');
      found.add(dest.replace('arn:aws:s3:::recordings-chime/', '') + '/composited-video/concat-id.mp4');
      return 'concat-id';
    },
    async stopCapture(id) {assert.equal(id, 'capture-id');calls.push('stop');},
    async concatenationStatus(id) {assert.equal(id, 'concat-id'); calls.push('status');return 'Stopped';},
  }, objectReader);
  const room = {
    ...entry('chime'),
    meeting: {MeetingId: 'abc', MeetingArn: 'arn:aws:chime:us-east-1:123:meeting/abc', TenantIds: []},
  };
  assert.equal((await recorder.start(room, 'grid', 'H264_720P_30')).state, 'recording');
  assert.equal((await recorder.stop(room)).state, 'processing');
  assert.equal((await recorder.status(room)).state, 'completed');
  assert.deepEqual(calls, ['capture', 'concat', 'stop', 'status']);
  const ticket = (await recorder.download(room)).downloadUrl.split('/').at(-1)!;
  assert.equal((await recorder.consumeExport(room.roomCode, ticket)).kind, 'stream');
});

test('ARTC cloud recorder requires storage credentials and records via Alibaba API SDK', async () => {
  const missing = new ArtcCloudRecording({ARTC_APP_ID: 'app-id'});
  assert.equal(missing.readiness().available, false);
  assert.deepEqual(missing.supportedLayouts, ['grid']);
  await assert.rejects(missing.start(entry('artc'), 'grid', 'H264_720P_30'), RecordingConfigurationError);
  const calls: string[] = [];
  let task = '';
  const recorder = new ArtcCloudRecording({
    ARTC_APP_ID: 'app-id', ARTC_RECORDING_TEMPLATE_ID: 'template-grid',
    ALIBABA_CLOUD_ACCESS_KEY_ID: 'access', ALIBABA_CLOUD_ACCESS_KEY_SECRET: 'secret',
    ARTC_RECORDING_OSS_BUCKET: 'recording-artc-test',
    ARTC_RECORDING_OSS_REGION: 'oss-cn-shanghai',
    ARTC_RECORDING_OSS_REGION_CODE: '1',
    ARTC_RECORDING_OSS_ACCESS_KEY: 'access', ARTC_RECORDING_OSS_SECRET_KEY: 'secret',
  }, {
    async startCloudRecord(req: any) {
      calls.push('start');
      assert.equal(req.templateId, 'template-grid');
      assert.equal(req.storageConfig.bucket, 'recording-artc-test');
      task = req.taskId;
      return {body: {taskId: req.taskId}} as never;
    },
    async stopCloudRecord(req: any) {
      calls.push('stop'); assert.equal(req.taskId, task);return {body: {taskId: task}} as never;
    },
    async describeCloudRecordStatus(_req: any) {
      calls.push('describe');return {body: {status: 1}} as never;
    },
    async describeAppRecordingFiles(req: any) {
      calls.push('files');
      assert.deepEqual(req.taskIds, [task]);
      const key = `record/app-id/media-R4567_${task}/playlist.mp4`;
      found.add(key);
      return {body: {items: [{
        taskId: task, channelId: 'media-R4567',
        bucket: 'recording-artc-test', filePath: key, fileSize: 1024,
      }]}} as never;
    },
  } as never, objectReader);
  assert.deepEqual(recorder.supportedLayouts, ['grid']);
  const room = entry('artc');
  const started = await recorder.start(room, 'grid', 'H264_720P_30');
  assert.equal(started.state, 'recording');
  assert.equal((await recorder.status(room)).state, 'recording');
  assert.equal((await recorder.stop(room)).state, 'processing');
  assert.equal((await recorder.status(room)).state, 'completed');
  assert.deepEqual(calls, ['start', 'describe', 'stop', 'files']);
  const ticket = (await recorder.download(room)).downloadUrl.split('/').at(-1)!;
  assert.equal((await recorder.consumeExport(room.roomCode, ticket)).kind, 'stream');
});
