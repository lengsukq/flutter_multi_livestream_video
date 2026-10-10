import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import {mkdtemp, rm, writeFile} from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import type {NamedRoomEntry} from '../types.ts';
import {
  LiveKitCloudRecording,
  RecordingConfigurationError,
  RecordingProviderError,
} from '../recording/livekit-cloud-recording.ts';

const room = (): NamedRoomEntry => ({
  provider: 'livekit', roomCode: 'abc123',
  providerRoomName: 'media-abc123', attendees: [],
  createdAt: new Date().toISOString(), lastHeartbeatMs: Date.now(),
});

function mockLiveKit() {
  const calls: Array<{method: string; body: any}> = [];
  let status = 'EGRESS_ACTIVE';
  const transport = (async (input: string | URL | Request, init?: RequestInit) => {
    const url = new URL(String(input));
    const method = url.pathname.split('/').at(-1)!;
    const body = JSON.parse(String(init?.body));
    calls.push({method, body});
    assert.equal(url.protocol, 'https:');
    const token = String((init?.headers as Record<string, string>)?.Authorization ?? '');
    const grants = JSON.parse(Buffer.from(token.split('.')[1] ?? '', 'base64url').toString());
    assert.equal(grants.video.roomRecord, true);
    if (method === 'StartEgress') {
      return new Response(JSON.stringify({
        egress_id: 'EG_1', room_name: 'media-abc123', status: 'EGRESS_STARTING',
      }), {status: 200});
    }
    if (method === 'StopEgress') {
      assert.equal(body.egress_id, 'EG_1');
      return new Response(JSON.stringify({
        egress_id: 'EG_1', room_name: 'media-abc123', status: 'EGRESS_ENDING',
      }), {status: 200});
    }
    return new Response(JSON.stringify({items: [{
      egress_id: 'EG_1', room_name: 'media-abc123', status,
    }]}), {status: 200});
  }) as typeof fetch;
  return {transport, calls, setStatus: (next: string) => {status = next;}};
}

test('no storage credentials: only self-hosted LiveKit + absolute shared directories', async () => {
  const recorder = new LiveKitCloudRecording({});
  assert.equal(recorder.configured, false);
  await assert.rejects(recorder.start(room(), 'grid'), RecordingConfigurationError);
});

test('local Egress output → finalized MP4 → Demo export ticket → one-time download', async () => {
  const folder = await mkdtemp(path.join(os.tmpdir(), 'livekit-export-'));
  try {
    const env = {
      LIVEKIT_URL: 'wss://livekit.example.test',
      LIVEKIT_API_KEY: 'key',
      LIVEKIT_API_SECRET: 'secret',
      LIVEKIT_EGRESS_OUTPUT_DIR: '/out',
      LIVEKIT_RECORDING_EXPORT_DIR: folder,
    };
    const fake = mockLiveKit();
    const recorder = new LiveKitCloudRecording(env, fake.transport);
    const target = room();
    const started = await recorder.start(target, 'speaker');
    assert.equal(started.recordingId, 'EG_1');
    const request = fake.calls[0]!.body;
    assert.equal(request.template.layout, 'speaker');
    assert.equal(request.outputs[0].file.file_type, 'MP4');
    assert.ok(request.outputs[0].file.filepath.startsWith('/out/'));
    assert.equal(request.storage, undefined);
    assert.equal(request.s3, undefined);
    await assert.rejects(recorder.start(target, 'grid'), RecordingProviderError);
    fake.setStatus('EGRESS_ACTIVE');
    assert.equal((await recorder.status(target)).state, 'recording');
    assert.equal((await recorder.stop(target)).state, 'processing');
    await assert.rejects(recorder.download(target), RecordingProviderError);
    const filename = path.basename(request.outputs[0].file.filepath);
    assert.match(filename, /^[0-9a-f-]{36}\.mp4$/);
    // Minimal test container: ftyp header and finalized moov atom, not a text
    // file pretending to be MP4. Actual media playback needs real E2E.
    const bytes = Buffer.alloc(800);
    bytes.write('ftyp', 4, 'ascii');
    bytes.write('moov', 500, 'ascii');
    await writeFile(path.join(folder, filename), bytes);
    assert.equal((await recorder.status(target)).canDownload, false);
    await new Promise((done) => setTimeout(done, 1600));
    const completed = await recorder.status(target);
    assert.equal(completed.state, 'completed');
    assert.equal(completed.fileSizeBytes, 800);
    const download = await recorder.download(target);
    assert.match(download.downloadUrl, /^\/rooms\/abc123\/recording\/export\//);
    assert.equal(download.expiresInSeconds, 60);
    const ticket = download.downloadUrl.split('/').at(-1)!;
    assert.equal((await recorder.consumeExport(target.roomCode, ticket)).filename, filename);
    await assert.rejects(recorder.consumeExport(target.roomCode, ticket), RecordingProviderError);
    const otherTicket = (await recorder.download(target)).downloadUrl.split('/').at(-1)!;
    await assert.rejects(recorder.consumeExport('another-room', otherTicket), RecordingProviderError);
  } finally {
    await rm(folder, {recursive: true, force: true});
  }
});

test('failed Egress never produces a download ticket', async () => {
  const folder = await mkdtemp(path.join(os.tmpdir(), 'livekit-failed-'));
  try {
    const fake = mockLiveKit();
    const recorder = new LiveKitCloudRecording({
      LIVEKIT_URL: 'wss://livekit.example.test',
      LIVEKIT_API_KEY: 'key', LIVEKIT_API_SECRET: 'secret',
      LIVEKIT_EGRESS_OUTPUT_DIR: '/out',
      LIVEKIT_RECORDING_EXPORT_DIR: folder,
    }, fake.transport);
    const target = room();
    await recorder.start(target, 'grid');
    fake.setStatus('EGRESS_FAILED');
    assert.equal((await recorder.status(target)).state, 'failed');
    assert.equal((await recorder.status(target)).canDownload, false);
    await assert.rejects(recorder.download(target), RecordingProviderError);
  } finally {
    await rm(folder, {recursive: true, force: true});
  }
});
