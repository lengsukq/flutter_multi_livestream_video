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
import { ProviderOperationError, ProviderRegistry } from './providers/provider-registry.ts';
import { RoomDirectory } from './providers/room-directory.ts';
import { createTrtcProvider } from './providers/trtc.ts';
import type {
  ChimeRoomEntry,
  MediaRole,
  ProviderAdapter,
  RoomEntry,
  RoomSummary,
} from './types.ts';

const CONTROL_REGION = process.env.AWS_REGION ?? 'us-east-1';
const MEDIA_REGION = process.env.CHIME_MEDIA_REGION ?? 'ap-southeast-1';
const CONTRACT_VERSION = 1;
const MEDIA_CONTRACT_HEADER = 'X-Media-Backend-Contract';
const LEGACY_CHIME_CONTRACT_HEADER = 'X-Chime-Backend-Contract';
const DEMO_BEARER_TOKEN = process.env.DEMO_BEARER_TOKEN?.trim() || null;
const INITIAL_PROVIDER = String(process.env.MEDIA_DEFAULT_PROVIDER ?? 'chime').trim().toLowerCase();
const STARTED_AT = Date.now();
const EMPTY_CLOSE_AFTER_MS = Number(process.env.EMPTY_CLOSE_AFTER_MS ?? 90_000);
const SWEEP_INTERVAL_MS = 30_000;

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROVIDER_STATE_PATH = process.env.MEDIA_PROVIDER_STATE_PATH ?? path.join(__dirname, '.provider-state.json');

const app = express();
app.use(cors());
app.use(express.json({ limit: '64kb' }));

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

function parseRole(raw: unknown): MediaRole | null {
  const role = String(raw ?? 'participant').trim().toLowerCase();
  if (role === 'participant' || role === 'host' || role === 'viewer') return role;
  return null;
}

const chimeProvider = createChimeProvider({
  env: process.env,
  contractVersion: CONTRACT_VERSION,
  normalizeUserId,
});
const providerRegistry = new ProviderRegistry([
  chimeProvider,
  createLiveKitProvider({ env: process.env, contractVersion: CONTRACT_VERSION, normalizeDisplayName }),
  createAgoraProvider({ env: process.env, contractVersion: CONTRACT_VERSION, normalizeDisplayName }),
  createTrtcProvider({ env: process.env, contractVersion: CONTRACT_VERSION, normalizeDisplayName }),
  createArtcProvider({ env: process.env, contractVersion: CONTRACT_VERSION, normalizeDisplayName }),
]);
const roomDirectory = new RoomDirectory();
const events: Array<{ ts: string; type: string; message: string }> = [];

providerRegistry.require(INITIAL_PROVIDER);

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
  const requestedVersion = req.get(MEDIA_CONTRACT_HEADER) ?? req.get(LEGACY_CHIME_CONTRACT_HEADER);
  if (requestedVersion && requestedVersion !== String(CONTRACT_VERSION)) {
    return contractError(
      res,
      400,
      'unsupported-contract-version',
      `This demo server supports backend contract v${CONTRACT_VERSION}.`,
    );
  }
  if (DEMO_BEARER_TOKEN && req.get('Authorization') !== `Bearer ${DEMO_BEARER_TOKEN}`) {
    return contractError(res, 401, 'unauthorized', 'A valid demo bearer token is required.');
  }
  next();
}

app.use('/rooms', requireRoomContract);

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
  try {
    const parsed = JSON.parse(readFileSync(PROVIDER_STATE_PATH, 'utf8')) as {
      provider?: unknown;
    };
    const provider = providerRegistry.get(parsed?.provider);
    if (provider?.isConfigured()) return provider.id;
  } catch (_) {
    // Missing/corrupt runtime state falls back to MEDIA_DEFAULT_PROVIDER.
  }
  const initial = providerRegistry.require(INITIAL_PROVIDER);
  return initial.isConfigured() ? initial.id : 'chime';
}

function persistActiveProvider(provider: string): void {
  try {
    writeFileSync(
      PROVIDER_STATE_PATH,
      JSON.stringify({ provider, updatedAt: new Date().toISOString() }, null, 2) + '\n',
      'utf8',
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.warn(`Unable to persist media provider selection: ${message}`);
  }
}

let activeProvider = loadPersistedProvider();

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
  await provider.closeRoom({ entry, reason });
  roomDirectory.remove(entry);
  const suffix = entry.provider === 'chime' ? ' — billing for future joins stops' : '';
  logEvent('delete', `room ${entry.roomCode} closed (${reason})${suffix}`);
}

function summarizeRoom(entry: RoomEntry, req?: Request): RoomSummary {
  const provider = providerRegistry.require(entry.provider);
  const host = req ? `${req.protocol}://${req.get('host')}` : '';
  return provider.summarizeRoom(entry, { host });
}

setInterval(() => {
  const now = Date.now();
  for (const entry of roomDirectory.entries()) {
    if (now - (entry.lastHeartbeatMs ?? 0) <= EMPTY_CLOSE_AFTER_MS) continue;
    const idleSec = Math.round((now - entry.lastHeartbeatMs) / 1000);
    closeRoom(entry, `idle ${idleSec}s, no heartbeat`).catch((error) =>
      console.error('auto-close failed', entry.roomCode, error),
    );
  }
}, SWEEP_INTERVAL_MS);

