import crypto from 'node:crypto';
import { buildAgoraRtcToken } from '../agora-token.ts';
import type {
  NamedRoomEntry,
  NormalizeName,
  ProviderAdapter,
  ProviderFactoryContext,
} from '../types.ts';

export function createAgoraProvider({
  env = process.env,
  contractVersion,
  normalizeDisplayName,
}: ProviderFactoryContext & { normalizeDisplayName: NormalizeName }): ProviderAdapter {
  const appId = env.AGORA_APP_ID?.trim() || null;
  const appCertificate = env.AGORA_APP_CERTIFICATE?.trim() || null;
  const ttlSeconds = Number(env.AGORA_TOKEN_TTL_SECONDS ?? 600);

  function generateUid(entry: NamedRoomEntry): number {
    for (let i = 0; i < 50; i++) {
      const uid = crypto.randomInt(1, 0x80000000);
      if (!entry.attendees.some((item) => item.attendeeId === String(uid))) return uid;
    }
    throw new Error('Unable to allocate a unique Agora uid.');
  }

  return {
    id: 'agora',
    displayName: 'Agora',
    label: 'Agora RTC',
    description: 'Agora RTC 全球实时网络',
    themeKey: 'agora',
    configurationError: 'Agora is not configured. Set AGORA_APP_ID and AGORA_APP_CERTIFICATE.',
    isConfigured: () => Boolean(appId && appCertificate),
    supportsRole: () => true,
    async createRoom({ roomCode, role }) {
      const entry: NamedRoomEntry = {
        provider: 'agora', roomCode, providerRoomName: `media-${roomCode}`,
        createdAt: new Date().toISOString(), attendees: [], lastHeartbeatMs: Date.now(),
      };
      return { entry, response: { contractVersion, provider: 'agora', role, roomCode } };
    },
    async joinRoom({ entry, rawName, role }) {
      const room = entry as NamedRoomEntry;
      const uid = generateUid(room);
      const displayName = normalizeDisplayName(rawName) || String(uid);
      room.attendees.push({ attendeeId: String(uid), externalUserId: displayName, joinedAt: new Date().toISOString() });
      room.lastHeartbeatMs = Date.now();
      return {
        contractVersion, provider: 'agora', role, roomCode: room.roomCode,
        participantId: String(uid), displayName,
        agora: {
          appId,
          channelName: room.providerRoomName,
          token: buildAgoraRtcToken({ appId, appCertificate, channelName: room.providerRoomName, uid, role, ttlSeconds }),
          uid,
        },
      };
    },
    async closeRoom() {},
    removeAttendee(entry, who) {
      const before = entry.attendees.length;
      entry.attendees = entry.attendees.filter((attendee) =>
        attendee.attendeeId !== String(who) && attendee.externalUserId !== String(who));
      return { removed: entry.attendees.length !== before, closeWhenEmpty: entry.attendees.length === 0 };
    },
    summarizeRoom(entry, { host }) {
      const room = entry as NamedRoomEntry;
      return {
        provider: 'agora', roomCode: room.roomCode, meetingId: room.providerRoomName,
        externalMeetingId: room.providerRoomName, mediaRegion: 'Agora', createdAt: room.createdAt,
        lastHeartbeat: new Date(room.lastHeartbeatMs ?? Date.now()).toISOString(),
        idleSec: Math.max(0, Math.round((Date.now() - (room.lastHeartbeatMs ?? Date.now())) / 1000)),
        attendeeCount: room.attendees.length, attendees: room.attendees, shareText: room.roomCode,
        shareLink: `multimedia://join?roomCode=${room.roomCode}&server=${host}`,
      };
    },
  };
}
