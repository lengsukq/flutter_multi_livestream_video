// Multi-provider demo backend — provider credentials stay server-side.
//
// `npm start` is the single backend entry point. The dashboard lets developers
// switch NEW rooms between AWS Chime, LiveKit, and Agora at runtime. Existing rooms
// remain bound to the provider that created them, so Flutter only needs a room
// code and never sends a provider selection.
//
// Room model (user-facing):
//   POST /rooms              { roomCode?, nickname?, role? } -> provider join info
//   POST /rooms/:code/join   { userId, role? }               -> provider join info
//   GET  /rooms                                       -> { rooms: [...] }
//   DELETE /rooms/:code                               -> { deleted: true } (force close)
//
// Legacy meeting endpoints (kept for compat, room-aware):
//   POST /meetings            { externalMeetingId? }  -> { meeting, roomCode }
//   POST /meetings/:id/join   { userId }              -> { roomCode, meeting, attendee }
//   POST /join                { meetingId?, userId }  -> { roomCode, meeting, attendee }
//   GET  /meetings/:id        -> { meeting }
//   DELETE /meetings/:id      -> { deleted: true }
//
// Monitor:
//   GET  /                    -> dashboard (provider switch, rooms, force close)
//   GET  /health              -> provider/backend status
//   GET  /api/overview        -> dashboard data
//   POST /api/provider        -> switch provider for newly-created rooms
//
// Response shape matches JoinInfo.fromJson: { meeting: {...}, attendee: {...} }

import crypto from 'node:crypto';
import express from 'express';
import cors from 'cors';
import { readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildAgoraRtcToken } from './agora-token.mjs';
import {
  ChimeSDKMeetingsClient,
  CreateMeetingCommand,
  CreateAttendeeCommand,
  GetMeetingCommand,
  DeleteMeetingCommand,
} from '@aws-sdk/client-chime-sdk-meetings';

const CONTROL_REGION = process.env.AWS_REGION ?? 'us-east-1';
const MEDIA_REGION = process.env.CHIME_MEDIA_REGION ?? 'ap-southeast-1';
const CONTRACT_VERSION = 1;
const MEDIA_CONTRACT_HEADER = 'X-Media-Backend-Contract';
const LEGACY_CHIME_CONTRACT_HEADER = 'X-Chime-Backend-Contract';
const DEMO_BEARER_TOKEN = process.env.DEMO_BEARER_TOKEN?.trim() || null;
const LIVEKIT_URL = process.env.LIVEKIT_URL?.trim() || null;
const LIVEKIT_API_KEY = process.env.LIVEKIT_API_KEY?.trim() || null;
const LIVEKIT_API_SECRET = process.env.LIVEKIT_API_SECRET?.trim() || null;
const LIVEKIT_TOKEN_TTL_SECONDS = Number(process.env.LIVEKIT_TOKEN_TTL_SECONDS ?? 600);
const AGORA_APP_ID = process.env.AGORA_APP_ID?.trim() || null;
const AGORA_APP_CERTIFICATE = process.env.AGORA_APP_CERTIFICATE?.trim() || null;
const AGORA_TOKEN_TTL_SECONDS = Number(process.env.AGORA_TOKEN_TTL_SECONDS ?? 600);
const INITIAL_PROVIDER = String(process.env.MEDIA_DEFAULT_PROVIDER ?? 'chime').trim().toLowerCase();
const STARTED_AT = Date.now();
// Empty-room auto close: sweep every 30s, close rooms with no heartbeat for 90s.
// Heartbeat comes from the app (see POST /rooms/:code/heartbeat).
const EMPTY_CLOSE_AFTER_MS = Number(process.env.EMPTY_CLOSE_AFTER_MS ?? 90_000);
const SWEEP_INTERVAL_MS = 30_000;

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROVIDER_STATE_PATH = path.join(__dirname, '.provider-state.json');

const client = new ChimeSDKMeetingsClient({ region: CONTROL_REGION });
const app = express();
app.use(cors());
app.use(express.json({ limit: '64kb' }));

if (!['chime', 'livekit', 'agora'].includes(INITIAL_PROVIDER)) {
  throw new Error('MEDIA_DEFAULT_PROVIDER must be chime, livekit, or agora.');
}

async function resolveRoom(ref) {
  const key = String(ref ?? '').trim();
  if (!key) return null;
  const agora = agoraRooms.get(key);
  if (agora) return agora;
  const livekit = livekitRooms.get(key);
  if (livekit) return livekit;
  return resolveEntry(key);
}

