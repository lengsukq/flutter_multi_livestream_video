import { ProviderOperationError } from '../providers/provider-registry.ts';

/** Decoded protocol values; application services do not receive Express objects. */
export interface ApplicationInput {
  readonly params: Readonly<Record<string, string>>;
  readonly query: Readonly<Record<string, unknown>>;
  readonly body: Readonly<Record<string, unknown>> & { readonly displayName?: string; readonly nickname?: string };
}
export interface ApplicationReply {
  readonly status: number;
  readonly body: unknown;
}
export function reply(body: unknown): ApplicationReply {
  return Object.freeze({status: 200, body});
}
export function replyStatus(status: number, body: unknown): ApplicationReply {
  return Object.freeze({status, body});
}
export function fail(status: number, code: string, message: string, details?: unknown): never {
  throw new ProviderOperationError(status, code, message, details);
}