app.get('/', (_req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.get('/health', (_req, res) => {
  const current = providerRegistry.require(activeProvider);
  const providerList = providerRegistry.metadata();
  res.json({
    ok: current.isConfigured(),
    contractVersion: CONTRACT_VERSION,
    activeProvider,
    controlRegion: CONTROL_REGION,
    mediaRegion: MEDIA_REGION,
    providers: Object.fromEntries(providerList.map((item) => [item.id, item])),
    providerList,
  });
});

app.post('/api/provider', (req, res) => {
  try {
    const provider = providerRegistry.requireConfigured(req.body?.provider);
    if (provider.id !== activeProvider) {
      activeProvider = provider.id;
      logEvent('provider-switch', `new rooms will use ${provider.id}`);
    }
    persistActiveProvider(provider.id);
    res.json({ ok: true, activeProvider });
  } catch (error) {
    if (sendProviderError(res, error) !== false) return;
    throw error;
  }
});

app.get('/api/overview', (req, res) => {
  const allRooms = roomDirectory.entries();
  const providerList = providerRegistry.metadata();
  res.json({
    ok: true,
    activeProvider,
    providers: Object.fromEntries(providerList.map((item) => [item.id, item])),
    providerList,
    controlRegion: CONTROL_REGION,
    mediaRegion: MEDIA_REGION,
    uptimeSec: Math.floor((Date.now() - STARTED_AT) / 1000),
    startedAt: new Date(STARTED_AT).toISOString(),
    roomCount: allRooms.length,
    attendeeCount: allRooms.reduce((count, entry) => count + entry.attendees.length, 0),
    rooms: allRooms.map((entry) => summarizeRoom(entry, req)),
    events: events.slice(0, 100),
  });
});

app.get('/rooms', (req, res) => {
  res.json({
    contractVersion: CONTRACT_VERSION,
    rooms: roomDirectory.entries().map((entry) => summarizeRoom(entry, req)),
  });
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

    const role = parseRole(req.body?.role);
    if (!role) {
      return contractError(res, 400, 'invalid-argument', 'role must be participant, host, or viewer.');
    }

    const provider = providerRegistry.requireConfigured(activeProvider);
    assertRole(provider, role);
    const created = await provider.createRoom({ roomCode, role });
    registerRoom(provider, created.entry);
    created.entry.lastHeartbeatMs = Date.now();
    logEvent('create', `room ${roomCode} created with ${provider.displayName}`);

    const rawNickname = req.body?.nickname?.trim() || null;
    if (!rawNickname) return res.json(created.response);

    const response = await provider.joinRoom({ entry: created.entry, rawName: rawNickname, role });
    logEvent('join', `${response.displayName} created+joined room ${roomCode} via ${provider.displayName}`);
    res.json(response);
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
    const role = parseRole(req.body?.role);
    if (!role) {
      return contractError(res, 400, 'invalid-argument', 'role must be participant, host, or viewer.');
    }
    const provider = providerRegistry.requireConfigured(entry.provider);
    assertRole(provider, role, entry);
    const response = await provider.joinRoom({ entry, rawName: req.body?.userId, role });
    logEvent('join', `${response.displayName} joined room ${entry.roomCode} via ${provider.displayName}`);
    res.json(response);
  } catch (error) {
    if (sendProviderError(res, error) !== false) return;
    console.error('room join failed', error);
    const name = error instanceof Error ? error.name : String(error);
    logEvent('error', `join room failed: ${name}`);
    contractError(res, 500, 'join-failed', 'Unable to join the room.');
  }
});

app.post('/rooms/:code/credentials/refresh', async (req, res) => {
  try {
    const entry = await resolveRoom(req.params.code);
    if (!entry) return contractError(res, 404, 'room-not-found', 'The requested room was not found.');
    const participantId = String(req.body?.participantId ?? '').trim();
    const role = parseRole(req.body?.role);
    if (!participantId || !role) {
      return contractError(res, 400, 'invalid-argument', 'participantId and a valid role are required.');
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
    res.json(response);
  } catch (error) {
    if (sendProviderError(res, error) !== false) return;
    console.error('credential refresh failed', error);
    contractError(res, 500, 'credential-refresh-failed', 'Unable to refresh provider credentials.');
  }
});

app.post('/rooms/:code/heartbeat', async (req, res) => {
  const entry = await resolveRoom(req.params.code);
  if (!entry) return contractError(res, 404, 'room-not-found', 'The requested room was not found.');
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

app.delete('/rooms/:code', async (req, res) => {
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

app.delete('/meetings/:id', async (req, res) => {
  try {
    await chimeProvider.deleteLegacyMeeting(req.params.id);
    const entry = roomDirectory.get(req.params.id);
    if (entry?.provider === 'chime') {
      roomDirectory.remove(entry);
      logEvent('delete', `room ${entry.roomCode} force-closed`);
    }
    res.json({ deleted: true });
  } catch (_) {
    res.status(404).json({ error: 'meeting-not-found' });
  }
});

const port = Number(process.env.PORT ?? 3000);
const server = app.listen(port, '0.0.0.0', () => {
  const address = server.address();
  const listeningPort = address && typeof address === 'object' ? address.port : port;
  console.log(`media-demo-server on :${listeningPort} (control=${CONTROL_REGION} media=${MEDIA_REGION})`);
  console.log(`active provider: ${activeProvider}`);
  for (const provider of providerRegistry.metadata()) {
    console.log(`${provider.displayName} configured: ${provider.configured ? 'yes' : 'no'}`);
  }
  console.log(`dashboard: http://127.0.0.1:${listeningPort}/`);
});

export { app, server, providerRegistry, roomDirectory };
