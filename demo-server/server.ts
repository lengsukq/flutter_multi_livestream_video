// Multi-provider demo backend — provider credentials stay server-side.
//
// `npm start` is the single backend entry point. Flutter sends room/user intent;
// this server selects a provider for new rooms and preserves that binding for
// the room lifetime. Provider SDK/token details live under demo-server/providers.

import crypto from 'node:crypto';
import express, {
  type NextFunction,
  type Request,
  type Response,
} from 'express';
import cors from 'cors';
import { readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { createAgoraProvider } from './providers/agora.ts';
import { createArtcProvider } from './providers/artc.ts';
import { createChimeProvider } from './providers/chime.ts';
import { createLiveKitProvider } from './providers/livekit.ts';
import { createIvsProvider } from './providers/ivs.ts';
import {
  AWS_VENDOR_ID,
  awsEngineForRoomMode,
  awsVendorMetadata,
  isAwsEngine,
  publicVendorForEngine,
} from './providers/aws.ts';
import { ChatProviderRegistry } from './chat/chat-provider-registry.ts';
import { ChatRoomDirectory } from './chat/chat-room-directory.ts';
import {
  createIvsChatProvider,
  resolveIvsChatRegion,
} from './chat/ivs-chat.ts';
import { createTencentChatProvider } from './chat/tencent-chat.ts';
import { createAgoraChatProvider } from './chat/agora-chat.ts';
import {
  issueParticipantCredential,
  requireParticipantCredential,
} from './participant-credential.ts';
import {
  issueRoomOwnerCredential,
  matchesRoomOwnerCredential,
} from './room-owner-credential.ts';
import { ProviderOperationError, ProviderRegistry } from './providers/provider-registry.ts';
import { RoomDirectory } from './providers/room-directory.ts';
import { createTrtcProvider } from './providers/trtc.ts';
import type {
  ChatRoomEntry,
  ChimeRoomEntry,
  MediaRole,
  ProviderAdapter,
  RoomAttendee,
  RoomMode,
  RoomEntry,
  RoomSummary,
} from './types.ts';

const CONTROL_REGION = process.env.AWS_REGION ?? 'us-east-1';
const MEDIA_REGION = process.env.CHIME_MEDIA_REGION ?? 'ap-southeast-1';
const CONTRACT_VERSION = 1;
const MEDIA_CONTRACT_HEADER = 'X-Media-Backend-Contract';
const CHAT_CONTRACT_HEADER = 'X-Realtime-Chat-Contract';
const LEGACY_CHIME_CONTRACT_HEADER = 'X-Chime-Backend-Contract';
const DEMO_BEARER_TOKEN = process.env.DEMO_BEARER_TOKEN?.trim() || null;
const MEDIA_ADMIN_PASSWORD = process.env.MEDIA_ADMIN_PASSWORD?.trim() || '';
const ADMIN_SESSION_COOKIE = 'media_admin_session';
const ADMIN_SESSION_TTL_SECONDS = 8 * 60 * 60;
const IS_VERCEL = process.env.VERCEL === '1';
const MEDIA_CONNECTIONS_ENABLED = parseBoolean(
  process.env.MEDIA_CONNECTIONS_ENABLED,
  !IS_VERCEL,
);
const INITIAL_PROVIDER = String(process.env.MEDIA_DEFAULT_PROVIDER ?? 'aws').trim().toLowerCase();
const INITIAL_CHAT_PROVIDER = String(process.env.CHAT_DEFAULT_PROVIDER ?? 'none').trim().toLowerCase();
const STARTED_AT = Date.now();
const EMPTY_CLOSE_AFTER_MS = Number(process.env.EMPTY_CLOSE_AFTER_MS ?? 90_000);
const PARTICIPANT_STALE_AFTER_MS = Number(
  process.env.PARTICIPANT_STALE_AFTER_MS ?? Math.max(120_000, EMPTY_CLOSE_AFTER_MS),
);
const SWEEP_INTERVAL_MS = 30_000;

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROVIDER_STATE_PATH = process.env.MEDIA_PROVIDER_STATE_PATH ?? path.join(__dirname, '.provider-state.json');

const app = express();
app.set('trust proxy', 1);
app.use(cors({
  origin: true,
  methods: ['GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: [
    'Authorization',
    'Content-Type',
    'X-Media-Backend-Contract',
    'X-Realtime-Chat-Contract',
    'X-Chime-Backend-Contract',
  ],
  exposedHeaders: [MEDIA_CONTRACT_HEADER, CHAT_CONTRACT_HEADER],
  maxAge: 600,
}));
app.use(express.json({ limit: '64kb' }));

function parseBoolean(value: string | undefined, fallback: boolean): boolean {
  if (value == null || value.trim() === '') return fallback;
  return ['1', 'true', 'yes', 'on'].includes(value.trim().toLowerCase());
}

function pruneStaleAttendees(entry: RoomEntry, now: number): void {
  entry.attendees = entry.attendees.filter((attendee) => {
    const lastSeen = attendee.lastHeartbeatMs;
    return lastSeen == null || now - lastSeen <= PARTICIPANT_STALE_AFTER_MS;
  });
}

function bindLogicalIdentity(
  entry: RoomEntry,
  participantId: string,
  userId: string,
  displayName: string,
  deviceId: string | null,
  role: MediaRole,
): void {
  const current = entry.attendees.find(
    (attendee) => attendee.attendeeId === participantId,
  );
  if (!current) return;
  current.userId = userId;
  current.displayName = displayName;
  current.externalUserId = displayName;
  current.role = role;
  current.lastHeartbeatMs = Date.now();
  if (deviceId) current.deviceId = deviceId;
  entry.attendees = entry.attendees.filter((attendee) => {
    if (attendee.attendeeId === participantId) return true;
    if (attendee.role === 'host') {
      if (role === 'host') return false;
      // A normal join must not evict the logical owner merely by reusing its
      // public user id. The same device may replace its stale logical entry
      // without gaining host authority.
      return !(deviceId && attendee.deviceId === deviceId);
    }
    return (
      attendee.userId !== userId &&
      (!deviceId || attendee.deviceId !== deviceId)
    );
  });
}


function getCookie(req: Request, name: string): string | null {
  const header = req.get('Cookie');
  if (!header) return null;
  for (const pair of header.split(';')) {
    const separator = pair.indexOf('=');
    if (separator < 0 || pair.slice(0, separator).trim() !== name) continue;
    const value = pair.slice(separator + 1).trim();
    try { return decodeURIComponent(value); } catch (_) { return value; }
  }
  return null;
}

function adminSessionSignature(expiresAtSeconds: string): string {
  return crypto.createHmac('sha256', MEDIA_ADMIN_PASSWORD).update(expiresAtSeconds).digest('base64url');
}

function hasAdminSession(req: Request): boolean {
  if (!MEDIA_ADMIN_PASSWORD) return false;
  const token = getCookie(req, ADMIN_SESSION_COOKIE);
  if (!token) return false;
  const [expiresAtSeconds, signature, ...extra] = token.split('.');
  if (extra.length || !expiresAtSeconds || !/^\d{10}$/.test(expiresAtSeconds) || !signature) return false;
  if (Number(expiresAtSeconds) <= Math.floor(Date.now() / 1000)) return false;
  const supplied = Buffer.from(signature, 'base64url');
  const expected = Buffer.from(adminSessionSignature(expiresAtSeconds), 'base64url');
  return supplied.length === expected.length && crypto.timingSafeEqual(supplied, expected);
}

function setAdminCookie(res: Response, req: Request): void {
  const expiresAtSeconds = String(Math.floor(Date.now() / 1000) + ADMIN_SESSION_TTL_SECONDS);
  const secure = IS_VERCEL || req.secure;
  res.setHeader(
    'Set-Cookie',
    `${ADMIN_SESSION_COOKIE}=${expiresAtSeconds}.${adminSessionSignature(expiresAtSeconds)}; Path=/; HttpOnly; SameSite=Strict; Max-Age=${ADMIN_SESSION_TTL_SECONDS}${secure ? '; Secure' : ''}`,
  );
}

function clearAdminCookie(res: Response, req: Request): void {
  const secure = IS_VERCEL || req.secure;
  res.setHeader(
    'Set-Cookie',
    `${ADMIN_SESSION_COOKIE}=; Path=/; HttpOnly; SameSite=Strict; Max-Age=0${secure ? '; Secure' : ''}`,
  );
}

function requireSameOrigin(req: Request, res: Response, next: NextFunction): Response | void {
  const origin = req.get('Origin');
  if (!origin) return next();
  const protocol = req.get('x-forwarded-proto')?.split(',')[0]?.trim() || req.protocol;
  const expectedOrigin = `${protocol}://${req.get('host')}`;
  try {
    if (new URL(origin).origin === expectedOrigin) return next();
  } catch (_) {
    // Invalid Origin headers are rejected below.
  }
  return contractError(res, 403, 'cross-origin-request', 'Admin actions must come from this site.');
}

function requireAdmin(req: Request, res: Response, next: NextFunction): Response | void {
  res.set('Cache-Control', 'no-store');
  if (!MEDIA_ADMIN_PASSWORD && !IS_VERCEL && process.env.NODE_ENV !== 'production') return next();
  if (!MEDIA_ADMIN_PASSWORD) {
    return contractError(res, 503, 'admin-not-configured', 'Set MEDIA_ADMIN_PASSWORD before using admin routes.');
  }
  if (!hasAdminSession(req)) {
    return contractError(res, 401, 'admin-auth-required', 'Sign in to manage this service.');
  }
  next();
}

function requireConnectionsEnabled(_req: Request, res: Response, next: NextFunction): Response | void {
  if (MEDIA_CONNECTIONS_ENABLED) return next();
  return contractError(res, 503, 'service-paused', 'The media connection service is paused.');
}

function requireLegacyConnectionAccess(req: Request, res: Response, next: NextFunction): Response | void {
  // Keep administrator cleanup available while the public connection API is paused.
  if (req.method === 'DELETE' && /^\/[^/]+$/.test(req.path)) return next();
  if (!MEDIA_CONNECTIONS_ENABLED) {
    return contractError(res, 503, 'service-paused', 'The media connection service is paused.');
  }
  if (
    DEMO_BEARER_TOKEN &&
    req.get('Authorization') !== `Bearer ${DEMO_BEARER_TOKEN}` &&
    !hasAdminSession(req)
  ) {
    return contractError(res, 401, 'unauthorized', 'A valid demo bearer token is required.');
  }
  next();
}

function normalizeRoomCode(raw: unknown): string | null {
  if (raw == null) return null;
  const code = String(raw).trim();
  return /^[A-Za-z0-9]{4,12}$/.test(code) ? code : null;
}

function normalizeUserId(raw: unknown): string {
  const id = String(raw ?? '').trim() || `user-${crypto.randomUUID().slice(0, 8)}`;
  if (/^[-_&@+=,(){}\[\]\/«.:\s'"#a-zA-Z0-9À-ÿ]*$/.test(id) && id.length <= 64) return id;
  const ascii = id
    .replace(/[^\x20-\x7E]/g, '')
    .replace(/[^A-Za-z0-9\-_=@,. ]/g, '')
    .trim()
    .slice(0, 48);
  return ascii || `user-${crypto.randomUUID().slice(0, 8)}`;
}

function normalizeDisplayName(raw: unknown): string {
  return String(raw ?? '').trim().slice(0, 64);
}

function normalizeDeviceId(raw: unknown): string | null {
  if (raw == null) return null;
  const value = String(raw).trim();
  if (!value) return null;
  return /^[A-Za-z0-9._:-]{8,128}$/.test(value) ? value : null;
}

function bindDevicePresence(
  entry: RoomEntry,
  participantId: string,
  deviceId: string | null,
): void {
  if (!deviceId) return;
  const current = entry.attendees.find(
    (attendee) => attendee.attendeeId === participantId,
  );
  if (!current) return;
  current.deviceId = deviceId;
  current.lastHeartbeatMs = Date.now();
  entry.attendees = entry.attendees.filter(
    (attendee) =>
      attendee.attendeeId === participantId || attendee.deviceId !== deviceId,
  );
}

function parseRole(raw: unknown): MediaRole | null {
  const role = String(raw ?? 'participant').trim().toLowerCase();
  if (role === 'participant' || role === 'host' || role === 'viewer') return role;
  return null;
}

function parseRoomMode(raw: unknown): RoomMode | null {
  if (raw == null || String(raw).trim() === '') return null;
  const mode = String(raw).trim().toLowerCase();
  return mode === 'meeting' || mode === 'broadcast' ? mode : null;
}

function creatorRoleForMode(mode: RoomMode): MediaRole {
  return mode === 'broadcast' ? 'host' : 'participant';
}

function joinRoleForRoom(
  entry: RoomEntry,
  roomOwnerCredential: unknown,
): MediaRole {
  if (entry.roomMode !== 'broadcast') return 'participant';
  const credential = String(roomOwnerCredential ?? '').trim();
  if (!credential) return 'viewer';
  if (!matchesRoomOwnerCredential(entry, credential)) {
    throw new ProviderOperationError(
      403,
      'forbidden',
      'The room owner credential is invalid.',
    );
  }
  return 'host';
}

const chimeProvider = createChimeProvider({
  env: process.env,
  contractVersion: CONTRACT_VERSION,
  normalizeUserId,
});

function requireStandaloneChatHost(entry: ChatRoomEntry, body: Record<string, unknown>): RoomAttendee {
  const participantId = String(body.requesterParticipantId ?? '').trim();
  const attendee = requireParticipantCredential(
    entry,
    participantId,
    body.participantCredential,
  );
  if (attendee.role !== 'host') {
    throw new ProviderOperationError(403, 'forbidden', 'Chat management requires the host role.');
  }
  return attendee;
}

app.post('/chat/rooms/:code/members', (req, res) => {
  try {
    const entry = chatRoomDirectory.get(req.params.code);
    if (!entry) {
      return contractError(res, 404, 'room-not-found', 'The requested chat room was not found.');
    }
    requireStandaloneChatHost(entry, req.body ?? {});
    res.json({
      contractVersion: CONTRACT_VERSION,
      roomCode: entry.roomCode,
      members: entry.attendees.map((item) => ({
        userId: item.userId ?? item.externalUserId,
        displayName: item.displayName ?? item.externalUserId,
        role: item.role ?? 'participant',
      })),
    });
  } catch (error) {
    if (sendProviderError(res, error) !== false) return;
    throw error;
  }
});

app.post('/chat/rooms/:code/manage/close', async (req, res) => {
  try {
    const entry = chatRoomDirectory.get(req.params.code);
    if (!entry || !entry.chatProvider) {
      return contractError(res, 404, 'room-not-found', 'The requested chat room was not found.');
    }
    requireStandaloneChatHost(entry, req.body ?? {});
    const provider = chatProviderRegistry.requireConfigured(entry.chatProvider);
    await provider.closeRoom(entry);
    chatRoomDirectory.remove(entry.roomCode);
    res.json({ contractVersion: CONTRACT_VERSION, ok: true, roomCode: entry.roomCode });
  } catch (error) {
    if (sendProviderError(res, error) !== false) return;
    console.error('standalone chat close failed', error);
    contractError(res, 500, 'chat-room-close-failed', 'Unable to close the chat room.');
  }
});

app.post('/chat/rooms/:code/credentials', async (req, res) => {
  try {
    const entry = chatRoomDirectory.get(req.params.code);
    if (!entry || !entry.chatProvider) {
      return contractError(res, 404, 'room-not-found', 'The requested chat room was not found.');
    }
    const participantId = String(req.body?.participantId ?? '').trim();
    const attendee = requireParticipantCredential(
      entry,
      participantId,
      req.body?.participantCredential,
    );
    const provider = chatProviderRegistry.requireConfigured(entry.chatProvider);
    const response = await provider.issueToken({ entry, attendee });
    res.json({
      ...response,
      participantCredential: String(req.body?.participantCredential ?? '').trim(),
      context: 'standalone',
    });
  } catch (error) {
    if (sendProviderError(res, error) !== false) return;
    console.error('standalone chat credential refresh failed', error);
    contractError(res, 500, 'chat-credential-refresh-failed', 'Unable to refresh chat credentials.');
  }
});

app.get('/chat/rooms', (_req, res) => {
  res.json({
    contractVersion: CONTRACT_VERSION,
    rooms: chatRoomDirectory.list().map((entry) => ({
      roomCode: entry.roomCode,
      chatProvider: entry.chatProvider,
      context: 'standalone',
      createdAt: entry.createdAt,
    })),
  });
});

app.post('/chat/rooms', async (req, res) => {
  try {
    const providerId = String(
      req.body?.chatProvider ?? activeChatProvider ?? '',
    ).trim().toLowerCase();
    if (!providerId) {
      return contractError(
        res,
        400,
        'provider-not-configured',
        'Select a configured chat provider before creating a chat room.',
      );
    }
    const provider = chatProviderRegistry.requireConfigured(providerId);
    const requestedCode = String(req.body?.roomCode ?? '').trim();
    const roomCode = requestedCode || generateRoomCode();
    if (chatRoomDirectory.get(roomCode)) {
      return contractError(res, 409, 'room-exists', 'The chat room code is already in use.');
    }
    const binding = await provider.createRoom(roomCode);
    const now = Date.now();
    const entry = chatRoomDirectory.add({
      roomCode,
      chatProvider: binding.chatProvider,
      chatRoomArn: binding.chatRoomArn,
      createdAt: new Date(now).toISOString(),
      attendees: [],
      lastHeartbeatMs: now,
    });
    const userId = String(req.body?.userId ?? '').trim();
    if (userId) {
      const displayName = normalizeDisplayName(req.body?.displayName ?? userId);
      const participantId = `chat-${crypto.randomUUID()}`;
      const attendee: RoomAttendee = {
        attendeeId: participantId,
        externalUserId: userId,
        userId,
        displayName,
        role: 'host',
        joinedAt: new Date(now).toISOString(),
        lastHeartbeatMs: now,
      };
      entry.attendees.push(attendee);
      const participantCredential = issueParticipantCredential(entry, participantId);
      const response = await provider.issueToken({ entry, attendee });
      return res.status(201).json({
        ...response,
        participantCredential,
        context: 'standalone',
      });
    }
    res.status(201).json({
      contractVersion: CONTRACT_VERSION,
      roomCode: entry.roomCode,
      chatProvider: entry.chatProvider,
      context: 'standalone',
    });
  } catch (error) {
    if (sendProviderError(res, error) !== false) return;
    console.error('standalone chat room create failed', error);
    contractError(res, 500, 'chat-room-create-failed', 'Unable to create the chat room.');
  }
});

app.post('/chat/rooms/:code/join', async (req, res) => {
  try {
    const entry = chatRoomDirectory.get(req.params.code);
    if (!entry || !entry.chatProvider) {
      return contractError(res, 404, 'room-not-found', 'The requested chat room was not found.');
    }
    const provider = chatProviderRegistry.requireConfigured(entry.chatProvider);
    const userId = normalizeUserId(req.body?.userId);
    const displayName = normalizeDisplayName(req.body?.displayName ?? userId);
    // Public joins are never allowed to self-promote to host. The creator gets
    // host credentials atomically from POST /chat/rooms.
    const role: MediaRole = 'participant';
    const participantId = `chat-${crypto.randomUUID()}`;
    const attendee: RoomAttendee = {
      attendeeId: participantId,
      externalUserId: userId,
      userId,
      displayName,
      role,
      joinedAt: new Date().toISOString(),
      lastHeartbeatMs: Date.now(),
    };
    entry.attendees.push(attendee);
    entry.lastHeartbeatMs = Date.now();
    const response = await provider.issueToken({ entry, attendee });
    const participantCredential = issueParticipantCredential(entry, participantId);
    res.json({ ...response, participantCredential, context: 'standalone' });
  } catch (error) {
    if (sendProviderError(res, error) !== false) return;
    console.error('standalone chat join failed', error);
    contractError(res, 500, 'chat-join-failed', 'Unable to join the chat room.');
  }
});
const ivsProvider = createIvsProvider({
  env: process.env,
  contractVersion: CONTRACT_VERSION,
  normalizeDisplayName,
});

app.post('/api/chat-provider', requireSameOrigin, requireAdmin, (req, res) => {
  const requested = String(req.body?.provider ?? '').trim().toLowerCase();
  try {
    if (requested === 'none' || requested === '') {
      activeChatProvider = null;
    } else {
      activeChatProvider = chatProviderRegistry.requireConfigured(requested).id;
    }
    logEvent(
      'chat-provider-switch',
      activeChatProvider
        ? `new rooms will use chat provider ${activeChatProvider}`
        : 'new rooms will not attach a chat provider',
    );
    persistActiveProviders(activeProvider, activeChatProvider);
    res.json({ ok: true, activeChatProvider });
  } catch (error) {
    if (sendProviderError(res, error) !== false) return;
    throw error;
  }
});
const providerRegistry = new ProviderRegistry([
  chimeProvider,
  createLiveKitProvider({ env: process.env, contractVersion: CONTRACT_VERSION, normalizeDisplayName }),
  createAgoraProvider({ env: process.env, contractVersion: CONTRACT_VERSION, normalizeDisplayName }),
  createTrtcProvider({ env: process.env, contractVersion: CONTRACT_VERSION, normalizeDisplayName }),
  createArtcProvider({ env: process.env, contractVersion: CONTRACT_VERSION, normalizeDisplayName }),
  ivsProvider,
]);
const ivsChatRegion = await resolveIvsChatRegion(process.env);
const chatProviderRegistry = new ChatProviderRegistry([
  createIvsChatProvider({
    env: process.env,
    contractVersion: CONTRACT_VERSION,
    resolvedRegion: ivsChatRegion,
  }),
  createTencentChatProvider({
    env: process.env,
    contractVersion: CONTRACT_VERSION,
  }),
  createAgoraChatProvider({
    env: process.env,
    contractVersion: CONTRACT_VERSION,
  }),
]);
const roomDirectory = new RoomDirectory();
const chatRoomDirectory = new ChatRoomDirectory();
const events: Array<{ ts: string; type: string; message: string }> = [];

if (INITIAL_PROVIDER !== AWS_VENDOR_ID) providerRegistry.require(INITIAL_PROVIDER);

function engineProviderForSelection(providerId: string, roomMode: RoomMode): ProviderAdapter {
  const engineId = providerId === AWS_VENDOR_ID
    ? awsEngineForRoomMode(roomMode)
    : providerId;
  return providerRegistry.requireConfigured(engineId);
}

function publicProviderId(engineId: string): string {
  return publicVendorForEngine(engineId);
}

function exposeVendorResponse<T extends { provider: string; [key: string]: unknown }>(
  response: T,
): T {
  if (!isAwsEngine(response.provider)) return response;
  const engine = response.provider;
  return { ...response, provider: AWS_VENDOR_ID, vendor: AWS_VENDOR_ID, engine };
}

function providerMetadataForDashboard() {
  return [
    awsVendorMetadata(chimeProvider, ivsProvider),
    ...providerRegistry.metadata().filter((item) => !isAwsEngine(item.id)),
  ];
}

function logEvent(type: string, message: string): void {
  events.unshift({ ts: new Date().toISOString(), type, message });
  if (events.length > 200) events.pop();
  console.log(`[${type}] ${message}`);
}

function contractError(
  res: Response,
  status: number,
  code: string,
  message: string,
  details: unknown = undefined,
): Response {
  return res.status(status).json({
    contractVersion: CONTRACT_VERSION,
    error: { code, message, ...(details === undefined ? {} : { details }) },
  });
}

function sendProviderError(res: Response, error: unknown): Response | false {
  if (error instanceof ProviderOperationError) {
    return contractError(res, error.status, error.code, error.message, error.details);
  }
  return false;
}

function requireRoomContract(req: Request, res: Response, next: NextFunction): Response | void {
  res.set(MEDIA_CONTRACT_HEADER, String(CONTRACT_VERSION));
  res.set(CHAT_CONTRACT_HEADER, String(CONTRACT_VERSION));
  const requestedVersion =
    req.get(MEDIA_CONTRACT_HEADER) ??
    req.get(CHAT_CONTRACT_HEADER) ??
    req.get(LEGACY_CHIME_CONTRACT_HEADER);
  if (requestedVersion && requestedVersion !== String(CONTRACT_VERSION)) {
    return contractError(
      res,
      400,
      'unsupported-contract-version',
      `This demo server supports backend contract v${CONTRACT_VERSION}.`,
    );
  }
  if (
    DEMO_BEARER_TOKEN &&
    req.get('Authorization') !== `Bearer ${DEMO_BEARER_TOKEN}` &&
    !hasAdminSession(req)
  ) {
    return contractError(res, 401, 'unauthorized', 'A valid demo bearer token is required.');
  }
  next();
}

app.use('/rooms', (req, res, next) => {
  const isRoomList = req.method === 'GET' && req.path === '/';
  const isRoomDiscovery = req.method === 'GET' && req.path === '/discover';
  const isRoomCleanup = req.method === 'DELETE' && /^\/[^/]+$/.test(req.path);
  if (isRoomList || isRoomDiscovery || isRoomCleanup) {
    return requireRoomContract(req, res, next);
  }
  return requireConnectionsEnabled(req, res, () => requireRoomContract(req, res, next));
});
app.use(['/meetings', '/join'], requireLegacyConnectionAccess);

app.post('/api/admin/login', requireSameOrigin, (req, res) => {
  res.set('Cache-Control', 'no-store');
  if (!MEDIA_ADMIN_PASSWORD) {
    return contractError(res, 503, 'admin-not-configured', 'Admin login is not configured.');
  }
  const password = typeof req.body?.password === 'string' ? req.body.password : '';
  const supplied = crypto.createHash('sha256').update(password).digest();
  const expected = crypto.createHash('sha256').update(MEDIA_ADMIN_PASSWORD).digest();
  if (!crypto.timingSafeEqual(supplied, expected)) {
    return contractError(res, 401, 'invalid-admin-password', 'The management password is incorrect.');
  }
  setAdminCookie(res, req);
  res.json({ ok: true, expiresInSeconds: ADMIN_SESSION_TTL_SECONDS });
});

app.post('/api/admin/logout', requireSameOrigin, (req, res) => {
  res.set('Cache-Control', 'no-store');
  clearAdminCookie(res, req);
  res.json({ ok: true });
});

app.get('/api/admin/session', requireAdmin, (_req, res) => {
  res.json({ authenticated: true, connectionsEnabled: MEDIA_CONNECTIONS_ENABLED });
});

function generateRoomCode(): string {
  for (let i = 0; i < 50; i++) {
    const code = String(Math.floor(100000 + Math.random() * 900000));
    if (!roomDirectory.has(code)) return code;
  }
  return String(Date.now()).slice(-6);
}

function providerAliases(provider: ProviderAdapter, entry: RoomEntry): string[] {
  return typeof provider.aliases === 'function' ? provider.aliases(entry) : [];
}

function registerRoom(provider: ProviderAdapter, entry: RoomEntry): RoomEntry {
  return roomDirectory.register(entry, providerAliases(provider, entry));
}

function assertRole(
  provider: ProviderAdapter,
  role: MediaRole,
  entry: RoomEntry | null = null,
): void {
  if (provider.supportsRole(role, entry)) return;
  const message = typeof provider.roleError === 'function'
    ? provider.roleError(entry, role)
    : `${provider.displayName ?? provider.id} does not support the ${role} role.`;
  throw new ProviderOperationError(400, 'unsupported-role', message);
}

function loadPersistedProvider(): string {
  // Vercel instances are ephemeral and may run concurrently. Deployment config
  // is the only reliable source for its default provider.
  if (IS_VERCEL) {
    if (INITIAL_PROVIDER === AWS_VENDOR_ID) return AWS_VENDOR_ID;
    const initial = providerRegistry.require(INITIAL_PROVIDER);
    return initial.isConfigured() ? initial.id : AWS_VENDOR_ID;
  }
  try {
    const parsed = JSON.parse(readFileSync(PROVIDER_STATE_PATH, 'utf8')) as {
      provider?: unknown;
    };
    if (parsed?.provider === AWS_VENDOR_ID) return AWS_VENDOR_ID;
    if (isAwsEngine(parsed?.provider)) return AWS_VENDOR_ID;
    const provider = providerRegistry.get(parsed?.provider);
    if (provider?.isConfigured()) return provider.id;
  } catch (_) {
    // Missing/corrupt runtime state falls back to MEDIA_DEFAULT_PROVIDER.
  }
  if (INITIAL_PROVIDER === AWS_VENDOR_ID || isAwsEngine(INITIAL_PROVIDER)) return AWS_VENDOR_ID;
  const initial = providerRegistry.require(INITIAL_PROVIDER);
  return initial.isConfigured() ? initial.id : AWS_VENDOR_ID;
}

function loadPersistedChatProvider(): string | null {
  const configuredDefault = INITIAL_CHAT_PROVIDER === 'none'
    ? null
    : chatProviderRegistry.get(INITIAL_CHAT_PROVIDER);
  if (IS_VERCEL) {
    return configuredDefault?.isConfigured() ? configuredDefault.id : null;
  }
  try {
    const parsed = JSON.parse(readFileSync(PROVIDER_STATE_PATH, 'utf8')) as {
      chatProvider?: unknown;
    };
    const hasPersistedSelection = Object.prototype.hasOwnProperty.call(
      parsed,
      'chatProvider',
    );
    if (!hasPersistedSelection) {
      return configuredDefault?.isConfigured() ? configuredDefault.id : null;
    }
    if (parsed.chatProvider == null || parsed.chatProvider === 'none') return null;
    const provider = chatProviderRegistry.get(parsed.chatProvider);
    if (provider?.isConfigured()) return provider.id;
  } catch (_) {
    // Missing/corrupt state falls back to CHAT_DEFAULT_PROVIDER.
  }
  return configuredDefault?.isConfigured() ? configuredDefault.id : null;
}

function persistActiveProviders(mediaProvider: string, chatProvider: string | null): void {
  if (IS_VERCEL) return;
  try {
    writeFileSync(
      PROVIDER_STATE_PATH,
      JSON.stringify(
        {
          provider: mediaProvider,
          chatProvider: chatProvider ?? 'none',
          updatedAt: new Date().toISOString(),
        },
        null,
        2,
      ) + '\n',
      'utf8',
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.warn(`Unable to persist media provider selection: ${message}`);
  }
}

let activeProvider = loadPersistedProvider();
let activeChatProvider = loadPersistedChatProvider();

async function resolveRoom(ref: unknown): Promise<RoomEntry | null> {
  const key = String(ref ?? '').trim();
  if (!key) return null;
  const local = roomDirectory.get(key);
  if (local) return local;

  for (const provider of providerRegistry.list()) {
    if (typeof provider.resolveExternalRoom !== 'function') continue;
    const entry = await provider.resolveExternalRoom(key, { allocateRoomCode: generateRoomCode });
    if (entry) return registerRoom(provider, entry);
  }
  return null;
}

async function resolveChimeRoom(ref: unknown): Promise<RoomEntry | null> {
  const local = roomDirectory.get(ref);
  if (local?.provider === 'chime') return local;
  const entry = await chimeProvider.resolveExternalRoom(String(ref ?? '').trim(), {
    allocateRoomCode: generateRoomCode,
  });
  return entry ? registerRoom(chimeProvider, entry) : null;
}

async function closeRoom(entry: RoomEntry, reason: string): Promise<void> {
  const provider = providerRegistry.require(entry.provider);
  entry.closePending = true;
  let chatError: unknown;
  if (entry.chatProvider && !entry.chatClosed) {
    try {
      await chatProviderRegistry.require(entry.chatProvider).closeRoom(entry);
      entry.chatClosed = true;
    } catch (error) {
      chatError = error;
    }
  }
  let mediaError: unknown;
  if (!entry.mediaClosed) {
    try {
      await provider.closeRoom({ entry, reason });
      entry.mediaClosed = true;
    } catch (error) {
      mediaError = error;
    }
  }
  if (mediaError || chatError) {
    logEvent(
      'error',
      `room ${entry.roomCode} close incomplete (${reason}); retry remains possible`,
    );
    if (mediaError) throw mediaError;
    throw chatError;
  }
  roomDirectory.remove(entry);
  const suffix = entry.provider === 'chime' ? ' — billing for future joins stops' : '';
  logEvent('delete', `room ${entry.roomCode} closed (${reason})${suffix}`);
}

function summarizeRoom(entry: RoomEntry, req?: Request): RoomSummary {
  pruneStaleAttendees(entry, Date.now());
  const provider = providerRegistry.require(entry.provider);
  const host = req ? `${req.protocol}://${req.get('host')}` : '';
  const providerSummary = provider.summarizeRoom(entry, { host });
  return {
    ...providerSummary,
    provider: publicProviderId(entry.provider),
    ...(isAwsEngine(entry.provider)
      ? { vendor: AWS_VENDOR_ID, engine: entry.provider }
      : {}),
    attendees: providerSummary.attendees.map((attendee) => ({
      attendeeId: attendee.attendeeId,
      ...(attendee.providerParticipantId
        ? { providerParticipantId: attendee.providerParticipantId }
        : {}),
      externalUserId: attendee.externalUserId,
      ...(attendee.userId ? { userId: attendee.userId } : {}),
      ...(attendee.displayName ? { displayName: attendee.displayName } : {}),
      joinedAt: attendee.joinedAt,
      ...(attendee.lastHeartbeatMs != null
        ? { lastHeartbeatMs: attendee.lastHeartbeatMs }
        : {}),
      ...(attendee.role ? { role: attendee.role } : {}),
      ...(attendee.deviceId ? { deviceId: attendee.deviceId } : {}),
    })),
    ...(entry.roomMode ? { roomMode: entry.roomMode } : {}),
    ...(entry.chatProvider ? { chatProvider: entry.chatProvider } : {}),
  };
}

function isRoomPartiallyClosed(entry: RoomEntry): boolean {
  return (
    entry.closePending === true ||
    entry.mediaClosed === true ||
    entry.chatClosed === true
  );
}

if (!IS_VERCEL) {
  setInterval(() => {
    const now = Date.now();
    for (const entry of roomDirectory.entries()) {
      pruneStaleAttendees(entry, now);
      if (now - (entry.lastHeartbeatMs ?? 0) <= EMPTY_CLOSE_AFTER_MS) continue;
      const idleSec = Math.round((now - entry.lastHeartbeatMs) / 1000);
      closeRoom(entry, `idle ${idleSec}s, no heartbeat`).catch((error) =>
        console.error('auto-close failed', entry.roomCode, error),
      );
    }
  }, SWEEP_INTERVAL_MS);
}

app.get('/', (_req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.get('/health', (_req, res) => {
  const currentConfigured = activeProvider === AWS_VENDOR_ID
    ? chimeProvider.isConfigured() || ivsProvider.isConfigured()
    : providerRegistry.require(activeProvider).isConfigured();
  const providerList = providerMetadataForDashboard();
  const chatProviderList = chatProviderRegistry.metadata();
  res.json({
    ok: currentConfigured,
    connectionsEnabled: MEDIA_CONNECTIONS_ENABLED,
    contractVersion: CONTRACT_VERSION,
    activeProvider,
    activeChatProvider,
    controlRegion: CONTROL_REGION,
    mediaRegion: MEDIA_REGION,
    providers: Object.fromEntries(providerList.map((item) => [item.id, item])),
    providerList,
    chatProviders: Object.fromEntries(chatProviderList.map((item) => [item.id, item])),
    chatProviderList,
  });
});

app.post('/api/provider', requireSameOrigin, requireAdmin, (req, res) => {
  if (IS_VERCEL && req.body?.provider !== activeProvider) {
    return contractError(
      res,
      409,
      'provider-selection-is-deployment-config',
      'Set MEDIA_DEFAULT_PROVIDER in Vercel and redeploy to change the default provider.',
    );
  }
  try {
    const requested = String(req.body?.provider ?? '').trim().toLowerCase();
    const selected = isAwsEngine(requested) ? AWS_VENDOR_ID : requested;
    if (selected !== AWS_VENDOR_ID) providerRegistry.requireConfigured(selected);
    if (selected !== activeProvider) {
      activeProvider = selected;
      logEvent('provider-switch', `new rooms will use ${selected}`);
    }
    persistActiveProviders(selected, activeChatProvider);
    res.json({ ok: true, activeProvider });
  } catch (error) {
    if (sendProviderError(res, error) !== false) return;
    throw error;
  }
});

app.get('/api/overview', requireAdmin, (req, res) => {
  const allRooms = roomDirectory.entries();
  const standaloneChatRooms = chatRoomDirectory.list();
  const providerList = providerMetadataForDashboard();
  const chatProviderList = chatProviderRegistry.metadata();
  res.json({
    ok: true,
    connectionsEnabled: MEDIA_CONNECTIONS_ENABLED,
    providerSelectionEnabled: !IS_VERCEL,
    activeProvider,
    activeChatProvider,
    providers: Object.fromEntries(providerList.map((item) => [item.id, item])),
    providerList,
    chatProviders: Object.fromEntries(
      chatProviderList.map((item) => [item.id, item]),
    ),
    chatProviderList,
    controlRegion: CONTROL_REGION,
    mediaRegion: MEDIA_REGION,
    uptimeSec: Math.floor((Date.now() - STARTED_AT) / 1000),
    startedAt: new Date(STARTED_AT).toISOString(),
    roomCount: allRooms.length,
    attendeeCount: allRooms.reduce((count, entry) => count + entry.attendees.length, 0),
    standaloneChatRoomCount: standaloneChatRooms.length,
    standaloneChatAttendeeCount: standaloneChatRooms.reduce(
      (count, entry) => count + entry.attendees.length,
      0,
    ),
    standaloneChatRooms: standaloneChatRooms.map((entry) => ({
      roomCode: entry.roomCode,
      chatProvider: entry.chatProvider,
      context: 'standalone',
      createdAt: entry.createdAt,
      attendeeCount: entry.attendees.length,
    })),
    rooms: allRooms.map((entry) => summarizeRoom(entry, req)),
    events: events.slice(0, 100),
  });
});

app.get('/rooms', requireAdmin, (req, res) => {
  res.json({
    contractVersion: CONTRACT_VERSION,
    rooms: roomDirectory.entries().map((entry) => summarizeRoom(entry, req)),
  });
});

app.get('/rooms/discover', (req, res) => {
  const rooms = roomDirectory
    .entries()
    .filter((entry) => !isRoomPartiallyClosed(entry))
    .map((entry) => {
    const summary = summarizeRoom(entry, req);
    return {
      provider: summary.provider,
      ...(summary.chatProvider ? { chatProvider: summary.chatProvider } : {}),
      roomCode: summary.roomCode,
      roomMode: summary.roomMode ?? 'meeting',
      createdAt: summary.createdAt,
      attendeeCount: summary.attendeeCount,
    };
    });
  res.set('Cache-Control', 'no-store');
  res.json({ contractVersion: CONTRACT_VERSION, rooms });
});

app.post('/rooms', async (req, res) => {
  try {
    let roomCode = normalizeRoomCode(req.body?.roomCode);
    if (req.body?.roomCode && !roomCode) {
      return contractError(res, 400, 'bad-room-code', 'roomCode must be 4-12 letters/digits.');
    }
    if (roomCode && roomDirectory.has(roomCode)) {
      return contractError(res, 409, 'room-exists', 'The room code is already in use.');
    }
    roomCode ??= generateRoomCode();

    const requestedRole = req.body?.role == null ? null : parseRole(req.body.role);
    if (req.body?.role != null && !requestedRole) {
      return contractError(res, 400, 'invalid-argument', 'role must be participant, host, or viewer.');
    }
    const requestedRoomMode = parseRoomMode(req.body?.roomMode);
    if (req.body?.roomMode != null && !requestedRoomMode) {
      return contractError(res, 400, 'invalid-argument', 'roomMode must be meeting or broadcast.');
    }
    const roomMode: RoomMode =
      requestedRoomMode ?? (requestedRole === 'host' || requestedRole === 'viewer' ? 'broadcast' : 'meeting');
    const derivedCreatorRole = creatorRoleForMode(roomMode);
    if (requestedRoomMode && requestedRole && requestedRole !== derivedCreatorRole) {
      return contractError(
        res,
        400,
        'invalid-argument',
        `role is assigned by roomMode; ${roomMode} rooms are created as ${derivedCreatorRole}.`,
      );
    }
    const role = requestedRoomMode ? derivedCreatorRole : requestedRole ?? derivedCreatorRole;
    const deviceId = normalizeDeviceId(req.body?.deviceId);
    if (req.body?.deviceId != null && !deviceId) {
      return contractError(
        res,
        400,
        'invalid-argument',
        'deviceId must be 8-128 letters, digits, dots, underscores, colons, or hyphens.',
      );
    }

    const provider = engineProviderForSelection(activeProvider, roomMode);
    assertRole(provider, role);
    if (roomMode === 'broadcast') {
      assertRole(provider, 'viewer');
    }
    const rawNickname = req.body?.displayName?.trim() || req.body?.nickname?.trim() || null;
    const created = await provider.createRoom({ roomCode, role });
    created.entry.vendor = publicProviderId(provider.id);
    created.entry.engine = provider.id;
    created.response.vendor = publicProviderId(provider.id);
    created.response.engine = provider.id;
    const selectedChatProvider =
      activeProvider === AWS_VENDOR_ID && roomMode === 'broadcast'
        ? 'ivs-chat'
        : activeChatProvider;
    if (selectedChatProvider) {
      try {
        const chat = await chatProviderRegistry
          .requireConfigured(selectedChatProvider)
          .createRoom(roomCode);
        created.entry.chatProvider = chat.chatProvider;
        created.entry.chatRoomArn = chat.chatRoomArn;
        created.response.chatProvider = chat.chatProvider;
      } catch (error) {
        try {
          await provider.closeRoom({ entry: created.entry, reason: 'chat room create rollback' });
        } catch (cleanupError) {
          console.error('media rollback after chat create failure failed', cleanupError);
        }
        throw error;
      }
    }
    created.entry.roomMode = roomMode;
    created.response.roomMode = roomMode;
    // Room ownership is a logical SDK/control-plane role and is independent
    // from the provider media role. This lets meeting providers such as Chime
    // keep their native participant role while the creator can still manage
    // the logical room.
    const roomOwnerCredential = issueRoomOwnerCredential(created.entry);
    if (roomOwnerCredential) {
      created.response.roomOwnerCredential = roomOwnerCredential;
    }
    registerRoom(provider, created.entry);
    created.entry.lastHeartbeatMs = Date.now();
    logEvent('create', `room ${roomCode} created with ${provider.displayName}`);

    if (!rawNickname) return res.json(exposeVendorResponse(created.response));

    const userId = normalizeUserId(
      req.body?.userId ?? deviceId ?? rawNickname,
    );
    const response = await provider.joinRoom({
      entry: created.entry,
      rawName: rawNickname,
      role,
      userId,
      deviceId,
    });
    if (created.entry.chatProvider) response.chatProvider = created.entry.chatProvider;
    response.roomMode = roomMode;
    if (roomOwnerCredential) {
      response.roomOwnerCredential = roomOwnerCredential;
    }
    bindLogicalIdentity(
      created.entry,
      response.participantId,
      userId,
      rawNickname,
      deviceId,
      'host',
    );
    response.participantCredential = issueParticipantCredential(
      created.entry,
      response.participantId,
    );
    logEvent('join', `${response.displayName} created+joined room ${roomCode} via ${provider.displayName}`);
    res.json(exposeVendorResponse(response));
  } catch (error) {
    if (sendProviderError(res, error) !== false) return;
    console.error('create room failed', error);
    const name = error instanceof Error ? error.name : String(error);
    logEvent('error', `create room failed: ${name}`);
    contractError(res, 500, 'create-room-failed', 'Unable to create the room.');
  }
});

app.post('/rooms/:code/join', async (req, res) => {
  try {
    const entry = await resolveRoom(req.params.code);
    if (!entry) {
      logEvent('error', `join ${req.params.code} failed: not found`);
      return contractError(res, 404, 'room-not-found', 'The requested room was not found.');
    }
    if (isRoomPartiallyClosed(entry)) {
      return contractError(
        res,
        409,
        'room-closing',
        'The room is partially closed and is waiting for cleanup retry.',
      );
    }
    const provider = providerRegistry.requireConfigured(entry.provider);
    const deviceId = normalizeDeviceId(req.body?.deviceId);
    if (req.body?.deviceId != null && !deviceId) {
      return contractError(
        res,
        400,
        'invalid-argument',
        'deviceId must be 8-128 letters, digits, dots, underscores, colons, or hyphens.',
      );
    }
    const displayName = normalizeDisplayName(
      req.body?.displayName ?? req.body?.nickname ?? req.body?.userId,
    );
    if (!displayName) {
      return contractError(res, 400, 'invalid-argument', 'displayName or userId is required.');
    }
    const userId = normalizeUserId(req.body?.userId ?? deviceId ?? displayName);
    const requestedRole = req.body?.role == null ? null : parseRole(req.body.role);
    if (req.body?.role != null && !requestedRole) {
      return contractError(res, 400, 'invalid-argument', 'role must be participant, host, or viewer.');
    }
    const role = entry.roomMode
      ? joinRoleForRoom(entry, req.body?.roomOwnerCredential)
      : requestedRole ?? 'participant';
    assertRole(provider, role, entry);
    const response = await provider.joinRoom({
      entry,
      rawName: displayName,
      role,
      userId,
      deviceId,
    });
    if (entry.chatProvider) response.chatProvider = entry.chatProvider;
    if (entry.roomMode) response.roomMode = entry.roomMode;
    if (role === 'host') {
      response.roomOwnerCredential = String(
        req.body?.roomOwnerCredential ?? '',
      ).trim();
    }
    bindLogicalIdentity(
      entry,
      response.participantId,
      userId,
      displayName,
      deviceId,
      role,
    );
    response.participantCredential = issueParticipantCredential(
      entry,
      response.participantId,
    );
    logEvent('join', `${response.displayName} joined room ${entry.roomCode} via ${provider.displayName}`);
    res.json(exposeVendorResponse(response));
  } catch (error) {
    if (sendProviderError(res, error) !== false) return;
    console.error('room join failed', error);
    const name = error instanceof Error ? error.name : String(error);
    logEvent('error', `join room failed: ${name}`);
    contractError(res, 500, 'join-failed', 'Unable to join the room.');
  }
});

app.post('/rooms/:code/chat/token', async (req, res) => {
  try {
    const entry = await resolveRoom(req.params.code);
    if (!entry) {
      return contractError(res, 404, 'room-not-found', 'The requested room was not found.');
    }
    if (isRoomPartiallyClosed(entry)) {
      return contractError(
        res,
        409,
        'room-closing',
        'The room is partially closed and cannot issue chat credentials.',
      );
    }
    if (!entry.chatProvider || !entry.chatRoomArn) {
      return contractError(
        res,
        400,
        'unsupported-feature',
        'This room does not have a chat provider.',
      );
    }
    const participantId = String(req.body?.participantId ?? '').trim();
    if (!participantId) {
      return contractError(res, 400, 'invalid-argument', 'participantId is required.');
    }
    pruneStaleAttendees(entry, Date.now());
    const attendee = requireParticipantCredential(
      entry,
      participantId,
      req.body?.participantCredential,
    );
    const chatProvider = chatProviderRegistry.requireConfigured(entry.chatProvider);
    const response = await chatProvider.issueToken({ entry, attendee });
    res.json(response);
  } catch (error) {
    if (sendProviderError(res, error) !== false) return;
    console.error('chat token failed', error);
    contractError(res, 500, 'chat-token-failed', 'Unable to issue chat credentials.');
  }
});

app.post('/rooms/:code/credentials/refresh', async (req, res) => {
  try {
    const entry = await resolveRoom(req.params.code);
    if (!entry) return contractError(res, 404, 'room-not-found', 'The requested room was not found.');
    if (isRoomPartiallyClosed(entry)) {
      return contractError(
        res,
        409,
        'room-closing',
        'The room is partially closed and cannot refresh credentials.',
      );
    }
    const participantId = String(req.body?.participantId ?? '').trim();
    if (!participantId) {
      return contractError(res, 400, 'invalid-argument', 'participantId is required.');
    }
    pruneStaleAttendees(entry, Date.now());
    const attendee = requireParticipantCredential(
      entry,
      participantId,
      req.body?.participantCredential,
    );
    const role = attendee.role ?? 'participant';
    const requestedRole = req.body?.role == null ? null : parseRole(req.body.role);
    if (req.body?.role != null && requestedRole == null) {
      return contractError(res, 400, 'invalid-argument', 'role must be participant, host, or viewer.');
    }
    if (requestedRole != null && requestedRole !== role) {
      return contractError(
        res,
        403,
        'forbidden',
        'Credential refresh cannot change the participant role.',
      );
    }
    const provider = providerRegistry.requireConfigured(entry.provider);
    if (typeof provider.refreshCredentials !== 'function') {
      return contractError(
        res,
        400,
        'unsupported-provider',
        'Credential refresh is not supported by this room provider.',
      );
    }
    const response = await provider.refreshCredentials({ entry, participantId, role });
    res.json(exposeVendorResponse(response));
  } catch (error) {
    if (sendProviderError(res, error) !== false) return;
    console.error('credential refresh failed', error);
    contractError(res, 500, 'credential-refresh-failed', 'Unable to refresh provider credentials.');
  }
});

app.post('/rooms/:code/heartbeat', async (req, res) => {
  const entry = await resolveRoom(req.params.code);
  if (!entry) return contractError(res, 404, 'room-not-found', 'The requested room was not found.');
  const participantId = String(req.body?.participantId ?? '').trim();
  if (participantId) {
    const attendee = entry.attendees.find((item) => item.attendeeId === participantId);
    if (!attendee) {
      return contractError(
        res,
        404,
        'participant-not-found',
        'The participant is no longer registered in this room.',
      );
    }
    attendee.lastHeartbeatMs = Date.now();
  }
  entry.lastHeartbeatMs = Date.now();
  res.json({ contractVersion: CONTRACT_VERSION, ok: true, roomCode: entry.roomCode });
});

app.post('/rooms/:code/leave', async (req, res) => {
  try {
    const entry = await resolveRoom(req.params.code);
    if (!entry) return contractError(res, 404, 'room-not-found', 'The requested room was not found.');
    const provider = providerRegistry.require(entry.provider);
    const who = req.body?.participantId ?? req.body?.attendeeId ?? req.body?.userId ?? 'someone';
    const result = typeof provider.removeAttendee === 'function'
      ? provider.removeAttendee(entry, who)
      : { removed: false, closeWhenEmpty: false };
    if (result.closeWhenEmpty) {
      await closeRoom(entry, 'last attendee left');
      return res.json({ contractVersion: CONTRACT_VERSION, ok: true, roomCode: entry.roomCode, closed: true });
    }
    logEvent('leave', `${who} left room ${entry.roomCode} (auto-close in ~90s if empty)`);
    res.json({ contractVersion: CONTRACT_VERSION, ok: true, roomCode: entry.roomCode });
  } catch (error) {
    if (sendProviderError(res, error) !== false) return;
    console.error('leave failed', error);
    contractError(res, 500, 'leave-failed', 'Unable to leave the room.');
  }
});

function requireHostAttendee(
  entry: RoomEntry,
  requesterParticipantId: unknown,
  participantCredential: unknown,
): RoomAttendee | null {
  const requester = String(requesterParticipantId ?? '').trim();
  if (!requester) return null;
  try {
    const attendee = requireParticipantCredential(
      entry,
      requester,
      participantCredential,
    );
    return attendee.role === 'host' ? attendee : null;
  } catch (error) {
    if (
      error instanceof ProviderOperationError &&
      (error.status === 403 || error.status === 404)
    ) {
      return null;
    }
    throw error;
  }
}

app.post('/rooms/:code/participants', async (req, res) => {
  const entry = await resolveRoom(req.params.code);
  if (!entry) {
    return contractError(res, 404, 'room-not-found', 'The requested room was not found.');
  }
  if (!requireHostAttendee(
    entry,
    req.body?.requesterParticipantId,
    req.body?.participantCredential,
  )) {
    return contractError(res, 403, 'forbidden', 'Host permission is required.');
  }
  res.json({
    contractVersion: CONTRACT_VERSION,
    roomCode: entry.roomCode,
    participants: entry.attendees.map((attendee) => ({
      participantId: attendee.attendeeId,
      displayName: attendee.displayName ?? attendee.externalUserId,
      role: attendee.role ?? 'participant',
      joinedAt: attendee.joinedAt,
    })),
  });
});

app.post('/rooms/:code/participants/remove', async (req, res) => {
  try {
    const entry = await resolveRoom(req.params.code);
    if (!entry) {
      return contractError(res, 404, 'room-not-found', 'The requested room was not found.');
    }
    const host = requireHostAttendee(
      entry,
      req.body?.requesterParticipantId,
      req.body?.participantCredential,
    );
    if (!host) {
      return contractError(res, 403, 'forbidden', 'Host permission is required.');
    }
    const targetParticipantId = String(req.body?.targetParticipantId ?? '').trim();
    if (!targetParticipantId) {
      return contractError(res, 400, 'invalid-argument', 'targetParticipantId is required.');
    }
    if (host.attendeeId === targetParticipantId) {
      return contractError(res, 400, 'invalid-argument', 'Use leave or closeRoom for the host.');
    }
    const provider = providerRegistry.requireConfigured(entry.provider);
    if (typeof provider.moderateRemoveParticipant !== 'function') {
      return contractError(
        res,
        400,
        'unsupported-feature',
        'This provider does not support server-enforced participant removal.',
      );
    }
    const removed = await provider.moderateRemoveParticipant(entry, targetParticipantId);
    if (!removed) {
      return contractError(res, 404, 'participant-not-found', 'Participant was not found.');
    }
    logEvent('moderate', `${host.attendeeId} removed ${targetParticipantId} from room ${entry.roomCode}`);
    res.json({
      contractVersion: CONTRACT_VERSION,
      ok: true,
      roomCode: entry.roomCode,
      participantId: targetParticipantId,
    });
  } catch (error) {
    if (sendProviderError(res, error) !== false) return;
    console.error('participant removal failed', error);
    contractError(res, 500, 'moderation-failed', 'Unable to remove the participant.');
  }
});

app.post('/rooms/:code/close', async (req, res) => {
  try {
    const entry = await resolveRoom(req.params.code);
    if (!entry) {
      return contractError(res, 404, 'room-not-found', 'The requested room was not found.');
    }
    if (!requireHostAttendee(
      entry,
      req.body?.requesterParticipantId,
      req.body?.participantCredential,
    )) {
      return contractError(res, 403, 'forbidden', 'Host permission is required.');
    }
    await closeRoom(entry, 'host close');
    res.json({
      contractVersion: CONTRACT_VERSION,
      ok: true,
      closed: true,
      roomCode: entry.roomCode,
    });
  } catch (error) {
    if (sendProviderError(res, error) !== false) return;
    console.error('host room close failed', error);
    contractError(res, 500, 'close-failed', 'Unable to close the room.');
  }
});

app.delete('/rooms/:code', requireSameOrigin, requireAdmin, async (req, res) => {
  try {
    const entry = await resolveRoom(req.params.code);
    if (!entry) return contractError(res, 404, 'room-not-found', 'The requested room was not found.');
    await closeRoom(entry, 'force close');
    res.json({ contractVersion: CONTRACT_VERSION, deleted: true, roomCode: entry.roomCode });
  } catch (error) {
    if (sendProviderError(res, error) !== false) return;
    if (error instanceof Error && error.name === 'NotFoundException') {
      const stale = roomDirectory.get(req.params.code);
      if (stale) roomDirectory.remove(stale);
      return contractError(res, 404, 'room-not-found', 'The requested room was not found.');
    }
    console.error('room delete failed', error);
    contractError(res, 500, 'delete-failed', 'Unable to close the room.');
  }
});

// Legacy Chime endpoints remain available for compatibility, but AWS-specific
// SDK operations stay inside the Chime adapter.
app.post('/meetings', async (req, res) => {
  try {
    const created = await chimeProvider.createLegacyMeeting({
      roomCode: generateRoomCode(),
      externalMeetingId: req.body?.externalMeetingId ?? `demo-${Date.now()}`,
    });
    registerRoom(chimeProvider, created.entry);
    const chimeEntry = created.entry as ChimeRoomEntry;
    logEvent('create', `meeting ${chimeEntry.meeting.MeetingId.slice(0, 8)} created (room ${chimeEntry.roomCode})`);
    res.json({ meeting: chimeEntry.meeting, roomCode: chimeEntry.roomCode });
  } catch (error) {
    console.error('create meeting failed', error);
    res.status(500).json({ error: 'create-meeting-failed' });
  }
});

app.post('/meetings/:id/join', async (req, res) => {
  try {
    const entry = await resolveChimeRoom(req.params.id);
    if (!entry) return res.status(404).json({ error: 'meeting-not-found' });
    const response = await chimeProvider.joinLegacy(entry, req.body?.userId);
    logEvent('join', `${response.attendee.ExternalUserId} joined room ${entry.roomCode}`);
    res.json(response);
  } catch (error) {
    console.error('join failed', error);
    res.status(500).json({ error: 'join-failed' });
  }
});

app.post('/join', async (req, res) => {
  try {
    const ref = req.body?.meetingId?.trim();
    let entry = ref ? await resolveChimeRoom(ref) : null;
    if (!entry) {
      const created = await chimeProvider.createLegacyMeeting({
        roomCode: generateRoomCode(),
        externalMeetingId: `demo-${Date.now()}`,
      });
      entry = registerRoom(chimeProvider, created.entry);
      const chimeEntry = entry as ChimeRoomEntry;
      logEvent('create', `meeting ${chimeEntry.meeting.MeetingId.slice(0, 8)} created (room ${chimeEntry.roomCode}, via /join)`);
    }
    const response = await chimeProvider.joinLegacy(entry, req.body?.userId);
    logEvent('join', `${response.attendee.ExternalUserId} joined room ${entry.roomCode} (via /join)`);
    res.json(response);
  } catch (error) {
    console.error('join shortcut failed', error);
    res.status(500).json({ error: 'join-failed' });
  }
});

app.get('/meetings/:id', async (req, res) => {
  try {
    res.json({ meeting: await chimeProvider.getLegacyMeeting(req.params.id) });
  } catch (_) {
    res.status(404).json({ error: 'meeting-not-found' });
  }
});

app.delete('/meetings/:id', requireSameOrigin, requireAdmin, async (req, res) => {
  try {
    const meetingId = req.params.id;
    if (!meetingId) return res.status(404).json({ error: 'meeting-not-found' });
    await chimeProvider.deleteLegacyMeeting(meetingId);
    const entry = roomDirectory.get(meetingId);
    if (entry?.provider === 'chime') {
      roomDirectory.remove(entry);
      logEvent('delete', `room ${entry.roomCode} force-closed`);
    }
    res.json({ deleted: true });
  } catch (_) {
    res.status(404).json({ error: 'meeting-not-found' });
  }
});

let server: ReturnType<typeof app.listen> | null = null;
if (!IS_VERCEL) {
  const port = Number(process.env.PORT ?? 3000);
  server = app.listen(port, '0.0.0.0', () => {
    const address = server?.address();
    const listeningPort = address && typeof address === 'object' ? address.port : port;
    console.log(`media-demo-server on :${listeningPort} (control=${CONTROL_REGION} media=${MEDIA_REGION})`);
    console.log(`active provider: ${activeProvider}`);
    for (const provider of providerRegistry.metadata()) {
      console.log(`${provider.displayName} configured: ${provider.configured ? 'yes' : 'no'}`);
    }
    console.log(`connections enabled: ${MEDIA_CONNECTIONS_ENABLED ? 'yes' : 'no'}`);
    console.log(`dashboard: http://127.0.0.1:${listeningPort}/`);
  });
}

export { app, server, providerRegistry, roomDirectory };
export default app;
