import crypto from 'node:crypto';
import { buildTrtcCredentials } from '../trtc-token.ts';
import { ProviderOperationError } from './provider-registry.ts';
import type {
  MediaRole,
  NormalizeName,
  ProviderAdapter,
  ProviderFactoryContext,
  ProviderJoinResponse,
  TrtcRoomAttendee,
  TrtcRoomEntry,
} from '../types.ts';

export function createTrtcProvider({
  env = process.env,
  contractVersion,
  normalizeDisplayName,
}: ProviderFactoryContext & { normalizeDisplayName: NormalizeName }): ProviderAdapter {
  const sdkAppId = Number(env.TRTC_SDK_APP_ID ?? 0);
  const secretKey = env.TRTC_SDK_SECRET_KEY?.trim() || null;
  const ttlSeconds = Number(env.TRTC_TOKEN_TTL_SECONDS ?? 600);
  const sceneForRole = (role: MediaRole): 'meeting' | 'live' => role === 'participant' ? 'meeting' : 'live';
  const configured = (): boolean => Number.isSafeInteger(sdkAppId) && sdkAppId > 0 && Boolean(secretKey) &&
    Number.isInteger(ttlSeconds) && ttlSeconds >= 60 && ttlSeconds <= 90 * 24 * 60 * 60;

  function supportsRole(role: MediaRole, entry: TrtcRoomEntry | null = null): boolean {
    return !entry || entry.scene === sceneForRole(role);
  }

  function roleError(entry: TrtcRoomEntry, role: MediaRole): string {
    return `This TRTC room uses the ${entry.scene} scene and does not support ${role}.`;
  }

  function credentials(
    entry: TrtcRoomEntry,
    attendee: TrtcRoomAttendee,
    role: MediaRole,
  ): ProviderJoinResponse {
    const { userSig, privateMapKey } = buildTrtcCredentials({
      sdkAppId, secretKey, userId: attendee.attendeeId, strRoomId: entry.providerRoomName, ttlSeconds, role,
    });
    return {
      contractVersion, provider: 'trtc', role, roomCode: entry.roomCode,
      participantId: attendee.attendeeId, displayName: attendee.externalUserId,
      trtc: {
        sdkAppId, strRoomId: entry.providerRoomName, userId: attendee.attendeeId,
        userSig, privateMapKey, expiresAtMs: Date.now() + ttlSeconds * 1000,
      },
    };
  }

  return {
    id: 'trtc',
    displayName: 'Tencent TRTC',
    label: 'Tencent TRTC',
    description: '腾讯云 TRTC 实时音视频',
    themeKey: 'trtc',
    configurationError: 'TRTC is not configured. Set TRTC_SDK_APP_ID and TRTC_SDK_SECRET_KEY.',
    isConfigured: configured,
    supportsRole: (role, entry = null) => supportsRole(role, entry as TrtcRoomEntry | null),
    roleError: (entry, role) => roleError(entry as TrtcRoomEntry, role),
    async createRoom({ roomCode, role }) {
      const entry: TrtcRoomEntry = {
        provider: 'trtc', roomCode, providerRoomName: `media-${roomCode}`, scene: sceneForRole(role),
        createdAt: new Date().toISOString(), attendees: [], lastHeartbeatMs: Date.now(),
      };
      return { entry, response: { contractVersion, provider: 'trtc', role, roomCode } };
    },
    async joinRoom({ entry, rawName, role }) {
      const room = entry as TrtcRoomEntry;
      if (!supportsRole(role, room)) {
        throw new ProviderOperationError(400, 'unsupported-role', roleError(room, role));
      }
      const userId = `u-${crypto.randomUUID().replaceAll('-', '').slice(0, 30)}`;
      const attendee = {
        attendeeId: userId, externalUserId: normalizeDisplayName(rawName) || userId,
        role, joinedAt: new Date().toISOString(),
      };
      room.attendees.push(attendee);
      room.lastHeartbeatMs = Date.now();
      return credentials(room, attendee, role);
    },
    async refreshCredentials({ entry, participantId, role }) {
      const room = entry as TrtcRoomEntry;
      const attendee = room.attendees.find((item) => item.attendeeId === participantId);
      if (!attendee || attendee.role !== role) {
        throw new ProviderOperationError(
          403, 'forbidden', 'The participant is not authorized to refresh credentials for this room and role.',
        );
      }
      if (!supportsRole(role, room)) {
        throw new ProviderOperationError(400, 'unsupported-role', 'The role does not match this TRTC room scene.');
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
      const room = entry as TrtcRoomEntry;
      return {
        provider: 'trtc', roomCode: room.roomCode, meetingId: room.providerRoomName,
        externalMeetingId: room.providerRoomName, mediaRegion: 'TRTC', scene: room.scene,
        createdAt: room.createdAt,
        lastHeartbeat: new Date(room.lastHeartbeatMs ?? Date.now()).toISOString(),
        idleSec: Math.max(0, Math.round((Date.now() - (room.lastHeartbeatMs ?? Date.now())) / 1000)),
        attendeeCount: room.attendees.length, attendees: room.attendees, shareText: room.roomCode,
        shareLink: `multimedia://join?roomCode=${room.roomCode}&server=${host}`,
      };
    },
  };
}
