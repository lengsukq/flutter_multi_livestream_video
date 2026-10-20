import type { IvsRoomEntry, NamedRoomEntry, RoomEntry } from '../../types.ts';
import { requireRoomManager } from '../../room-access.ts';
import type { CloudRecordingExecutor, RecordingLayoutIntent, RecordingPreset } from '../../recording/cloud-recording-executor.ts';
import { RecordingProviderError } from '../../recording/livekit-cloud-recording.ts';
import { fail, reply, type ApplicationInput, type ApplicationReply } from '../application-protocol.ts';

export type RecordingAction = 'start' | 'stop' | 'status' | 'download';

export interface RecordingApplicationDependencies {
  resolveRoom(ref: unknown): Promise<RoomEntry | null>;
  withRoomOperation?<T>(entry: RoomEntry, operation: () => Promise<T>): Promise<T>;
  recorders: ReadonlyMap<string, CloudRecordingExecutor>;
  logError?(message: string, error: unknown): void;
}

function recordingRoom(entry: RoomEntry): NamedRoomEntry {
  const stageArn = entry.provider === 'ivs' ? (entry as IvsRoomEntry).stageArn : undefined;
  if (!entry.providerRoomName && !entry.meeting?.MeetingArn && !stageArn) {
    fail(400, 'unsupported-provider', 'Cloud recording is not supported for this media provider.');
  }
  return {
    ...entry,
    providerRoomName: entry.providerRoomName ?? entry.meeting?.MeetingId ?? stageArn ?? '',
  };
}

async function withRecorder(
  input: ApplicationInput,
  dependencies: RecordingApplicationDependencies,
  action: RecordingAction,
): Promise<ApplicationReply> {
  const entry = await dependencies.resolveRoom(input.params.code);
  if (!entry) fail(404, 'room-not-found', 'Room not found.');
  if (!requireRoomManager(
    entry,
    input.body.requesterParticipantId,
    input.body.participantCredential,
    input.body.roomOwnerCredential,
  )) {
    fail(403, 'forbidden', 'Host permission is required for cloud recording.');
  }
  const recorder = dependencies.recorders.get(entry.provider);
  if (!recorder) {
    fail(400, 'unsupported-provider', 'Cloud recording is not supported for this media provider.');
  }
  const room = recordingRoom(entry);
  const supportedLayouts: readonly RecordingLayoutIntent[] =
    recorder.supportedLayouts ?? ['grid'];

  if (action === 'start') {
    const raw = input.body.rawProviderParams ?? {};
    if (!raw || typeof raw !== 'object' || Array.isArray(raw) ||
        Object.keys(raw).some((key) => key !== 'preset')) {
      fail(400, 'invalid-recording-params',
        'Only the encoding preset may be passed to the server; storage/auth overrides are prohibited.');
    }
    const params = raw as Record<string, unknown>;
    const preset = params.preset ?? 'H264_720P_30';
    if (preset !== 'H264_720P_30' && preset !== 'H264_1080P_30') {
      fail(400, 'invalid-recording-preset',
        'Only H264_720P_30 or H264_1080P_30 presets are supported.');
    }
    if (input.body.containerFormat && input.body.containerFormat !== 'mp4') {
      fail(400, 'invalid-recording-format', 'Cloud recording V1 outputs MP4 only.');
    }
    if (input.body.streamType && input.body.streamType !== 'both') {
      fail(400, 'invalid-recording-stream',
        'Cloud recording V1 captures composite audio and video.');
    }
    const requestedLayout: unknown = input.body.layout ?? 'grid';
    const layout: unknown = requestedLayout === 'speaker'
      ? supportedLayouts.includes('activeSpeaker') ? 'activeSpeaker' : 'featuredParticipant'
      : requestedLayout;
    if (!['grid', 'featuredParticipant', 'activeSpeaker'].includes(String(layout))) {
      fail(400, 'invalid-recording-layout', 'Use grid, featuredParticipant or activeSpeaker.');
    }
    if (!supportedLayouts.includes(layout as RecordingLayoutIntent)) {
      fail(422, 'unsupported-recording-layout',
        `Recording layout ${layout} is not supported by ${entry.provider}. ` +
        `Available: ${supportedLayouts.join(', ') || 'none'}.`);
    }
    const start = () => recorder.start(
      room,
      layout === 'grid' ? 'grid' : 'speaker',
      preset as RecordingPreset,
    );
    return reply(await (dependencies.withRoomOperation
      ? dependencies.withRoomOperation(entry, start)
      : start()));
  }

  if (action === 'stop') {
    const stop = () => recorder.stop(room);
    return reply(await (dependencies.withRoomOperation
      ? dependencies.withRoomOperation(entry, stop)
      : stop()));
  }
  if (action === 'status') {
    const status = await recorder.status(room);
    const readiness = await recorder.readiness?.();
    return reply({
      ...(status as Record<string, unknown>),
      recordingAvailable: readiness?.available ?? true,
      recordingUnavailableReason: readiness?.available === false ? readiness.reason : undefined,
      supportedLayouts,
    });
  }
  return reply(await recorder.download(room));
}

export function startRecording(input: ApplicationInput, dependencies: RecordingApplicationDependencies) {
  return withRecorder(input, dependencies, 'start');
}
export function stopRecording(input: ApplicationInput, dependencies: RecordingApplicationDependencies) {
  return withRecorder(input, dependencies, 'stop');
}
export function recordingStatus(input: ApplicationInput, dependencies: RecordingApplicationDependencies) {
  return withRecorder(input, dependencies, 'status');
}
export function requestRecordingDownload(input: ApplicationInput, dependencies: RecordingApplicationDependencies) {
  return withRecorder(input, dependencies, 'download');
}

export async function consumeRecordingExport(
  roomCode: string,
  ticket: string,
  dependencies: RecordingApplicationDependencies,
) {
  const entry = await dependencies.resolveRoom(roomCode);
  const recorder = entry && dependencies.recorders.get(entry.provider);
  if (!entry || !recorder) throw new RecordingProviderError('Recording provider unavailable.');
  return recorder.consumeExport(roomCode, ticket);
}
