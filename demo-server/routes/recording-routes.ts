import {Readable} from 'node:stream';
import {pipeline} from 'node:stream/promises';
import type {Express, Response} from 'express';
import type {CloudRecordingExecutor} from '../recording/cloud-recording-executor.ts';
import {
  RecordingConfigurationError,
  RecordingProviderError,
} from '../recording/livekit-cloud-recording.ts';
import {ProviderOperationError} from '../providers/provider-registry.ts';
import type {RecordingApplicationDependencies} from '../services/recording/recording-operations.ts';
import {
  consumeRecordingExport,
  recordingStatus,
  requestRecordingDownload,
  startRecording,
  stopRecording,
} from '../services/recording/recording-operations.ts';
import {applicationHandler} from './application-handler.ts';

export interface RecordingRouteDependencies extends Omit<RecordingApplicationDependencies, 'recorders'> {
  recorders?: ReadonlyMap<string, CloudRecordingExecutor>;
  recorder?: CloudRecordingExecutor;
  contractError(response: Response, status: number, code: string, message: string): Response;
  sendProviderError?(response: Response, error: unknown): Response | false;
}

export function registerRecordingRoutes(app: Express, dependencies: RecordingRouteDependencies): void {
  const recorders = dependencies.recorders ?? new Map(
    dependencies.recorder ? [['livekit', dependencies.recorder]] : [],
  );
  const applicationDependencies = {
    ...dependencies,
    recorders,
    sendProviderError: dependencies.sendProviderError ?? ((response: Response, error: unknown) => {
      if (!(error instanceof ProviderOperationError)) return false;
      return dependencies.contractError(
        response, error.status, error.code, error.message,
      );
    }),
    handleUnknownError(response: Response, error: unknown) {
      if (error instanceof ProviderOperationError) return false;
      if (error instanceof RecordingConfigurationError) {
        return dependencies.contractError(response, 503,
          'cloud-recording-not-configured', error.message);
      }
      if (error instanceof RecordingProviderError) {
        return dependencies.contractError(response, 409,
          'cloud-recording-error', error.message);
      }
      dependencies.logError?.('cloud recording operation failed', error);
      return dependencies.contractError(response, 502,
        'cloud-recording-provider-failed',
        'Cloud recording service could not complete the operation.');
    },
  };

  app.post('/rooms/:code/recording/start', applicationHandler(startRecording, applicationDependencies));
  app.post('/rooms/:code/recording/stop', applicationHandler(stopRecording, applicationDependencies));
  app.post('/rooms/:code/recording/status', applicationHandler(recordingStatus, applicationDependencies));
  app.post('/rooms/:code/recording/download', applicationHandler(requestRecordingDownload, applicationDependencies));

  // Export URLs use a cryptographically random, single-use 60-second ticket.
  app.get('/rooms/:code/recording/export/:ticket', async (req, res) => {
    try {
      const artifact = await consumeRecordingExport(
        String(req.params.code), String(req.params.ticket), applicationDependencies,
      );
      res.setHeader('Cache-Control', 'private, no-store');
      res.setHeader('X-Content-Type-Options', 'nosniff');
      res.type('video/mp4');
      if (artifact.kind === 'local') {
        res.download(artifact.absolutePath, artifact.filename, (error) => {
          if (error && !res.headersSent) {
            dependencies.contractError(res, 404, 'recording-file-unavailable',
              'The recording file could not be exported.');
          }
        });
      } else if (artifact.kind === 'stream') {
        res.attachment(artifact.filename);
        await pipeline(Readable.from(artifact.body), res);
        if (artifact.afterDownload) {
          try {
            await artifact.afterDownload();
          } catch {
            console.warn('Recording was downloaded, but storage cleanup failed.');
          }
        }
      } else {
        const upstream = await fetch(artifact.url, {
          redirect: 'error', signal: AbortSignal.timeout(120_000),
        });
        if (!upstream.ok || !upstream.body) throw new Error('Recording file unavailable.');
        res.attachment(artifact.filename);
        await pipeline(Readable.from(upstream.body as AsyncIterable<Uint8Array>), res);
      }
    } catch {
      if (!res.headersSent) dependencies.contractError(res, 404,
        'recording-download-invalid',
        'The recording download ticket has expired or is invalid.');
      else res.destroy();
    }
  });
}
