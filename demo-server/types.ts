export type MediaRole = 'participant' | 'host' | 'viewer';

export interface RoomAttendee {
  attendeeId: string;
  externalUserId: string;
  joinedAt: string;
  role?: MediaRole;
}

export interface ChimeMeeting {
  MeetingId: string;
  ExternalMeetingId?: string;
  MediaRegion?: string;
  MediaPlacement?: unknown;
  MeetingArn?: string;
  TenantIds: string[];
}

export interface ChimeAttendee {
  AttendeeId: string;
  ExternalUserId: string;
  JoinToken?: string;
  Capabilities?: unknown;
}

export interface RoomEntry {
  provider: string;
  roomCode: string;
  createdAt: string;
  attendees: RoomAttendee[];
  lastHeartbeatMs: number;
  providerRoomName?: string;
  scene?: 'meeting' | 'live';
  meeting?: ChimeMeeting;
}

export interface NamedRoomEntry extends RoomEntry {
  providerRoomName: string;
}

export interface TrtcRoomAttendee extends RoomAttendee {
  role: MediaRole;
}

export interface TrtcRoomEntry extends NamedRoomEntry {
  provider: 'trtc';
  scene: 'meeting' | 'live';
  attendees: TrtcRoomAttendee[];
}

export interface ChimeRoomEntry extends RoomEntry {
  provider: 'chime';
  meeting: ChimeMeeting;
}

export interface ProviderBaseResponse {
  contractVersion: number;
  provider: string;
  role: MediaRole;
  roomCode: string;
  [key: string]: unknown;
}

export interface ProviderJoinResponse extends ProviderBaseResponse {
  participantId: string;
  displayName: string;
}

export interface RoomSummary {
  provider: string;
  roomCode: string;
  meetingId?: string;
  externalMeetingId?: string;
  mediaRegion?: string;
  scene?: string;
  createdAt: string;
  lastHeartbeat: string;
  idleSec: number;
  attendeeCount: number;
  attendees: RoomAttendee[];
  shareText: string;
  shareLink: string;
}

export interface ProviderMetadata {
  id: string;
  displayName: string;
  label: string;
  description: string;
  themeKey: string;
  enabled: boolean;
  configured: boolean;
  [key: string]: unknown;
}

export interface CreateRoomInput {
  roomCode: string;
  role: MediaRole;
  externalMeetingId?: string | null;
}

export interface CreateRoomResult {
  entry: RoomEntry;
  response: ProviderBaseResponse;
}

export interface JoinRoomInput {
  entry: RoomEntry;
  rawName: unknown;
  role: MediaRole;
}

export interface CloseRoomInput {
  entry: RoomEntry;
  reason: string;
}

export interface RefreshCredentialsInput {
  entry: RoomEntry;
  participantId: string;
  role: MediaRole;
}

export interface RemoveAttendeeResult {
  removed: boolean;
  closeWhenEmpty: boolean;
}

export interface ProviderAdapter {
  id: string;
  displayName: string;
  label?: string;
  description?: string;
  themeKey?: string;
  enabled?: boolean;
  configurationError?: string;

  isConfigured(): boolean;
  metadata?(): Record<string, unknown>;
  supportsRole(role: MediaRole, entry?: RoomEntry | null): boolean;
  roleError?(entry: RoomEntry | null, role: MediaRole): string;
  aliases?(entry: RoomEntry): string[];

  createRoom(input: CreateRoomInput): Promise<CreateRoomResult>;
  joinRoom(input: JoinRoomInput): Promise<ProviderJoinResponse>;
  closeRoom(input: CloseRoomInput): Promise<void>;
  summarizeRoom(entry: RoomEntry, context: { host: string }): RoomSummary;

  removeAttendee?(entry: RoomEntry, who: unknown): RemoveAttendeeResult;
  refreshCredentials?(input: RefreshCredentialsInput): Promise<ProviderJoinResponse>;
  resolveExternalRoom?(
    ref: string,
    context: { allocateRoomCode: () => string },
  ): Promise<RoomEntry | null>;
}

export interface LegacyChimeJoinResponse {
  roomCode: string;
  meeting: ChimeMeeting;
  attendee: ChimeAttendee;
}

export interface ChimeProviderAdapter extends ProviderAdapter {
  resolveExternalRoom(
    ref: string,
    context: { allocateRoomCode: () => string },
  ): Promise<RoomEntry | null>;
  createLegacyMeeting(input: {
    roomCode: string;
    externalMeetingId: string;
  }): Promise<CreateRoomResult>;
  joinLegacy(entry: RoomEntry, rawName: unknown): Promise<LegacyChimeJoinResponse>;
  getLegacyMeeting(meetingId: string): Promise<ChimeMeeting>;
  deleteLegacyMeeting(meetingId: string): Promise<void>;
}

export interface ProviderFactoryContext {
  env?: NodeJS.ProcessEnv;
  contractVersion: number;
}

export type NormalizeName = (raw: unknown) => string;
