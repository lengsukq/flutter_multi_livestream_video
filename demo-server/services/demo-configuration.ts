export function readDemoConfiguration(env: NodeJS.ProcessEnv) {
const CONTROL_REGION = env.AWS_REGION ?? 'us-east-1';
const MEDIA_REGION = env.CHIME_MEDIA_REGION ?? 'ap-southeast-1';
const CONTRACT_VERSION = 1;
const MEDIA_CONTRACT_HEADER = 'X-Media-Backend-Contract';
const CHAT_CONTRACT_HEADER = 'X-Realtime-Chat-Contract';
const LEGACY_CHIME_CONTRACT_HEADER = 'X-Chime-Backend-Contract';
const DEMO_BEARER_TOKEN = env.DEMO_BEARER_TOKEN?.trim() || null;
const MEDIA_ADMIN_PASSWORD = env.MEDIA_ADMIN_PASSWORD?.trim() || '';
const ADMIN_SESSION_COOKIE = 'media_admin_session';
const ADMIN_SESSION_TTL_SECONDS = 8 * 60 * 60;
const IS_VERCEL = env.VERCEL === '1';
const MEDIA_CONNECTIONS_ENABLED = parseBoolean(
  env.MEDIA_CONNECTIONS_ENABLED,
  !IS_VERCEL,
);
const INITIAL_PROVIDER = String(env.MEDIA_DEFAULT_PROVIDER ?? 'aws').trim().toLowerCase();
const INITIAL_CHAT_PROVIDER = String(env.CHAT_DEFAULT_PROVIDER ?? 'none').trim().toLowerCase();
const STARTED_AT = Date.now();
const EMPTY_CLOSE_AFTER_MS = Number(env.EMPTY_CLOSE_AFTER_MS ?? 90_000);
const PARTICIPANT_STALE_AFTER_MS = Number(
  env.PARTICIPANT_STALE_AFTER_MS ?? Math.max(120_000, EMPTY_CLOSE_AFTER_MS),
);
const SWEEP_INTERVAL_MS = 30_000;

return Object.freeze({CONTROL_REGION, MEDIA_REGION, CONTRACT_VERSION, MEDIA_CONTRACT_HEADER, CHAT_CONTRACT_HEADER, LEGACY_CHIME_CONTRACT_HEADER, DEMO_BEARER_TOKEN, MEDIA_ADMIN_PASSWORD, ADMIN_SESSION_COOKIE, ADMIN_SESSION_TTL_SECONDS, IS_VERCEL, MEDIA_CONNECTIONS_ENABLED, INITIAL_PROVIDER, INITIAL_CHAT_PROVIDER, STARTED_AT, EMPTY_CLOSE_AFTER_MS, PARTICIPANT_STALE_AFTER_MS, SWEEP_INTERVAL_MS});
}

function parseBoolean(value: string | undefined, fallback: boolean): boolean {
  if (value == null || value.trim() === '') return fallback;
  return ['1', 'true', 'yes', 'on'].includes(value.trim().toLowerCase());
}
