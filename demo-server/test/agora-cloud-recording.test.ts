import assert from 'node:assert/strict';
import {once} from 'node:events';
import test from 'node:test';
import express from 'express';
import type {AddressInfo} from 'node:net';

import type {NamedRoomEntry} from '../types.ts';
import {issueParticipantCredential} from '../participant-credential.ts';
import {AgoraCloudRecording} from '../recording/agora-cloud-recording.ts';
import type {RecordingObjectReader} from '../recording/s3-recording-storage.ts';
import {RecordingConfigurationError} from '../recording/livekit-cloud-recording.ts';
import {registerRecordingRoutes} from '../routes/recording-routes.ts';

const room: NamedRoomEntry = {
  provider: 'agora', roomCode: 'R1234', providerRoomName: 'media-R1234',
  createdAt: new Date().toISOString(), lastHeartbeatMs: Date.now(),
  attendees: [
    {attendeeId: 'host', role: 'host', externalUserId: 'host', joinedAt: new Date().toISOString()},
    {attendeeId: 'viewer', role: 'participant', externalUserId: 'viewer', joinedAt: new Date().toISOString()},
  ],
};

const env: NodeJS.ProcessEnv = {
  AGORA_APP_ID: '0123456789abcdef0123456789abcdef',
  AGORA_APP_CERTIFICATE: 'abcdef0123456789abcdef0123456789',
  AGORA_CUSTOMER_ID: 'agora-customer-id',
  AGORA_CUSTOMER_SECRET: 'customer-secret',
  AGORA_RECORDING_S3_BUCKET: 'recordings-example-bucket',
  AGORA_RECORDING_S3_REGION: 'us-east-1',
  AGORA_RECORDING_S3_REGION_CODE: '0',
  AGORA_RECORDING_S3_ACCESS_KEY: 'test-access',
  AGORA_RECORDING_S3_SECRET_KEY: 'test-secret',
};

function fixture(options: {omitStopFileList?: boolean; acquireStatus?: number} = {}) {
  const calls: Array<{method: string; path: string; payload: Record<string, any> | null}> = [];
  const files = new Map<string, Buffer>();
  let fileKey = '';
  const transport = (async (request: string | URL | Request, init?: RequestInit) => {
    const url = new URL(String(request));
    assert.equal(url.origin, 'https://api.sd-rtn.com');
    const path = url.pathname;
    const method = init?.method ?? '';
    const payload = init?.body ? JSON.parse(String(init.body)) : null;
    const auth = new Headers(init?.headers).get('Authorization');
    assert.equal(auth, 'Basic ' + Buffer.from('agora-customer-id:customer-secret').toString('base64'));
    calls.push({method, path, payload});
    if (path.endsWith('/acquire')) {
      if (options.acquireStatus) return new Response(null, {status: options.acquireStatus});
      return Response.json({resourceId: 'res-1'});
    }
    if (path.endsWith('/start')) {
      assert.match(path, /\/mode\/mix\/start$/);
      assert.equal(payload.cname, room.providerRoomName);
      assert.match(payload.uid, /^[1-9][0-9]*$/);
      assert.equal(payload.clientRequest.storageConfig.vendor, 1);
      assert.equal(payload.clientRequest.storageConfig.bucket, 'recordings-example-bucket');
      assert.deepEqual(payload.clientRequest.recordingFileConfig.avFileType, ['hls', 'mp4']);
      assert.equal(payload.clientRequest.recordingConfig.streamTypes, 2);
      assert.equal(payload.clientRequest.recordingConfig.channelType, 1);
      assert.equal(typeof payload.clientRequest.token, 'string');
      const video = payload.clientRequest.recordingConfig.transcodingConfig;
      assert.ok(video.width === 1280 || video.width === 1920);
      assert.equal(video.height, video.width === 1920 ? 1080 : 720);
      assert.ok(video.mixedVideoLayout === 0 || video.mixedVideoLayout === 1);
      assert.equal(payload.clientRequest.transcodingConfig, undefined);
      const prefix = payload.clientRequest.storageConfig.fileNamePrefix as string[];
      assert.ok(prefix.every((part) => /^[a-zA-Z0-9]+$/.test(part)));
      assert.ok(prefix.join('/').length <= 128);
      fileKey = [...prefix, 'video.mp4'].join('/');
      return Response.json({resourceId: 'res-1', sid: 'sid-1'});
    }
    if (path.endsWith('/query')) {
      assert.match(path, /\/mode\/mix\/query$/);
      assert.equal(method, 'GET');
      return Response.json({resourceId: 'res-1', sid: 'sid-1', serverResponse: {}});
    }
    if (path.endsWith('/stop')) {
      assert.match(path, /\/mode\/mix\/stop$/);
      assert.equal(payload.clientRequest.async_stop, false);
      return Response.json({
        resourceId: 'res-1', sid: 'sid-1',
        serverResponse: {
          uploadingStatus: 'uploaded',
          ...(options.omitStopFileList ? {} : {
            fileListMode: 'json',
            fileList: [
              {fileName: 'video.m3u8', trackType: 'audio_and_video'},
              {fileName: 'video.mp4', trackType: 'audio_and_video'},
            ],
          }),
        },
      });
    }
    throw Error('Unexpected Agora action: ' + path);
  }) as typeof fetch;
  const store: RecordingObjectReader = {
    async list(_bucket, prefix) {
      return [...files.keys()].filter((key) => key.startsWith(prefix) && key.endsWith('.mp4'));
    },
    async exists(_bucket, key) {
      assert.equal(key, fileKey);
      return files.has(key);
    },
    async open(_bucket, key) {
      const value = files.get(key);
      if (!value) throw Error('Not uploaded');
      return (async function* () {yield value;})();
    },
    async remove(_bucket, key) {
      files.delete(key);
    },
  };
  return {recorder: new AgoraCloudRecording(env, transport, store), calls, files, key: () => fileKey};
}

