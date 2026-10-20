import type { RequestHandler, Response } from 'express';
import type { ApplicationInput, ApplicationReply } from '../services/application-protocol.ts';
import { applicationInput } from './application-input.ts';

export function applicationHandler<T extends {
  sendProviderError(res: Response, error: unknown): Response | false;
  handleUnknownError?(res: Response, error: unknown): Response | false;
}>(
  action: (input: ApplicationInput, dependencies: T) => Promise<ApplicationReply>,
  dependencies: T,
): RequestHandler {
  return (req, res, next) => {
    void Promise.resolve().then(async () => {
      const result = await action(applicationInput(req), dependencies);
      res.status(result.status).json(result.body);
    }).catch((error: unknown) => {
      if (dependencies.sendProviderError(res, error) !== false) return;
      if (dependencies.handleUnknownError && dependencies.handleUnknownError(res, error) !== false) return;
      next(error);
    });
  };
}
