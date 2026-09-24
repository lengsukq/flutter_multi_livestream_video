import agoraToken from 'agora-token';

const { RtcRole, RtcTokenBuilder } = agoraToken;

export function normalizeAgoraTokenTtl(rawTtl) {
  const value = Number(rawTtl);
  if (!Number.isFinite(value)) return 600;
  return Math.max(60, Math.min(86_400, Math.floor(value)));
}

export function buildAgoraRtcToken({
  appId,
  appCertificate,
  channelName,
  uid,
  role,
  ttlSeconds = 600,
}) {
  if (!appId || !appCertificate) {
    throw new Error('Agora App ID and App Certificate are required.');
  }
  const ttl = normalizeAgoraTokenTtl(ttlSeconds);
  const rtcRole =
    role === 'viewer' ? RtcRole.SUBSCRIBER : RtcRole.PUBLISHER;
  return RtcTokenBuilder.buildTokenWithUid(
    appId,
    appCertificate,
    channelName,
    uid,
    rtcRole,
    ttl,
    ttl,
  );
}
