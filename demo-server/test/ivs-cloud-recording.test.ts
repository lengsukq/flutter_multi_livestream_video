import assert from 'node:assert/strict';
import test from 'node:test';

import {IvsCloudRecording, ivsCompositionLayout} from '../recording/ivs-cloud-recording.ts';
import {RecordingConfigurationError} from '../recording/livekit-cloud-recording.ts';
import type {RecordingObjectReader} from '../recording/s3-recording-storage.ts';
import type {IvsRoomEntry, NamedRoomEntry} from '../types.ts';

const room: IvsRoomEntry & NamedRoomEntry = {
  provider: 'ivs', roomCode: 'IVS321',
  stageArn: 'arn:aws:ivs:ap-northeast-1:123:stage/abc',
  providerRoomName: 'arn:aws:ivs:ap-northeast-1:123:stage/abc',
  createdAt: new Date().toISOString(), lastHeartbeatMs: Date.now(), attendees: [],
};

const env = {
  IVS_RECORDING_AWS_REGION: 'ap-northeast-1',
  IVS_RECORDING_S3_BUCKET: 'recordings-ivs-test',
  IVS_RECORDING_STORAGE_CONFIGURATION_ARN: 'arn:aws:ivs:ap-northeast-1:123:storage-configuration/abc',
  IVS_RECORDING_ENCODER_CONFIGURATION_ARN: 'arn:aws:ivs:ap-northeast-1:123:encoder-configuration/def',
  IVS_RECORDING_MEDIACONVERT_ROLE_ARN: 'arn:aws:iam::123:role/demo-mediaconvert',
};

test('IVS MP4 cloud recording refuses incomplete storage and MediaConvert configuration', async () => {
  const recorder = new IvsCloudRecording({});
  assert.equal(recorder.readiness().available, false);
  await assert.rejects(recorder.start(room, 'grid', 'H264_720P_30'), RecordingConfigurationError);
  assert.equal((await recorder.status(room)).canDownload, false);
});

test('IVS 1080p requires a separate matching encoder and speaker layout pins an explicitly featured host', async () => {
  assert.deepEqual(ivsCompositionLayout('grid'), {grid: {}});
  assert.deepEqual(ivsCompositionLayout('speaker'),
    {grid: {featuredParticipantAttribute: 'isFeatured'}});
  const missing = new IvsCloudRecording(env);
  await assert.rejects(
    missing.start(room, 'speaker', 'H264_1080P_30'),
    RecordingConfigurationError,
  );
  let selectedEncoder = '';
  let selectedLayout = '';
  const api = {
    async start(_stage: string, encoder: string, _storage: string, layout: string) {
      selectedEncoder = encoder;
      selectedLayout = layout;
      return {arn: 'arn:aws:ivs:ap-northeast-1:123:composition/new'};
    },
    async get() {return {state: 'ACTIVE'};},
    async stop() {},
    async convert() {return 'job-id';},
    async conversionStatus() {return 'PROGRESSING';},
  };
  const configured = new IvsCloudRecording({
    ...env, IVS_RECORDING_ENCODER_CONFIGURATION_ARN_1080P:
      'arn:aws:ivs:ap-northeast-1:123:encoder-configuration/hd',
  }, api);
  await configured.start(room, 'speaker', 'H264_1080P_30');
  assert.match(selectedEncoder, /encoder-configuration\/hd$/);
  assert.equal(selectedLayout, 'speaker');
});

test('IVS cloud service captures HLS, waits for recording-ended event, converts MP4 via AWS, and streams', async () => {
  const calls: string[] = [];
  const keys = new Set<string>();
  let outputKey = '';
  let jobState = 'PROGRESSING';
  const api = {
    async start(stageArn: string, encoder: string, storage: string) {
      assert.equal(stageArn, room.stageArn);
      assert.equal(encoder, env.IVS_RECORDING_ENCODER_CONFIGURATION_ARN);
      assert.equal(storage, env.IVS_RECORDING_STORAGE_CONFIGURATION_ARN);
      calls.push('ivs.start');
      return {arn: 'arn:aws:ivs:ap-northeast-1:123:composition/first', prefix: 'ivs-root/composite'};
    },
    async get(_arn: string) {
      calls.push('ivs.get');
      return {state: 'ACTIVE', prefix: 'ivs-root/composite'};
    },
    async stop(_arn: string) {calls.push('ivs.stop');},
    async convert(input: string, output: string, role: string) {
      calls.push('mediaconvert.create');
      assert.equal(input, 's3://recordings-ivs-test/ivs-root/composite/media/hls/multivariant.m3u8');
      assert.equal(role, env.IVS_RECORDING_MEDIACONVERT_ROLE_ARN);
      assert.match(output, /^s3:\/\/recordings-ivs-test\/flutter-realtime-demo\/[a-f\d-]{36}\/$/);
      outputKey = output.replace('s3://recordings-ivs-test/', '') + 'multivariant_demo.mp4';
      return 'mediaconvert-job-1';
    },
    async conversionStatus(id: string) {
      calls.push('mediaconvert.get');
      assert.equal(id, 'mediaconvert-job-1');
      return jobState;
    },
  };
  const store: RecordingObjectReader = {
    async exists(bucket, key) {
      assert.equal(bucket, env.IVS_RECORDING_S3_BUCKET);
      return keys.has(key);
    },
    async open(_bucket, key) {
      assert.equal(key, outputKey);
      return (async function* () {yield Buffer.from('mp4');})();
    },
    async remove(_bucket, key) {keys.delete(key);},
  };
  const recorder = new IvsCloudRecording(env, api, store);
  assert.equal(recorder.readiness().available, true);
  const started = await recorder.start(room, 'grid', 'H264_720P_30');
  assert.equal(started.state, 'recording');
  assert.equal(started.canDownload, false);
  assert.equal((await recorder.stop(room)).state, 'processing');
  assert.deepEqual(calls.slice(0, 2), ['ivs.start', 'ivs.stop']);
  assert.equal((await recorder.status(room)).state, 'processing');
  keys.add('ivs-root/composite/events/recording-ended.json');
  keys.add('ivs-root/composite/media/hls/multivariant.m3u8');
  assert.equal((await recorder.status(room)).state, 'processing');
  assert.ok(calls.includes('mediaconvert.create'));
  assert.ok(outputKey);
  await assert.rejects(recorder.download(room));
  jobState = 'COMPLETE';
  keys.add(outputKey);
  assert.equal((await recorder.status(room)).state, 'completed');
  const ticket = (await recorder.download(room)).downloadUrl.split('/').at(-1)!;
  const artifact = await recorder.consumeExport(room.roomCode, ticket);
  assert.equal(artifact.kind, 'stream');
  if (artifact.kind === 'stream') {
    await artifact.afterDownload?.();
  }
  assert.equal(keys.has(outputKey), false);
  assert.equal((await recorder.status(room)).canDownload, false);
  await assert.rejects(recorder.consumeExport(room.roomCode, ticket));
});
