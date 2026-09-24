import crypto from 'node:crypto';
import type {
  MediaRole,
  NamedRoomEntry,
  NormalizeName,
  ProviderAdapter,
  ProviderFactoryContext,
} from '../types.ts';

function base64Url(value: string): string {
  return Buffer.from(value).toString('base64url');
}

export function createLiveKitProvider({
  env = process.env,
  contractVersion,
  normalizeDisplayName,
}: ProviderFactoryContext & { normalizeDisplayName: NormalizeName }): ProviderAdapter {
  const url = env.LIVEKIT_URL?.trim() || null;
  const apiKey = env.LIVEKIT_API_KEY?.trim() || null;
  const apiSecret = env.LIVEKIT_API_SECRET?.trim() || null;
  const ttlSeconds = Number(env.LIVEKIT_TOKEN_TTL_SECONDS ?? 600);

  function signToken({
    identity,
    name,
    roomName,
    role,
  }: {
    identity: string;
    name: string;
    roomName: string;
    role: MediaRole;
  }): string {
    if (!apiKey || !apiSecret) {
      throw new Error('LiveKit is not configured.');
    }
    const now = Math.floor(Date.now() / 1000);
    const header = { alg: 'HS256', typ: 'JWT' };
    const payload = {
      iss: apiKey,
      sub: identity,
      nbf: now - 5,
      exp: now + ttlSeconds,
      ...(name ? { name } : {}),
      video: {
        roomJoin: true,
        room: roomName,
        canSubscribe: true,
        canPublish: role !== 'viewer',
        canPublishData: true,
      },
    };
    const unsigned = `${base64Url(JSON.stringify(header))}.${base64Url(JSON.stringify(payload))}`;
    const signature = crypto.createHmac('sha256', apiSecret).update(unsigned).digest('base64url');
    return `${unsigned}.${signature}`;
  }

  return {
    id: 'livekit',
    displayName: 'LiveKit',
    label: 'LiveKit WebRTC',
    description: 'WebRTC 原生流集群',
    themeKey: 'livekit',
    configurationError: 'LiveKit is not configured. Set LIVEKIT_URL, LIVEKIT_API_KEY, and LIVEKIT_API_SECRET.',
    isConfigured: () => Boolean(url && apiKey && apiSecret),
    metadata: () => ({ url }),
    supportsRole: () => true,
    async createRoom({ roomCode, role }) {
      const entry: NamedRoomEntry = {
        provider: 'livekit',
        roomCode,
        providerRoomName: `media-${roomCode}`,
        createdAt: new Date().toISOString(),
        attendees: [],
        lastHeartbeatMs: Date.now(),
      };
      return {
        entry,
        response: { contractVersion, provider: 'livekit', role, roomCode },
      };
    },
    async joinRoom({ entry, rawName, role }) {
      const room = entry as NamedRoomEntry;
      const identity = `p-${crypto.randomUUID()}`;
      const displayName = normalizeDisplayName(rawName) || identity;
      room.attendees.push({ attendeeId: identity, externalUserId: displayName, joinedAt: new Date().toISOString() });
      room.lastHeartbeatMs = Date.now();
      return {
        contractVersion,
        provider: 'livekit',
        role,
        roomCode: room.roomCode,
        participantId: identity,
        displayName,
        livekit: { url, token: signToken({ identity, name: displayName, roomName: room.providerRoomName, role }), identity },
      };
    },
    async closeRoom() {},
    removeAttendee() {
      return { removed: false, closeWhenEmpty: false };
    },
    summarizeRoom(entry, { host }) {
      const room = entry as NamedRoomEntry;
      return {
        provider: 'livekit', roomCode: room.roomCode, meetingId: room.providerRoomName,
        externalMeetingId: room.providerRoomName, mediaRegion: 'LiveKit', createdAt: room.createdAt,
        lastHeartbeat: new Date(room.lastHeartbeatMs ?? Date.now()).toISOString(),
        idleSec: Math.max(0, Math.round((Date.now() - (room.lastHeartbeatMs ?? Date.now())) / 1000)),
        attendeeCount: room.attendees.length, attendees: room.attendees, shareText: room.roomCode,
        shareLink: `multimedia://join?roomCode=${room.roomCode}&server=${host}`,
      };
    },
  };
}
