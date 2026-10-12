import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import test from 'node:test';

import type {NamedRoomEntry} from '../types.ts';
import {TrtcCloudRecording} from '../recording/trtc-cloud-recording.ts';
import type {RecordingObjectReader} from '../recording/s3-recording-storage.ts';
import {
  RecordingConfigurationError, RecordingProviderError,
} from '../recording/livekit-cloud-recording.ts';

const entry: NamedRoomEntry = {
  provider: 'trtc', roomCode: 'room1', providerRoomName: 'media-room1',
  createdAt: new Date().toISOString(), lastHeartbeatMs: Date.now(), attendees: [],
};

const env: NodeJS.ProcessEnv = {
  TRTC_SDK_APP_ID: '1400000001',
  TRTC_SDK_SECRET_KEY: 'test-signature-secret',
  TENCENTCLOUD_SECRET_ID: 'test-secret-id',
  TENCENTCLOUD_SECRET_KEY: 'test-api-secret',
  TRTC_RECORDING_CALLBACK_KEY: 'test-callback-key',
  TRTC_RECORDING_VOD_HOSTS: 'media.example.test',
};

function createRecorder() {
  const actions: string[] = [];
  const transport = (async (_url: string | URL | Request, options?: RequestInit) => {
    const headers = new Headers(options?.headers);
    const action = headers.get('x-tc-action') ?? '';
    const payload = JSON.parse(String(options?.body)) as Record<string, any>;
    actions.push(action);
    assert.match(headers.get('authorization') ?? '', /TC3-HMAC-SHA256 Credential=/);
    if (action === 'CreateCloudRecording') {
      assert.equal(payload.RoomId, 'media-room1');
      assert.equal(payload.RoomIdType, 0);
      assert.equal(payload.RecordParams.RecordMode, 2);
      assert.equal(payload.StorageParams.CloudVod.TencentVod.ExpireTime, 0);
    }
    if (action === 'DeleteCloudRecording' || action === 'DescribeCloudRecording') {
      assert.equal(payload.TaskId, 'task-1');
    }
    const result = switchAction(action);
    return new Response(JSON.stringify({Response: result}), {status: 200});
  }) as typeof fetch;
  return {recorder: new TrtcCloudRecording(env, transport), actions};
}

function switchAction(action: string): object {
  if (action === 'CreateCloudRecording') return {TaskId: 'task-1'};
  if (action === 'DescribeCloudRecording') return {Status: 'InProgress'};
  if (action === 'DeleteCloudRecording') return {TaskId: 'task-1'};
  throw new Error(`Unexpected TRTC action ${action}`);
}

function callback(type: number, status: number, url = 'https://media.example.test/rec.mp4') {
  const body = Buffer.from(JSON.stringify({
    EventGroupId: 3, EventType: type, CallbackTs: Date.now(),
    EventInfo: {
      RoomId: 'media-room1', TaskId: 'task-1',
      Payload: {
        Status: status,
        TencentVod: {FileId: 'file-1', VideoUrl: url, CacheFile: 'rec.mp4'},
      },
    },
  }));
  const sign = crypto.createHmac('sha256', env.TRTC_RECORDING_CALLBACK_KEY!)
    .update(body).digest('base64');
  return {body, sign};
}

test('TRTC recording requires trusted cloud config; missing keys fail before any API call', async () => {
  const recorder = new TrtcCloudRecording({});
  await assert.rejects(recorder.start(entry, 'grid', 'H264_720P_30'), RecordingConfigurationError);
  assert.equal((await recorder.status(entry)).state, 'idle');
});

test('TRTC AWS S3 is optional and requires explicit storage credentials', async () => {
  const recorder = new TrtcCloudRecording({
    ...env, TRTC_RECORDING_STORAGE: 's3', TRTC_RECORDING_VOD_HOSTS: '',
  });
  assert.equal(recorder.readiness().available, false);
  assert.match(recorder.readiness().reason ?? '', /TRTC_RECORDING_S3/);
  await assert.rejects(recorder.start(entry, 'grid', 'H264_720P_30'), RecordingConfigurationError);
});

