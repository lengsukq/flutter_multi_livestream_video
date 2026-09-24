import tlsSigApiV2 from 'tls-sig-api-v2';
import type { MediaRole } from './types.ts';

const { Api } = tlsSigApiV2;

export const TRTC_PUBLISHER_PRIVILEGES = 1 | 2 | 4 | 8 | 16 | 32;
export const TRTC_VIEWER_PRIVILEGES = 1 | 2 | 8 | 32;

/** Mints short-lived TRTC UserSig and room-scoped PrivateMapKey values. */
export function buildTrtcCredentials({
  sdkAppId,
  secretKey,
  userId,
  strRoomId,
  ttlSeconds,
  role,
}: {
  sdkAppId: number;
  secretKey: string | null;
  userId: string;
  strRoomId: string;
  ttlSeconds: number;
  role: unknown;
}): { userSig: string; privateMapKey: string } {
  if (!Number.isSafeInteger(sdkAppId) || sdkAppId <= 0) {
    throw new TypeError('TRTC SDKAppId must be a positive integer.');
  }
  if (!secretKey?.trim()) throw new TypeError('TRTC secret key is required.');
  if (!/^[A-Za-z0-9_-]{1,32}$/.test(userId)) {
    throw new TypeError('TRTC userId must use 1-32 letters, digits, hyphens, or underscores.');
  }
  if (!/^[A-Za-z0-9_-]{1,64}$/.test(strRoomId)) {
    throw new TypeError('TRTC string room id contains unsupported characters.');
  }
  if (!Number.isInteger(ttlSeconds) || ttlSeconds < 60 || ttlSeconds > 90 * 24 * 60 * 60) {
    throw new TypeError('TRTC token TTL must be between 60 seconds and 90 days.');
  }
  if (role !== 'participant' && role !== 'host' && role !== 'viewer') {
    throw new TypeError('TRTC role must be participant, host, or viewer.');
  }

  const api = new Api(sdkAppId, secretKey);
  const privilegeMap = role === 'viewer'
    ? TRTC_VIEWER_PRIVILEGES
    : TRTC_PUBLISHER_PRIVILEGES;
  return {
    userSig: api.genSig(userId, ttlSeconds),
    privateMapKey: api.genPrivateMapKeyWithStringRoomID(
      userId,
      ttlSeconds,
      strRoomId,
      privilegeMap,
    ),
  };
}
