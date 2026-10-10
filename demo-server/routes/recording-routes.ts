import type {Express, Response} from 'express';
import type {NamedRoomEntry, RoomEntry} from '../types.ts';
import {requireRoomManager} from '../room-access.ts';
import {
  LiveKitCloudRecording,
  RecordingConfigurationError,
  RecordingProviderError,
} from '../recording/livekit-cloud-recording.ts';

export function registerRecordingRoutes(app: Express, dependencies: {
  resolveRoom(ref: unknown): Promise<RoomEntry | null>;
  recorder: LiveKitCloudRecording;
  contractError(
    response: Response, status: number, code: string, message: string,
  ): Response;
}) {
  const {resolveRoom, recorder, contractError} = dependencies;

  function handler(action: 'start' | 'stop' | 'status' | 'download') {
    return async (req: import('express').Request, res: Response) => {
      try {
        const entry = await resolveRoom(req.params.code);
        if (!entry) return contractError(res, 404, 'room-not-found', 'Room not found.');
        if (!requireRoomManager(
          entry,
          req.body?.requesterParticipantId,
          req.body?.participantCredential,
          req.body?.roomOwnerCredential,
        )) {
          return contractError(res, 403, 'forbidden', 'Host permission is required for cloud recording.');
        }
        if (entry.provider !== 'livekit' || !entry.providerRoomName) {
          return contractError(res, 400, 'unsupported-provider', 'Cloud recording V1 supports LiveKit rooms only.');
        }
        const room = entry as NamedRoomEntry;
        if (action === 'start') {
          // No client-supplied URL, storage, credentials or arbitrary vendor API
          // payload are allowed. The backend owns all privileged configuration.
          const raw = req.body?.rawProviderParams ?? {};
          if (!raw || typeof raw !== 'object' || Array.isArray(raw) ||
              Object.keys(raw).some((key) => key !== 'preset')) {
            return contractError(res, 400, 'invalid-recording-params',
              'Only the encoding preset may be passed to the server; storage/auth overrides are prohibited.');
          }
          const preset = raw.preset ?? 'H264_720P_30';
          if (preset !== 'H264_720P_30' && preset !== 'H264_1080P_30') {
            return contractError(res, 400, 'invalid-recording-preset',
              'Only H264_720P_30 or H264_1080P_30 presets are supported.');
          }
          if (req.body?.containerFormat && req.body.containerFormat !== 'mp4') {
            return contractError(res, 400, 'invalid-recording-format', 'Cloud recording V1 outputs MP4 only.');
          }
          if (req.body?.streamType && req.body.streamType !== 'both') {
            return contractError(res, 400, 'invalid-recording-stream', 'Cloud recording V1 captures composite audio and video.');
          }
          const layout = req.body?.layout ?? 'grid';
          if (layout !== 'grid' && layout !== 'speaker') {
            return contractError(res, 400, 'invalid-recording-layout', 'Only grid and speaker layouts are available.');
          }
          return res.json(await recorder.start(room, layout, preset));
        }
        if (action === 'stop') return res.json(await recorder.stop(room));
        if (action === 'status') return res.json(await recorder.status(room));
        return res.json(await recorder.download(room));
      } catch (error) {
        if (error instanceof RecordingConfigurationError) {
          return contractError(res, 503, 'cloud-recording-not-configured', error.message);
        }
        if (error instanceof RecordingProviderError) {
          return contractError(res, 409, 'cloud-recording-error', error.message);
        }
        console.error('cloud recording operation failed', error);
        return contractError(res, 502, 'cloud-recording-provider-failed',
          'Cloud recording service could not complete the operation.');
      }
    };
  }
  app.post('/rooms/:code/recording/start', handler('start'));
  app.post('/rooms/:code/recording/stop', handler('stop'));
  app.post('/rooms/:code/recording/status', handler('status'));
  app.post('/rooms/:code/recording/download', handler('download'));

  // Demo browser download: POST above authenticates the host and issues a
  // random, single-use 60-second ticket. The GET contains no RTC credentials.
  app.get('/rooms/:code/recording/export/:ticket', async (req, res) => {
    try {
      const {absolutePath, filename} = await recorder.consumeExport(
        String(req.params.code), String(req.params.ticket),
      );
      res.setHeader('Cache-Control', 'private, no-store');
      res.setHeader('X-Content-Type-Options', 'nosniff');
      res.type('video/mp4');
      res.download(absolutePath, filename, (error) => {
        if (error && !res.headersSent) {
          contractError(res, 404, 'recording-file-unavailable',
            'The recording file could not be exported.');
        }
      });
    } catch {
      contractError(res, 404, 'recording-download-invalid',
        'The recording download ticket has expired or is invalid.');
    }
  });
}