test('TRTC AWS S3 starts native CloudStorage, exports only verified signed MP4 and scopes the ticket', async () => {
  const written = new Set<string>();
  const reader: RecordingObjectReader = {
    async exists(bucket, key) {
      assert.equal(bucket, 'rec-trtc-test');
      return written.has(key);
    },
    async open(bucket, key) {
      assert.equal(bucket, 'rec-trtc-test');
      assert.ok(written.has(key));
      return (async function* () {yield Buffer.from('mock recording');})();
    },
  };
  const requests: Record<string, any>[] = [];
  const transport = (async (_url: string | URL | Request, options?: RequestInit) => {
    const request = JSON.parse(String(options?.body));
    requests.push(request);
    if (new Headers(options?.headers).get('X-TC-Action') === 'CreateCloudRecording') {
      assert.equal(request.RoomIdType, 0);
      assert.equal(request.StorageParams.CloudStorage.Vendor, 1);
      assert.deepEqual(request.StorageParams.CloudStorage.FileNamePrefix, [
        'flutter_realtime_demo', 'trtc',
      ]);
      assert.equal(request.StorageParams.CloudStorage.Bucket, 'rec-trtc-test');
      assert.equal(request.StorageParams.CloudVod, undefined);
      return Response.json({Response: {TaskId: 'task-1'}});
    }
    return Response.json({Response: {TaskId: 'task-1'}});
  }) as typeof fetch;
  const recorder = new TrtcCloudRecording({
    ...env, TRTC_RECORDING_STORAGE: 's3', TRTC_RECORDING_VOD_HOSTS: '',
    TRTC_RECORDING_S3_BUCKET: 'rec-trtc-test',
    TRTC_RECORDING_S3_REGION: 'ap-southeast-1',
    TRTC_RECORDING_S3_ACCESS_KEY: 'aws-key',
    TRTC_RECORDING_S3_SECRET_KEY: 'aws-secret',
  }, transport, reader);
  assert.equal(recorder.readiness().available, true);
  const start = await recorder.start(entry, 'grid', 'H264_720P_30');
  assert.equal(start.state, 'recording');
  await recorder.stop(entry);
  const sign = (data: Buffer) => crypto.createHmac('sha256', env.TRTC_RECORDING_CALLBACK_KEY!)
    .update(data).digest('base64');
  const callbackBody = (type: number, filename: string) => Buffer.from(JSON.stringify({
    EventGroupId: 3, EventType: type, CallbackTs: Date.now(),
    EventInfo: {RoomId: 'media-room1', TaskId: 'task-1',
      Payload: {Status: 0, FileList: [filename], TencentVod: {VideoUrl: 'https://media.example.test/rec.mp4'}}},
  }));
  const vodCallback = callbackBody(311, 'recording.mp4');
  assert.equal(recorder.receiveCallback(vodCallback, sign(vodCallback), '1400000001'), true);
  assert.equal((await recorder.status(entry)).state, 'processing');
  const attack = callbackBody(310, '../secrets.mp4');
  assert.equal(recorder.receiveCallback(attack, sign(attack), '1400000001'), true);
  assert.equal((await recorder.status(entry)).state, 'failed');
  // Recreate a fresh task after the invalid artifact.
  await recorder.start(entry, 'grid', 'H264_720P_30');
  await recorder.stop(entry);
  const good = callbackBody(310, 'recording.mp4');
  assert.equal(recorder.receiveCallback(good, 'invalid', '1400000001'), false);
  assert.equal(recorder.receiveCallback(good, sign(good), '1400000001'), true);
  assert.equal((await recorder.status(entry)).state, 'processing');
  const key = 'flutter_realtime_demo/trtc/task-1/recording.mp4';
  written.add(key);
  assert.equal((await recorder.status(entry)).state, 'completed');
  const issued = await recorder.download(entry);
  assert.equal(issued.canDownload, true);
  const ticket = issued.downloadUrl.split('/').at(-1)!;
  await assert.rejects(recorder.consumeExport('another-room', ticket), RecordingProviderError);
  const ticket2 = (await recorder.download(entry)).downloadUrl.split('/').at(-1)!;
  assert.equal((await recorder.consumeExport('room1', ticket2)).kind, 'stream');
  await assert.rejects(recorder.consumeExport('room1', ticket2), RecordingProviderError);
  assert.equal(requests.length, 4);
});

test('TRTC start/describe/stop produce real task id; MP4 export requires signed upload completion', async () => {
  const {recorder, actions} = createRecorder();
  const started = await recorder.start(entry, 'grid', 'H264_720P_30');
  assert.equal(started.recordingId, 'task-1');
  assert.equal(started.canDownload, false);
  assert.equal((await recorder.status(entry)).state, 'recording');
  const stopped = await recorder.stop(entry);
  assert.equal(stopped.state, 'processing');
  await assert.rejects(recorder.download(entry), RecordingProviderError);

  const record = callback(311, 0);
  assert.equal(recorder.receiveCallback(record.body, 'wrong', '1400000001'), false);
  assert.equal(recorder.receiveCallback(record.body, record.sign, '999'), false);
  assert.equal((await recorder.status(entry)).state, 'processing');
  assert.equal(recorder.receiveCallback(record.body, record.sign, '1400000001'), true);
  assert.equal((await recorder.status(entry)).state, 'completed');
  const result = await recorder.download(entry);
  assert.equal(result.canDownload, true);
  assert.match(result.downloadUrl, /\/rooms\/room1\/recording\/export\//);
  const ticket = result.downloadUrl.split('/').at(-1)!;
  const artifact = await recorder.consumeExport('room1', ticket);
  assert.deepEqual(artifact, {
    kind: 'remote', url: 'https://media.example.test/rec.mp4',
    filename: 'trtc-task-1.mp4',
  });
  await assert.rejects(recorder.consumeExport('room1', ticket), RecordingProviderError);
  assert.deepEqual(actions, [
    'CreateCloudRecording', 'DescribeCloudRecording', 'DeleteCloudRecording',
  ]);
});

test('TRTC rejects a signed upload callback with unlisted host or insecure HTTP URL', async () => {
  const {recorder} = createRecorder();
  await recorder.start(entry, 'speaker', 'H264_720P_30');
  await recorder.stop(entry);
  const attack = callback(311, 0, 'https://media.example.test.evil.invalid/rec.mp4');
  assert.equal(recorder.receiveCallback(attack.body, attack.sign, '1400000001'), true);
  assert.equal((await recorder.status(entry)).state, 'failed');
  await assert.rejects(recorder.download(entry), RecordingProviderError);
});

test('TRTC upload callback is scoped to the exact recording task and room', async () => {
  const {recorder} = createRecorder();
  await recorder.start(entry, 'grid', 'H264_720P_30');
  await recorder.stop(entry);
  const item = callback(311, 0);
  const wrongRoom = Buffer.from(item.body.toString().replace('media-room1', 'media-room2'));
  const signature = crypto.createHmac('sha256', env.TRTC_RECORDING_CALLBACK_KEY!)
    .update(wrongRoom).digest('base64');
  assert.equal(recorder.receiveCallback(wrongRoom, signature, '1400000001'), false);
  assert.equal((await recorder.status(entry)).state, 'processing');
});