test('Agora hosted recorder accepts blank storage configuration until start, without Linux', async () => {
  const recorder = new AgoraCloudRecording({
    AGORA_APP_ID: env.AGORA_APP_ID,
    AGORA_APP_CERTIFICATE: env.AGORA_APP_CERTIFICATE,
    AGORA_CUSTOMER_ID: env.AGORA_CUSTOMER_ID,
    AGORA_CUSTOMER_SECRET: env.AGORA_CUSTOMER_SECRET,
  });
  assert.equal(recorder.readiness().available, false);
  await assert.rejects(recorder.start(room, 'grid', 'H264_720P_30'), RecordingConfigurationError);
  assert.equal((await recorder.status(room)).state, 'idle');
});

test('Agora room closure stops active capture exactly once without waiting for S3 upload', async () => {
  const {recorder, calls} = fixture();
  await recorder.stopIfActive(room);
  assert.equal(calls.length, 0, 'no recording requires no Agora API calls');
  await recorder.start(room, 'grid', 'H264_720P_30');
  await recorder.stopIfActive(room);
  assert.equal(calls.filter((call) => call.path.endsWith('/stop')).length, 1);
  await recorder.stopIfActive(room);
  assert.equal(calls.filter((call) => call.path.endsWith('/stop')).length, 1);
});

test('Agora stop can omit fileList: locate the uploaded MP4 using the owned S3 prefix', async () => {
  const {recorder, files, key} = fixture({omitStopFileList: true});
  await recorder.start(room, 'grid', 'H264_720P_30');
  assert.equal((await recorder.stop(room)).state, 'processing');
  files.set(key(), Buffer.from('test-mp4'));
  const status = await recorder.status(room);
  assert.equal(status.state, 'completed');
  assert.equal(status.fileName, 'video.mp4');
  assert.equal(status.canDownload, true);
});

test('Agora REST 401 reports Customer ID/Secret guidance without exposing credentials', async () => {
  const {recorder} = fixture({acquireStatus: 401});
  await assert.rejects(
    recorder.start(room, 'grid', 'H264_720P_30'),
    (error: unknown) => {
      assert.match(String(error), /HTTP 401/);
      assert.match(String(error), /Customer ID\/Secret/);
      assert.doesNotMatch(String(error), /customer-secret/);
      return true;
    },
  );
  assert.equal((await recorder.status(room)).state, 'failed');
});