function closeLiveKitEntry(entry, reason) {
  livekitRooms.delete(entry.roomCode);
  logEvent('delete', `room ${entry.roomCode} closed (${reason}) — LiveKit directory entry removed`);
}

function closeAgoraEntry(entry, reason) {
  agoraRooms.delete(entry.roomCode);
  logEvent('delete', `room ${entry.roomCode} closed (${reason}) — Agora directory entry removed`);
}

function contractError(res, status, code, message, details = undefined) {
  return res.status(status).json({
    contractVersion: CONTRACT_VERSION,
    error: { code, message, ...(details === undefined ? {} : { details }) },
  });
}

function requireRoomContract(req, res, next) {
  res.set(MEDIA_CONTRACT_HEADER, String(CONTRACT_VERSION));
  const requestedVersion =
    req.get(MEDIA_CONTRACT_HEADER) ?? req.get(LEGACY_CHIME_CONTRACT_HEADER);
  if (requestedVersion && requestedVersion !== String(CONTRACT_VERSION)) {
    return contractError(
      res,
      400,
      'unsupported-contract-version',
      `This demo server supports backend contract v${CONTRACT_VERSION}.`,
    );
  }
  if (DEMO_BEARER_TOKEN) {
    const expected = `Bearer ${DEMO_BEARER_TOKEN}`;
    if (req.get('Authorization') !== expected) {
      return contractError(res, 401, 'unauthorized', 'A valid demo bearer token is required.');
    }
  }
  next();
}

app.use('/rooms', requireRoomContract);

// ---- in-memory state (restart clears the room directory) ----
// Chime keeps the legacy meetingId index for backwards-compatible endpoints.
// LiveKit rooms are application-level entries; LiveKit creates the actual room
// lazily when the first signed participant token connects.
const meetings = new Map();
const rooms = new Map();
const livekitRooms = new Map();
const agoraRooms = new Map();
const events = [];
function logEvent(type, message) {
  events.unshift({ ts: new Date().toISOString(), type, message });
  if (events.length > 200) events.pop();
  console.log(`[${type}] ${message}`);
}

function pickMeeting(raw) {
  return {
    MeetingId: raw.MeetingId,
    ExternalMeetingId: raw.ExternalMeetingId,
    MediaRegion: raw.MediaRegion,
    MediaPlacement: raw.MediaPlacement,
    MeetingArn: raw.MeetingArn,
    TenantIds: raw.TenantIds ?? [],
  };
}

function pickAttendee(raw) {
  return {
    AttendeeId: raw.AttendeeId,
    ExternalUserId: raw.ExternalUserId,
    JoinToken: raw.JoinToken,
    Capabilities: raw.Capabilities,
  };
}

function generateRoomCode() {
  for (let i = 0; i < 50; i++) {
    const code = String(Math.floor(100000 + Math.random() * 900000));
    if (!rooms.has(code) && !livekitRooms.has(code) && !agoraRooms.has(code)) return code;
  }
  return String(Date.now()).slice(-6);
}

function normalizeRoomCode(raw) {
  if (raw == null) return null;
  const code = String(raw).trim();
  if (!/^[A-Za-z0-9]{4,12}$/.test(code)) return null;
  return code;
}

