export type MediaRole = 'participant' | 'host' | 'viewer';
export type RoomMode = 'meeting' | 'broadcast';
export type MediaVendorId = 'aws' | string;
export type ProviderCapabilitySupport =
  | 'supported'
  | 'conditional'
  | 'unsupported';

export interface ProviderCapability {
  key: string;
  label: string;
  support: ProviderCapabilitySupport;
  note?: string;
}

export interface RoomAttendee {
  attendeeId: string;
  providerParticipantId?: string;
  participantCredentialHash?: string;
  externalUserId: string;
  userId?: string;
  displayName?: string;
  joinedAt: string;
  lastHeartbeatMs?: number;
  role?: MediaRole;
  deviceId?: string;
}

export interface ChatProviderMetadata {
  id: string;
  displayName: string;
  label: string;
  description: string;
  themeKey: string;
  enabled: boolean;
  configured: boolean;
  capabilities?: ProviderCapability[];
  engines?: Record<string, string>;
  [key: string]: unknown;
}

export interface ChatRoomBinding {
  chatProvider: string;
  chatRoomArn: string;
}

export interface IssueChatTokenInput {
  entry: RoomEntry;
  attendee: RoomAttendee;
}

export interface ChatProviderTokenResponse {
  contractVersion: number;
  chatProvider: string;
  roomCode: string;
  participantId: string;
  userId: string;
  displayName: string;
  role: MediaRole;
  chat: Record<string, unknown>;
}

export interface ChatProviderAdapter {
  id: string;
  displayName: string;
  label?: string;
  description?: string;
  themeKey?: string;
  enabled?: boolean;
  configurationError?: string;
  capabilityMatrix?: ProviderCapability[];

  isConfigured(): boolean;
  metadata?(): Record<string, unknown>;
  createRoom(roomCode: string): Promise<ChatRoomBinding>;
  issueToken(input: IssueChatTokenInput): Promise<ChatProviderTokenResponse>;
  closeRoom(entry: RoomEntry): Promise<void>;
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
  /** Public vendor identity. provider remains the concrete engine id. */
  vendor?: MediaVendorId;
  /** Concrete media implementation used for this room. */
  engine?: string;
  chatProvider?: string;
  chatRoomArn?: string;
  mediaClosed?: boolean;
  chatClosed?: boolean;
  closePending?: boolean;
  roomCode: string;
  roomMode?: RoomMode;
  roomOwnerCredentialHash?: string;
  createdAt: string;
  attendees: RoomAttendee[];
  lastHeartbeatMs: number;
  providerRoomName?: string;
  scene?: 'meeting' | 'live';
  meeting?: ChimeMeeting;
}

export interface IvsRoomEntry extends RoomEntry {
  provider: 'ivs';
  stageArn: string;
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

export interface ArtcRoomAttendee extends RoomAttendee {
  role: MediaRole;
}

export interface ArtcRoomEntry extends NamedRoomEntry {
  provider: 'artc';
  scene: 'meeting' | 'live';
  attendees: ArtcRoomAttendee[];
}

export interface ChimeRoomEntry extends RoomEntry {
  provider: 'chime';
  meeting: ChimeMeeting;
}

export interface ProviderBaseResponse {
  contractVersion: number;
  provider: string;
  vendor?: MediaVendorId;
  engine?: string;
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
  vendor?: MediaVendorId;
  engine?: string;
  chatProvider?: string;
  roomCode: string;
  roomMode?: RoomMode;
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
  capabilities?: ProviderCapability[];
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
  userId?: string;
  deviceId?: string | null;
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
  capabilityMatrix?: ProviderCapability[];

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
  moderateRemoveParticipant?(entry: RoomEntry, participantId: string): Promise<boolean>;
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
