import crypto from 'node:crypto';
import {
  ChimeSDKMeetingsClient,
  CreateMeetingCommand,
  CreateAttendeeCommand,
  GetMeetingCommand,
  DeleteMeetingCommand,
} from '@aws-sdk/client-chime-sdk-meetings';
import type {
  ChimeAttendee,
  ChimeMeeting,
  ChimeProviderAdapter,
  ChimeRoomEntry,
  CreateRoomResult,
  MediaRole,
  NormalizeName,
  ProviderFactoryContext,
  ProviderJoinResponse,
  RoomEntry,
} from '../types.ts';

type RawMeeting = {
  MeetingId?: string;
  ExternalMeetingId?: string;
  MediaRegion?: string;
  MediaPlacement?: unknown;
  MeetingArn?: string;
  TenantIds?: string[];
};

type RawAttendee = {
  AttendeeId?: string;
  ExternalUserId?: string;
  JoinToken?: string;
  Capabilities?: unknown;
};

function requiredString(value: string | undefined, field: string): string {
  if (!value) throw new Error(`AWS Chime response is missing ${field}.`);
  return value;
}

function pickMeeting(raw: RawMeeting | undefined): ChimeMeeting {
  if (!raw) throw new Error('AWS Chime response is missing Meeting.');
  return {
    MeetingId: requiredString(raw.MeetingId, 'MeetingId'),
    ExternalMeetingId: raw.ExternalMeetingId,
    MediaRegion: raw.MediaRegion,
    MediaPlacement: raw.MediaPlacement, MeetingArn: raw.MeetingArn, TenantIds: raw.TenantIds ?? [],
  };
}

function pickAttendee(raw: RawAttendee | undefined): ChimeAttendee {
  if (!raw) throw new Error('AWS Chime response is missing Attendee.');
  return {
    AttendeeId: requiredString(raw.AttendeeId, 'AttendeeId'),
    ExternalUserId: requiredString(raw.ExternalUserId, 'ExternalUserId'),
    JoinToken: raw.JoinToken, Capabilities: raw.Capabilities,
  };
}

export function createChimeProvider({
  env = process.env,
  contractVersion,
  normalizeUserId,
}: ProviderFactoryContext & { normalizeUserId: NormalizeName }): ChimeProviderAdapter {
  const controlRegion = env.AWS_REGION ?? 'us-east-1';
  const mediaRegion = env.CHIME_MEDIA_REGION ?? 'ap-southeast-1';
  const client = new ChimeSDKMeetingsClient({ region: controlRegion });

  async function addAttendee(entry: ChimeRoomEntry, rawName: unknown): Promise<ChimeAttendee> {
    const safeId = normalizeUserId(rawName);
    const created = await client.send(new CreateAttendeeCommand({
      MeetingId: entry.meeting.MeetingId,
      ExternalUserId: safeId,
    }));
    const attendee = pickAttendee(created.Attendee);
    entry.attendees.push({
      attendeeId: attendee.AttendeeId, externalUserId: attendee.ExternalUserId, joinedAt: new Date().toISOString(),
    });
    return attendee;
  }

  function joinResponse(
    entry: ChimeRoomEntry,
    attendee: ChimeAttendee,
    role: MediaRole = 'participant',
  ): ProviderJoinResponse {
    return {
      contractVersion, provider: 'chime', role, roomCode: entry.roomCode,
      participantId: attendee.AttendeeId, displayName: attendee.ExternalUserId,
      meeting: entry.meeting, attendee,
    };
  }

  async function createRoom({
    roomCode,
    role,
    externalMeetingId = null,
  }: {
    roomCode: string;
    role: MediaRole;
    externalMeetingId?: string | null;
  }): Promise<CreateRoomResult> {
    const out = await client.send(new CreateMeetingCommand({
      ClientRequestToken: crypto.randomUUID(),
      MediaRegion: mediaRegion,
      ExternalMeetingId: externalMeetingId ?? `room-${roomCode}`,
    }));
    const meeting = pickMeeting(out.Meeting);
    const entry: ChimeRoomEntry = {
      provider: 'chime',
      meeting,
      roomCode,
      createdAt: new Date().toISOString(),
      attendees: [],
      lastHeartbeatMs: Date.now(),
    };
    return {
      entry,
      response: { contractVersion, provider: 'chime', role, roomCode, meeting },
    };
  }

  const adapter: ChimeProviderAdapter = {
    id: 'chime',
    displayName: 'AWS Chime',
    label: 'AWS Chime SDK',
    description: 'Amazon Chime 媒体面',
    themeKey: 'chime',
    isConfigured: () => true,
    metadata: () => ({ controlRegion, mediaRegion }),
    supportsRole: (role: MediaRole) => role === 'participant',
    roleError: () => 'AWS Chime currently supports participant rooms only.',
    aliases(entry) {
      return entry.meeting?.MeetingId ? [entry.meeting.MeetingId] : [];
    },
    createRoom,
    async joinRoom({ entry, rawName, role }) {
      const room = entry as ChimeRoomEntry;
      const attendee = await addAttendee(room, rawName);
      room.lastHeartbeatMs = Date.now();
      return joinResponse(room, attendee, role);
    },
    async closeRoom({ entry }) {
      const room = entry as ChimeRoomEntry;
      try {
        await client.send(new DeleteMeetingCommand({ MeetingId: room.meeting.MeetingId }));
      } catch (error) {
        if (!(error instanceof Error) || error.name !== 'NotFoundException') throw error;
      }
    },
    removeAttendee() {
      return { removed: false, closeWhenEmpty: false };
    },
    summarizeRoom(entry, { host }) {
      const room = entry as ChimeRoomEntry;
      return {
        provider: 'chime', roomCode: room.roomCode, meetingId: room.meeting.MeetingId,
        externalMeetingId: room.meeting.ExternalMeetingId, mediaRegion: room.meeting.MediaRegion,
        createdAt: room.createdAt,
        lastHeartbeat: new Date(room.lastHeartbeatMs ?? Date.now()).toISOString(),
        idleSec: Math.max(0, Math.round((Date.now() - (room.lastHeartbeatMs ?? Date.now())) / 1000)),
        attendeeCount: room.attendees.length, attendees: room.attendees, shareText: room.roomCode,
        shareLink: `chimedemo://join?meetingId=${room.roomCode}&server=${host}`,
      };
    },
    async resolveExternalRoom(ref, { allocateRoomCode }): Promise<RoomEntry | null> {
      try {
        const got = await client.send(new GetMeetingCommand({ MeetingId: ref }));
        const entry: ChimeRoomEntry = {
          provider: 'chime', meeting: pickMeeting(got.Meeting), roomCode: allocateRoomCode(),
          createdAt: new Date().toISOString(), attendees: [], lastHeartbeatMs: Date.now(),
        };
        return entry;
      } catch {
        return null;
      }
    },
    async createLegacyMeeting({ roomCode, externalMeetingId }) {
      return createRoom({ roomCode, role: 'participant', externalMeetingId });
    },
    async joinLegacy(entry, rawName) {
      const room = entry as ChimeRoomEntry;
      const attendee = await addAttendee(room, rawName);
      return { roomCode: room.roomCode, meeting: room.meeting, attendee };
    },
    async getLegacyMeeting(meetingId) {
      const got = await client.send(new GetMeetingCommand({ MeetingId: meetingId }));
      return pickMeeting(got.Meeting);
    },
    async deleteLegacyMeeting(meetingId) {
      await client.send(new DeleteMeetingCommand({ MeetingId: meetingId }));
    },
  };

  return adapter;
}