function normalizeUserId(raw) {
  const id = String(raw ?? '').trim() || `user-${crypto.randomUUID().slice(0, 8)}`;
  // Chime ExternalUserId pattern: ^[-_&@+=,(){}\[\]\/«.:\s'"#a-zA-Z0-9À-ÿ]*$ — no CJK.
  // Sanitize CJK/emoji nicknames to keep them usable while staying valid.
  if (/^[-_&@+=,(){}\[\]\/«.:\s'"#a-zA-Z0-9À-ÿ]*$/.test(id) && id.length <= 64) return id;
  const ascii = id.replace(/[^\x20-\x7E]/g, '').replace(/[^A-Za-z0-9\-_=@,. ]/g, '').trim().slice(0, 48);
  return ascii || `user-${crypto.randomUUID().slice(0, 8)}`;
}

function normalizeDisplayName(raw) {
  return String(raw ?? '').trim().slice(0, 64);
}

function parseRole(raw) {
  const role = String(raw ?? 'participant').trim().toLowerCase();
  return ['participant', 'host', 'viewer'].includes(role) ? role : null;
}

function liveKitConfigured() {
  return Boolean(LIVEKIT_URL && LIVEKIT_API_KEY && LIVEKIT_API_SECRET);
}

function base64Url(value) {
  return Buffer.from(value).toString('base64url');
}

function signLiveKitToken({ identity, name, roomName, role }) {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'HS256', typ: 'JWT' };
  const payload = {
    iss: LIVEKIT_API_KEY,
    sub: identity,
    nbf: now - 5,
    exp: now + LIVEKIT_TOKEN_TTL_SECONDS,
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
  const signature = crypto
    .createHmac('sha256', LIVEKIT_API_SECRET)
    .update(unsigned)
    .digest('base64url');
  return `${unsigned}.${signature}`;
}

function createLiveKitEntry(roomCode) {
  const entry = {
    provider: 'livekit',
    roomCode,
    providerRoomName: `media-${roomCode}`,
    createdAt: new Date().toISOString(),
    attendees: [],
    lastHeartbeatMs: Date.now(),
  };
  livekitRooms.set(roomCode, entry);
  return entry;
}

function createLiveKitJoin(entry, rawName, role) {
  const identity = `p-${crypto.randomUUID()}`;
  const displayName = normalizeDisplayName(rawName) || identity;
  entry.attendees.push({
    attendeeId: identity,
    externalUserId: displayName,
    joinedAt: new Date().toISOString(),
  });
  touchHeartbeat(entry);
  return {
    contractVersion: CONTRACT_VERSION,
    provider: 'livekit',
    role,
    roomCode: entry.roomCode,
    participantId: identity,
    displayName,
    livekit: {
      url: LIVEKIT_URL,
      token: signLiveKitToken({
        identity,
        name: displayName,
        roomName: entry.providerRoomName,
        role,
      }),
      identity,
    },
  };
}

function agoraConfigured() {
  return Boolean(AGORA_APP_ID && AGORA_APP_CERTIFICATE);
}

function providerConfigured(provider) {
  if (provider === 'chime') return true;
  if (provider === 'livekit') return liveKitConfigured();
  if (provider === 'agora') return agoraConfigured();
  return false;
}

function loadPersistedProvider() {
  try {
    const parsed = JSON.parse(readFileSync(PROVIDER_STATE_PATH, 'utf8'));
    const provider = String(parsed?.provider ?? '').trim().toLowerCase();
    if (['chime', 'livekit', 'agora'].includes(provider) && providerConfigured(provider)) {
      return provider;
    }
  } catch (_) {
    // Missing/corrupt runtime state falls back to MEDIA_DEFAULT_PROVIDER.
  }
  return providerConfigured(INITIAL_PROVIDER) ? INITIAL_PROVIDER : 'chime';
}

function persistActiveProvider(provider) {
  try {
    writeFileSync(
      PROVIDER_STATE_PATH,
      JSON.stringify({ provider, updatedAt: new Date().toISOString() }, null, 2) + '\n',
      'utf8',
    );
  } catch (error) {
    console.warn(`Unable to persist media provider selection: ${error?.message ?? error}`);
  }
}

let activeProvider = loadPersistedProvider();

function createAgoraEntry(roomCode) {
  const entry = {
    provider: 'agora',
    roomCode,
    providerRoomName: 'media-' + roomCode,
    createdAt: new Date().toISOString(),
    attendees: [],
    lastHeartbeatMs: Date.now(),
  };
  agoraRooms.set(roomCode, entry);
  return entry;
}

function generateAgoraUid(entry) {
  for (let i = 0; i < 50; i++) {
    // Agora AccessToken2 documents integer UIDs as signed 32-bit values.
    // Keep generated UIDs in 1..2^31-1 so the token and native SDK agree
    // across Node, Dart, iOS, and Android.
    const uid = crypto.randomInt(1, 0x80000000);
    if (!entry.attendees.some((item) => item.attendeeId === String(uid))) return uid;
  }
  throw new Error('Unable to allocate a unique Agora uid.');
}

function signAgoraToken({ channelName, uid, role }) {
  return buildAgoraRtcToken({
    appId: AGORA_APP_ID,
    appCertificate: AGORA_APP_CERTIFICATE,
    channelName,
    uid,
    role,
    ttlSeconds: AGORA_TOKEN_TTL_SECONDS,
  });
}

function createAgoraJoin(entry, rawName, role) {
  const uid = generateAgoraUid(entry);
  const displayName = normalizeDisplayName(rawName) || String(uid);
  entry.attendees.push({
    attendeeId: String(uid),
    externalUserId: displayName,
    joinedAt: new Date().toISOString(),
  });
  touchHeartbeat(entry);
  return {
    contractVersion: CONTRACT_VERSION,
    provider: 'agora',
    role,
    roomCode: entry.roomCode,
    participantId: String(uid),
    displayName,
    agora: {
      appId: AGORA_APP_ID,
      channelName: entry.providerRoomName,
      token: signAgoraToken({ channelName: entry.providerRoomName, uid, role }),
      uid,
    },
  };
}

function getOrCacheEntry(meeting, roomCode = null) {
  let entry = meetings.get(meeting.MeetingId);
  if (!entry) {
    const code = roomCode ?? generateRoomCode();
    entry = {
      provider: 'chime',
      meeting,
      roomCode: code,
      createdAt: new Date().toISOString(),
      attendees: [],
      // lastHeartbeatMs: last proof anyone is still inside (join or heartbeat).
      // Empty rooms (no heartbeat within EMPTY_CLOSE_AFTER_MS) get auto-closed.
      lastHeartbeatMs: Date.now(),
    };
    meetings.set(meeting.MeetingId, entry);
    rooms.set(code, meeting.MeetingId);
  } else {
    entry.meeting = meeting;
    if (roomCode && entry.roomCode !== roomCode) {
      rooms.delete(entry.roomCode);
      entry.roomCode = roomCode;
      rooms.set(roomCode, meeting.MeetingId);
    }
    if (!rooms.has(entry.roomCode)) rooms.set(entry.roomCode, meeting.MeetingId);
  }
  return entry;
}

function touchHeartbeat(entry) {
  entry.lastHeartbeatMs = Date.now();
}

async function closeEntry(entry, reason) {
  try {
    await client.send(new DeleteMeetingCommand({ MeetingId: entry.meeting.MeetingId }));
  } catch (err) {
    if (err?.name !== 'NotFoundException') throw err;
  }
  rooms.delete(entry.roomCode);
  meetings.delete(entry.meeting.MeetingId);
  logEvent('delete', `room ${entry.roomCode} closed (${reason}) — billing for future joins stops`);
}

// Periodic sweep: nobody inside -> close it so it doesn't linger/bill.
setInterval(() => {
  const now = Date.now();
  for (const entry of [...meetings.values()]) {
    if (now - (entry.lastHeartbeatMs ?? 0) > EMPTY_CLOSE_AFTER_MS) {
      const idleSec = Math.round((now - entry.lastHeartbeatMs) / 1000);
      closeEntry(entry, `idle ${idleSec}s, no heartbeat`).catch((err) =>
        console.error('auto-close failed', entry.roomCode, err),
      );
    }
  }
  for (const entry of [...livekitRooms.values()]) {
    if (now - (entry.lastHeartbeatMs ?? 0) > EMPTY_CLOSE_AFTER_MS) {
      const idleSec = Math.round((now - entry.lastHeartbeatMs) / 1000);
      closeLiveKitEntry(entry, `idle ${idleSec}s, no heartbeat`);
    }
  }
  for (const entry of [...agoraRooms.values()]) {
    if (now - (entry.lastHeartbeatMs ?? 0) > EMPTY_CLOSE_AFTER_MS) {
      const idleSec = Math.round((now - entry.lastHeartbeatMs) / 1000);
      closeAgoraEntry(entry, `idle ${idleSec}s, no heartbeat`);
    }
  }
}, SWEEP_INTERVAL_MS);

/// Accepts a room code ("123456") or a raw meetingId (uuid). Returns the entry or null.
async function resolveEntry(ref) {
  const key = String(ref ?? '').trim();
  if (!key) return null;
  if (rooms.has(key)) {
    const id = rooms.get(key);
    const entry = meetings.get(id);
    if (entry) return entry;
    rooms.delete(key);
  }
  // Fall back: treat as a Chime meetingId, fetch from AWS and cache.
  try {
    const got = await client.send(new GetMeetingCommand({ MeetingId: key }));
    return getOrCacheEntry(pickMeeting(got.Meeting));
  } catch {
    return null;
  }
}

async function createAttendeeIn(entry, userId) {
  const created = await client.send(
    new CreateAttendeeCommand({ MeetingId: entry.meeting.MeetingId, ExternalUserId: userId }),
  );
  const attendee = pickAttendee(created.Attendee);
  entry.attendees.push({
    attendeeId: attendee.AttendeeId,
    externalUserId: attendee.ExternalUserId,
    joinedAt: new Date().toISOString(),
  });
  return attendee;
}

function chimeJoinResponse(entry, attendee, role = 'participant') {
  return {
    contractVersion: CONTRACT_VERSION,
    provider: 'chime',
    role,
    roomCode: entry.roomCode,
    participantId: attendee.AttendeeId,
    displayName: attendee.ExternalUserId,
    meeting: entry.meeting,
    attendee,
  };
}

function roomSummary(entry, req) {
  const host = req ? `${req.protocol}://${req.get('host')}` : '';
  if (entry.provider === 'agora') {
    return {
      provider: 'agora',
      roomCode: entry.roomCode,
      meetingId: entry.providerRoomName,
      externalMeetingId: entry.providerRoomName,
      mediaRegion: 'Agora',
      createdAt: entry.createdAt,
      lastHeartbeat: new Date(entry.lastHeartbeatMs ?? Date.now()).toISOString(),
      idleSec: Math.max(0, Math.round((Date.now() - (entry.lastHeartbeatMs ?? Date.now())) / 1000)),
      attendeeCount: entry.attendees.length,
      attendees: entry.attendees,
      shareText: entry.roomCode,
      shareLink: `multimedia://join?roomCode=${entry.roomCode}&server=${host}`,
    };
  }
  if (entry.provider === 'livekit') {
    return {
      provider: 'livekit',
      roomCode: entry.roomCode,
      meetingId: entry.providerRoomName,
      externalMeetingId: entry.providerRoomName,
      mediaRegion: 'LiveKit',
      createdAt: entry.createdAt,
      lastHeartbeat: new Date(entry.lastHeartbeatMs ?? Date.now()).toISOString(),
      idleSec: Math.max(0, Math.round((Date.now() - (entry.lastHeartbeatMs ?? Date.now())) / 1000)),
      attendeeCount: entry.attendees.length,
      attendees: entry.attendees,
      shareText: entry.roomCode,
      shareLink: `multimedia://join?roomCode=${entry.roomCode}&server=${host}`,
    };
  }
  return {
    provider: 'chime',
    roomCode: entry.roomCode,
    meetingId: entry.meeting.MeetingId,
    externalMeetingId: entry.meeting.ExternalMeetingId,
    mediaRegion: entry.meeting.MediaRegion,
    createdAt: entry.createdAt,
    lastHeartbeat: new Date(entry.lastHeartbeatMs ?? Date.now()).toISOString(),
    idleSec: Math.max(0, Math.round((Date.now() - (entry.lastHeartbeatMs ?? Date.now())) / 1000)),
    attendeeCount: entry.attendees.length,
    attendees: entry.attendees,
    shareText: entry.roomCode,
    shareLink: `chimedemo://join?meetingId=${entry.roomCode}&server=${host}`,
  };
}

// ---- human dashboard ----
app.get('/', (_req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.get('/health', (_req, res) => {
  res.json({
    ok:
      activeProvider === 'livekit'
        ? liveKitConfigured()
        : activeProvider === 'agora'
          ? agoraConfigured()
          : true,
    contractVersion: CONTRACT_VERSION,
    activeProvider,
    controlRegion: CONTROL_REGION,
    mediaRegion: MEDIA_REGION,
    providers: {
      chime: { enabled: true, configured: true },
      livekit: { enabled: true, configured: liveKitConfigured(), url: LIVEKIT_URL },
      agora: { enabled: true, configured: agoraConfigured() },
    },
  });
});

app.post('/api/provider', (req, res) => {
  const provider = String(req.body?.provider ?? '').trim().toLowerCase();
  if (!['chime', 'livekit', 'agora'].includes(provider)) {
    return contractError(
      res,
      400,
      'unsupported-provider',
      'provider must be chime, livekit, or agora.',
    );
  }
  if (provider === 'livekit' && !liveKitConfigured()) {
    return contractError(
      res,
      503,
      'provider-not-configured',
      'LiveKit is not configured. Set LIVEKIT_URL, LIVEKIT_API_KEY, and LIVEKIT_API_SECRET.',
    );
  }
  if (provider === 'agora' && !agoraConfigured()) {
    return contractError(
      res,
      503,
      'provider-not-configured',
      'Agora is not configured. Set AGORA_APP_ID and AGORA_APP_CERTIFICATE.',
    );
  }
  if (provider === activeProvider) {
    persistActiveProvider(provider);
    return res.json({ ok: true, activeProvider });
  }
  activeProvider = provider;
  persistActiveProvider(provider);
  logEvent('provider-switch', `new rooms will use ${provider}`);
  res.json({ ok: true, activeProvider });
});

app.get('/api/overview', (req, res) => {
  const allRooms = [...meetings.values(), ...livekitRooms.values(), ...agoraRooms.values()];
  res.json({
    ok: true,
    activeProvider,
    providers: {
      chime: { enabled: true, configured: true },
      livekit: { enabled: true, configured: liveKitConfigured(), url: LIVEKIT_URL },
      agora: { enabled: true, configured: agoraConfigured() },
    },
    controlRegion: CONTROL_REGION,
    mediaRegion: MEDIA_REGION,
    uptimeSec: Math.floor((Date.now() - STARTED_AT) / 1000),
    startedAt: new Date(STARTED_AT).toISOString(),
    roomCount: allRooms.length,
    attendeeCount: allRooms.reduce((n, e) => n + e.attendees.length, 0),
    rooms: allRooms.map((e) => roomSummary(e, req)),
    events: events.slice(0, 100),
  });
});

app.get('/rooms', (req, res) => {
  res.json({
    contractVersion: CONTRACT_VERSION,
    rooms: [...meetings.values(), ...livekitRooms.values(), ...agoraRooms.values()].map((e) =>
      roomSummary(e, req),
    ),
  });
});

// ---- room API (primary for the app) ----

// Create a room. Body: { roomCode?, nickname?, role? }.
// The server-side activeProvider decides which media backend owns the room.
app.post('/rooms', async (req, res) => {
  try {
    let code = normalizeRoomCode(req.body?.roomCode);
    if (req.body?.roomCode && !code) {
      return contractError(
        res,
        400,
        'bad-room-code',
        'roomCode must be 4-12 letters/digits.',
      );
    }
    if (code && (rooms.has(code) || livekitRooms.has(code) || agoraRooms.has(code))) {
      return contractError(
        res,
        409,
        'room-exists',
        'The room code is already in use.',
      );
    }
    code ??= generateRoomCode();
    const role = parseRole(req.body?.role);
    if (!role) {
      return contractError(res, 400, 'invalid-argument', 'role must be participant, host, or viewer.');
    }
    const rawNickname = req.body?.nickname?.trim() || null;
    if (activeProvider === 'agora') {
      if (!agoraConfigured()) {
        return contractError(
          res,
          503,
          'provider-not-configured',
          'Agora is not configured on this demo server.',
        );
      }
      const entry = createAgoraEntry(code);
      logEvent('create', `room ${code} created with Agora`);
      if (rawNickname) {
        const response = createAgoraJoin(entry, rawNickname, role);
        logEvent('join', `${response.displayName} created+joined room ${code} via Agora`);
        return res.json(response);
      }
      return res.json({
        contractVersion: CONTRACT_VERSION,
        provider: 'agora',
        role,
        roomCode: code,
      });
    }
    if (activeProvider === 'livekit') {
      if (!liveKitConfigured()) {
        return contractError(
          res,
          503,
          'provider-not-configured',
          'LiveKit is not configured on this demo server.',
        );
      }
      const entry = createLiveKitEntry(code);
      logEvent('create', `room ${code} created with LiveKit`);
      if (rawNickname) {
        const response = createLiveKitJoin(entry, rawNickname, role);
        logEvent('join', `${response.displayName} created+joined room ${code} via LiveKit`);
        return res.json(response);
      }
      return res.json({
        contractVersion: CONTRACT_VERSION,
        provider: 'livekit',
        role,
        roomCode: code,
      });
    }

    if (role !== 'participant') {
      return contractError(
        res,
        400,
        'unsupported-role',
        'AWS Chime currently supports participant rooms only. Switch the server UI to LiveKit for host/viewer roles.',
      );
    }
    const nickname = rawNickname ? normalizeUserId(rawNickname) : null;

    const out = await client.send(
      new CreateMeetingCommand({
        ClientRequestToken: crypto.randomUUID(),
        MediaRegion: MEDIA_REGION,
        ExternalMeetingId: `room-${code}`,
      }),
    );
    const entry = getOrCacheEntry(pickMeeting(out.Meeting), code);
    touchHeartbeat(entry);
    logEvent('create', `room ${code} created (meeting ${entry.meeting.MeetingId.slice(0, 8)})`);

    if (nickname) {
      const attendee = await createAttendeeIn(entry, nickname);
      logEvent('join', `${nickname} created+joined room ${code}`);
      return res.json(chimeJoinResponse(entry, attendee, role));
    }
    res.json({
      contractVersion: CONTRACT_VERSION,
      provider: 'chime',
      role,
      roomCode: code,
      meeting: entry.meeting,
    });
  } catch (err) {
    console.error('create room failed', err);
    logEvent('error', `create room failed: ${err?.name ?? err}`);
    contractError(res, 500, 'create-room-failed', 'Unable to create the room.');
  }
});

// Join a room by code. Body: { userId, role? }. Provider comes from the room.
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
    if (entry.provider === 'agora') {
      if (!agoraConfigured()) {
        return contractError(res, 503, 'provider-not-configured', 'Agora is not configured.');
      }
      const response = createAgoraJoin(entry, req.body?.userId, role);
      logEvent('join', `${response.displayName} joined room ${entry.roomCode} via Agora`);
      return res.json(response);
    }
    if (entry.provider === 'livekit') {
      if (!liveKitConfigured()) {
        return contractError(res, 503, 'provider-not-configured', 'LiveKit is not configured.');
      }
      const response = createLiveKitJoin(entry, req.body?.userId, role);
      logEvent('join', `${response.displayName} joined room ${entry.roomCode} via LiveKit`);
      return res.json(response);
    }
    if (role !== 'participant') {
      return contractError(
        res,
        400,
        'unsupported-role',
        'This room uses AWS Chime, which currently supports participant role only.',
      );
    }
    const userId = req.body?.userId;
    const safeId = normalizeUserId(userId);
    const attendee = await createAttendeeIn(entry, safeId);
    touchHeartbeat(entry);
    logEvent('join', `${safeId} joined room ${entry.roomCode}`);
    res.json(chimeJoinResponse(entry, attendee, role));
  } catch (err) {
    console.error('room join failed', err);
    logEvent('error', `join room failed: ${err?.name ?? err}`);
    contractError(res, 500, 'join-failed', 'Unable to join the room.');
  }
});

// Proof-of-life from inside a room. Body: { attendeeId? }.
// Any active client calls this every ~30s; rooms without it get auto-closed.
app.post('/rooms/:code/heartbeat', async (req, res) => {
  const entry = await resolveRoom(req.params.code);
  if (!entry) return contractError(res, 404, 'room-not-found', 'The requested room was not found.');
  touchHeartbeat(entry);
  res.json({ contractVersion: CONTRACT_VERSION, ok: true, roomCode: entry.roomCode });
});

// Explicit leave notice from the app (best-effort; auto-close covers kills).
// Body: { attendeeId? }. Room closes immediately when the last known
// attendee leaves AND no heartbeat arrives — here we just log it and let
// the sweep handle the close to avoid kicking a second viewer.
app.post('/rooms/:code/leave', async (req, res) => {
  const entry = await resolveRoom(req.params.code);
  if (!entry) return contractError(res, 404, 'room-not-found', 'The requested room was not found.');
  const who = req.body?.attendeeId ?? req.body?.userId ?? 'someone';
  if (entry.provider === 'agora' && Array.isArray(entry.attendees)) {
    entry.attendees = entry.attendees.filter(
      (attendee) =>
        attendee.attendeeId !== String(who) &&
        attendee.externalUserId !== String(who),
    );
    if (entry.attendees.length === 0) {
      closeAgoraEntry(entry, 'last attendee left');
      return res.json({
        contractVersion: CONTRACT_VERSION,
        ok: true,
        roomCode: entry.roomCode,
        closed: true,
      });
    }
  }
  logEvent('leave', `${who} left room ${entry.roomCode} (auto-close in ~90s if empty)`);
  res.json({ contractVersion: CONTRACT_VERSION, ok: true, roomCode: entry.roomCode });
});

// Force close a room. Existing room/provider ownership determines cleanup.
app.delete('/rooms/:code', async (req, res) => {
  try {
    const key = String(req.params.code ?? '').trim();
    const agora = agoraRooms.get(key);
    if (agora) {
      closeAgoraEntry(agora, 'force close');
      return res.json({
        contractVersion: CONTRACT_VERSION,
        deleted: true,
        roomCode: key,
      });
    }
    const livekit = livekitRooms.get(key);
    if (livekit) {
      closeLiveKitEntry(livekit, 'force close');
      return res.json({
        contractVersion: CONTRACT_VERSION,
        deleted: true,
        roomCode: key,
      });
    }
    const entry = await resolveEntry(key);
    if (!entry) {
      return contractError(res, 404, 'room-not-found', 'The requested room was not found.');
    }
    await closeEntry(entry, 'force close');
    res.json({
      contractVersion: CONTRACT_VERSION,
      deleted: true,
      roomCode: entry.roomCode,
    });
  } catch (err) {
    const notFound = err?.name === 'NotFoundException';
    if (notFound) {
      const key = String(req.params.code ?? '').trim();
      const id = rooms.get(key);
      if (id) {
        rooms.delete(key);
        meetings.delete(id);
      }
      return contractError(res, 404, 'room-not-found', 'The requested room was not found.');
    }
    console.error('room delete failed', err);
    contractError(res, 500, 'delete-failed', 'Unable to close the room.');
  }
});

// ---- legacy meeting endpoints (room-aware) ----

app.post('/meetings', async (req, res) => {
  try {
    const externalMeetingId = req.body?.externalMeetingId ?? `demo-${Date.now()}`;
    const out = await client.send(
      new CreateMeetingCommand({
        ClientRequestToken: crypto.randomUUID(),
        MediaRegion: MEDIA_REGION,
        ExternalMeetingId: externalMeetingId,
      }),
    );
    const entry = getOrCacheEntry(pickMeeting(out.Meeting));
    logEvent('create', `meeting ${entry.meeting.MeetingId.slice(0, 8)} created (room ${entry.roomCode})`);
    res.json({ meeting: entry.meeting, roomCode: entry.roomCode });
  } catch (err) {
    console.error('create meeting failed', err);
    res.status(500).json({ error: 'create-meeting-failed' });
  }
});

app.post('/meetings/:id/join', async (req, res) => {
  try {
    const entry = await resolveEntry(req.params.id);
    if (!entry) return res.status(404).json({ error: 'meeting-not-found' });
    const safeId = normalizeUserId(req.body?.userId);
    const attendee = await createAttendeeIn(entry, safeId);
    logEvent('join', `${safeId} joined room ${entry.roomCode}`);
    res.json({ roomCode: entry.roomCode, meeting: entry.meeting, attendee });
  } catch (err) {
    console.error('join failed', err);
    res.status(500).json({ error: 'join-failed' });
  }
});

app.post('/join', async (req, res) => {
  try {
    const safeId = normalizeUserId(req.body?.userId);
    const ref = req.body?.meetingId?.trim();
    let entry = ref ? await resolveEntry(ref) : null;
    if (!entry) {
      const out = await client.send(
        new CreateMeetingCommand({
          ClientRequestToken: crypto.randomUUID(),
          MediaRegion: MEDIA_REGION,
          ExternalMeetingId: `demo-${Date.now()}`,
        }),
      );
      entry = getOrCacheEntry(pickMeeting(out.Meeting));
      logEvent('create', `meeting ${entry.meeting.MeetingId.slice(0, 8)} created (room ${entry.roomCode}, via /join)`);
    }
    const attendee = await createAttendeeIn(entry, safeId);
    logEvent('join', `${safeId} joined room ${entry.roomCode} (via /join)`);
    res.json({ roomCode: entry.roomCode, meeting: entry.meeting, attendee });
  } catch (err) {
    console.error('join shortcut failed', err);
    res.status(500).json({ error: 'join-failed' });
  }
});

app.get('/meetings/:id', async (req, res) => {
  try {
    const got = await client.send(new GetMeetingCommand({ MeetingId: req.params.id }));
    res.json({ meeting: pickMeeting(got.Meeting) });
  } catch (err) {
    res.status(404).json({ error: 'meeting-not-found' });
  }
});

app.delete('/meetings/:id', async (req, res) => {
  try {
    await client.send(new DeleteMeetingCommand({ MeetingId: req.params.id }));
    const entry = meetings.get(req.params.id);
    if (entry) {
      rooms.delete(entry.roomCode);
      meetings.delete(req.params.id);
      logEvent('delete', `room ${entry.roomCode} force-closed`);
    }
    res.json({ deleted: true });
  } catch (err) {
    res.status(404).json({ error: 'meeting-not-found' });
  }
});

const port = Number(process.env.PORT ?? 3000);
app.listen(port, '0.0.0.0', () => {
  console.log(`media-demo-server on :${port} (control=${CONTROL_REGION} media=${MEDIA_REGION})`);
  console.log(`active provider: ${activeProvider}`);
  console.log(`LiveKit configured: ${liveKitConfigured() ? 'yes' : 'no'}`);
  console.log(`Agora configured: ${agoraConfigured() ? 'yes' : 'no'}`);
  console.log(`dashboard: http://127.0.0.1:${port}/`);
});
