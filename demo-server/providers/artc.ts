import crypto from 'node:crypto';
import { buildArtcAuthInfo } from '../artc-token.ts';
import { ProviderOperationError } from './provider-registry.ts';
import type {
  ArtcRoomAttendee,
  ArtcRoomEntry,
  MediaRole,
  NormalizeName,
  ProviderAdapter,
  ProviderFactoryContext,
  ProviderJoinResponse,
} from '../types.ts';

const DEFAULT_TTL_SECONDS = 600;
const MIN_TTL_SECONDS = 60;
const MAX_TTL_SECONDS = 24 * 60 * 60;

export function normalizeArtcTokenTtl(raw: string | undefined): number {
  if (raw == null || raw.trim() === '') return DEFAULT_TTL_SECONDS;
  const value = Number(raw);
  if (!Number.isInteger(value) || value < MIN_TTL_SECONDS || value > MAX_TTL_SECONDS) {
    throw new TypeError(`ARTC token TTL must be between ${MIN_TTL_SECONDS} and ${MAX_TTL_SECONDS} seconds.`);
  }
  return value;
}

/** Reference backend adapter. ARTC role is a client SDK mode, not a token grant. */
export function createArtcProvider({
  env = process.env,
  contractVersion,
  normalizeDisplayName,
}: ProviderFactoryContext & { normalizeDisplayName: NormalizeName }): ProviderAdapter {
  const appId = env.ARTC_APP_ID?.trim() || '';
  const appKey = env.ARTC_APP_KEY?.trim() || null;
  let ttlSeconds = DEFAULT_TTL_SECONDS;
  let ttlIsValid = true;
  try {
    ttlSeconds = normalizeArtcTokenTtl(env.ARTC_TOKEN_TTL_SECONDS);
  } catch {
    ttlIsValid = false;
  }

  const sceneForRole = (role: MediaRole): 'meeting' | 'live' =>
    role === 'participant' ? 'meeting' : 'live';

  function supportsRole(role: MediaRole, entry: ArtcRoomEntry | null = null): boolean {
    return !entry || entry.scene === sceneForRole(role);
  }

  function roleError(entry: ArtcRoomEntry, role: MediaRole): string {
    return `This ARTC room uses the ${entry.scene} mode and does not support ${role}.`;
  }

  function credentials(
    entry: ArtcRoomEntry,
    attendee: ArtcRoomAttendee,
    role: MediaRole,
  ): ProviderJoinResponse {
    const expiresAtSeconds = Math.floor(Date.now() / 1000) + ttlSeconds;
    const expiresAtMs = expiresAtSeconds * 1000;
    return {
      contractVersion,
      provider: 'artc',
      role,
      roomCode: entry.roomCode,
      participantId: attendee.attendeeId,
      displayName: attendee.externalUserId,
      artc: {
        appId,
        channelId: entry.providerRoomName,
        userId: attendee.attendeeId,
        authInfo: buildArtcAuthInfo({
          appId,
          appKey,
          channelId: entry.providerRoomName,
          userId: attendee.attendeeId,
          expiresAtSeconds,
        }),
        expiresAtMs,
      },
    };
  }

  return {
    id: 'artc',
    displayName: 'Alibaba Cloud ARTC',
    label: '阿里云 ARTC',
    description: '阿里云实时音视频与互动直播',
    themeKey: 'artc',
    configurationError: 'ARTC is not configured. Set ARTC_APP_ID and ARTC_APP_KEY.',
    isConfigured: () => Boolean(appId && appKey && ttlIsValid),
    metadata: () => ttlIsValid ? {} : { configurationError: 'ARTC_TOKEN_TTL_SECONDS must be between 60 and 86400.' },
    supportsRole: (role, entry = null) => supportsRole(role, entry as ArtcRoomEntry | null),
    roleError: (entry, role) => roleError(entry as ArtcRoomEntry, role),
    async createRoom({ roomCode, role }) {
      const entry: ArtcRoomEntry = {
        provider: 'artc',
        roomCode,
        providerRoomName: `media-${roomCode}`,
        scene: sceneForRole(role),
        createdAt: new Date().toISOString(),
        attendees: [],
        lastHeartbeatMs: Date.now(),
      };
      return { entry, response: { contractVersion, provider: 'artc', role, roomCode } };
    },
    async joinRoom({ entry, rawName, role }) {
      const room = entry as ArtcRoomEntry;
      if (!supportsRole(role, room)) {
        throw new ProviderOperationError(400, 'unsupported-role', roleError(room, role));
      }
      const userId = `u-${crypto.randomUUID().replaceAll('-', '').slice(0, 30)}`;
      const attendee: ArtcRoomAttendee = {
        attendeeId: userId,
        externalUserId: normalizeDisplayName(rawName) || userId,
        role,
        joinedAt: new Date().toISOString(),
      };
      room.attendees.push(attendee);
      room.lastHeartbeatMs = Date.now();
      return credentials(room, attendee, role);
    },
    async refreshCredentials({ entry, participantId, role }) {
      const room = entry as ArtcRoomEntry;
      const attendee = room.attendees.find((item) => item.attendeeId === participantId);
      if (!attendee || attendee.role !== role) {
        throw new ProviderOperationError(
          403,
          'forbidden',
          'The participant is not authorized to refresh credentials for this room and role.',
        );
      }
      if (!supportsRole(role, room)) {
        throw new ProviderOperationError(400, 'unsupported-role', roleError(room, role));
      }
      room.lastHeartbeatMs = Date.now();
      return credentials(room, attendee, role);
    },
    async closeRoom() {},
    removeAttendee(entry, who) {
      const before = entry.attendees.length;
      entry.attendees = entry.attendees.filter((attendee) => attendee.attendeeId !== String(who));
      return { removed: entry.attendees.length !== before, closeWhenEmpty: false };
    },
    summarizeRoom(entry, { host }) {
      const room = entry as ArtcRoomEntry;
      return {
        provider: 'artc',
        roomCode: room.roomCode,
        meetingId: room.providerRoomName,
        externalMeetingId: room.providerRoomName,
        mediaRegion: 'ARTC',
        scene: room.scene,
        createdAt: room.createdAt,
        lastHeartbeat: new Date(room.lastHeartbeatMs ?? Date.now()).toISOString(),
        idleSec: Math.max(0, Math.round((Date.now() - (room.lastHeartbeatMs ?? Date.now())) / 1000)),
        attendeeCount: room.attendees.length,
        attendees: room.attendees,
        shareText: room.roomCode,
        shareLink: `multimedia://join?roomCode=${room.roomCode}&server=${host}`,
      };
    },
  };
}
