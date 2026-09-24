import { createHash } from 'node:crypto';

/** Creates ARTC's Base64 single-parameter auth information. Keep AppKey server-side. */
export function buildArtcAuthInfo({
  appId,
  appKey,
  channelId,
  userId,
  expiresAtSeconds,
}: {
  appId: string;
  appKey: string | null;
  channelId: string;
  userId: string;
  expiresAtSeconds: number;
}): string {
  if (!appId.trim()) throw new TypeError('ARTC AppID is required.');
  if (!appKey?.trim()) throw new TypeError('ARTC AppKey is required.');
  if (!/^[A-Za-z0-9_-]{1,64}$/.test(channelId)) {
    throw new TypeError('ARTC channelId must use 1-64 letters, digits, hyphens, or underscores.');
  }
  if (!/^[A-Za-z0-9_-]{1,64}$/.test(userId)) {
    throw new TypeError('ARTC userId must use 1-64 letters, digits, hyphens, or underscores.');
  }
  if (!Number.isSafeInteger(expiresAtSeconds) || expiresAtSeconds <= Math.floor(Date.now() / 1000)) {
    throw new TypeError('ARTC auth expiry must be a future Unix timestamp in seconds.');
  }

  const nonce = '';
  const signature = createHash('sha256')
    .update(`${appId}${appKey}${channelId}${userId}${nonce}${expiresAtSeconds}`)
    .digest('hex');
  return Buffer.from(JSON.stringify({
    appid: appId,
    channelid: channelId,
    userid: userId,
    nonce,
    timestamp: expiresAtSeconds,
    token: signature,
  })).toString('base64');
}
