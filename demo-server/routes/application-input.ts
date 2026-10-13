import type { Request } from 'express';
import { ProviderOperationError } from '../providers/provider-registry.ts';
import type { ApplicationInput } from '../services/application-protocol.ts';

export function applicationInput(request: Request): ApplicationInput {
  const raw: unknown = request.body;
  if (raw != null && (typeof raw !== 'object' || Array.isArray(raw))) {
    throw new ProviderOperationError(400, 'invalid-argument', 'A JSON object is required.');
  }
  const body = { ...((raw ?? {}) as Record<string, unknown>) };
  for (const name of ['displayName', 'nickname']) {
    if (body[name] != null && typeof body[name] !== 'string') {
      throw new ProviderOperationError(400, 'invalid-argument', `${name} must be a string.`);
    }
  }
  return Object.freeze({
    params: Object.freeze({ ...request.params }),
    query: Object.freeze({ ...request.query }),
    body: Object.freeze(body) as ApplicationInput['body'],
  });
}