test('Agora cloud recording calls Acquire, Start, Query, Stop and waits for remote MP4', async () => {
  const {recorder, calls, files, key} = fixture();
  assert.equal(recorder.readiness().available, true);
  const started = await recorder.start(room, 'speaker', 'H264_1080P_30');
  assert.equal(started.state, 'recording');
  assert.equal(started.recordingId, 'sid-1');
  assert.equal(started.canDownload, false);
  await assert.rejects(recorder.start(room, 'grid', 'H264_720P_30'));
  assert.equal((await recorder.status(room)).state, 'recording');
  assert.equal((await recorder.stop(room)).state, 'processing');
  assert.equal(calls.map((c) => c.path.split('/').at(-1)).join(','), 'acquire,start,query,stop');
  const before = calls.length;
  await recorder.stop(room);
  assert.equal(calls.length, before); // idempotent stop
  const bytes = Buffer.alloc(2048);
  bytes.write('ftyp', 4); bytes.write('moov', 1000);
  files.set(key(), bytes);
  assert.equal((await recorder.status(room)).state, 'completed');
  const exported = await recorder.download(room);
  assert.ok(exported.downloadUrl.includes('/recording/export/'));
  const ticket = exported.downloadUrl.split('/').at(-1)!;
  await assert.rejects(recorder.consumeExport('R2345', ticket));
  await assert.rejects(recorder.consumeExport(room.roomCode, ticket));
  const second = await recorder.download(room);
  const artifact = await recorder.consumeExport(room.roomCode, second.downloadUrl.split('/').at(-1)!);
  assert.equal(artifact.kind, 'stream');
  await assert.rejects(recorder.consumeExport(room.roomCode, second.downloadUrl.split('/').at(-1)!));
});

test('Agora cloud MP4 uses the existing host-authenticated one-use download route', async () => {
  const {recorder, files, key} = fixture();
  const credential = issueParticipantCredential(room, 'host');
  const viewerCredential = issueParticipantCredential(room, 'viewer');
  const app = express();
  app.use(express.json());
  registerRecordingRoutes(app, {
    resolveRoom: async (ref) => ref === room.roomCode ? room : null,
    recorders: new Map([['agora', recorder]]),
    contractError: (res, status, code, message) => res.status(status).json({error: {code, message}}),
  });
  const server = app.listen(0, '127.0.0.1');
  try {
    if (!server.listening) await once(server, 'listening');
    const root = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
    const route = `${root}/rooms/${room.roomCode}/recording`;
    const post = (action: string, attendee = 'host', token = credential) =>
      fetch(`${route}/${action}`, {
        method: 'POST', headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({requesterParticipantId: attendee, participantCredential: token, layout: 'grid'}),
      });
    assert.equal((await post('start', 'viewer', viewerCredential)).status, 403);
    assert.equal((await post('start')).status, 200);
    assert.equal((await post('stop')).status, 200);
    const bytes = Buffer.alloc(1024);
    bytes.write('ftyp', 4); bytes.write('moov', 750);
    files.set(key(), bytes);
    const status = await (await post('status')).json() as {canDownload: boolean};
    assert.equal(status.canDownload, true);
    const ticket = await (await post('download')).json() as {downloadUrl: string};
    assert.equal((await fetch(root + ticket.downloadUrl.replace('/R1234/', '/OTHER/'))).status, 404);
    const response = await fetch(root + ticket.downloadUrl);
    assert.equal(response.status, 200);
    assert.deepEqual(Buffer.from(await response.arrayBuffer()), bytes);
    assert.match(response.headers.get('content-disposition') ?? '', /video.mp4/);
    assert.equal(files.has(key()), false, 'Demo cleans up uploaded MP4 after a complete download');
    assert.equal((await (await post('status')).json() as {canDownload: boolean}).canDownload, false);
    assert.equal((await fetch(root + ticket.downloadUrl)).status, 404);
  } finally {
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }
});
