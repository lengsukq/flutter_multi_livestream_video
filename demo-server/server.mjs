// Chime demo backend — keys stay server-side, never ship to Flutter.
// Uses AWS_PROFILE=chime-demo (IAM least-privilege), control plane us-east-1.
// Billing: creating meetings is free; attendee-minutes bill only when someone joins.
//
// Room model (user-facing):
//   POST /rooms              { roomCode?, nickname? } -> { roomCode, meeting, attendee? }
//   POST /rooms/:code/join   { userId }               -> { roomCode, meeting, attendee }
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
//   GET  /                    -> dashboard (rooms, headcount, force close)
//   GET  /health              -> { ok, controlRegion, mediaRegion }
//   GET  /api/overview        -> dashboard data
//
// Response shape matches JoinInfo.fromJson: { meeting: {...}, attendee: {...} }

import crypto from 'node:crypto';
import express from 'express';
import cors from 'cors';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  ChimeSDKMeetingsClient,
  CreateMeetingCommand,
  CreateAttendeeCommand,
  GetMeetingCommand,
  DeleteMeetingCommand,
} from '@aws-sdk/client-chime-sdk-meetings';

const CONTROL_REGION = process.env.AWS_REGION ?? 'us-east-1';
const MEDIA_REGION = process.env.CHIME_MEDIA_REGION ?? 'ap-southeast-1';
const STARTED_AT = Date.now();
// Empty-room auto close: sweep every 30s, close rooms with no heartbeat for 90s.
// Heartbeat comes from the app (see POST /rooms/:code/heartbeat).
const EMPTY_CLOSE_AFTER_MS = Number(process.env.EMPTY_CLOSE_AFTER_MS ?? 90_000);
const SWEEP_INTERVAL_MS = 30_000;

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const client = new ChimeSDKMeetingsClient({ region: CONTROL_REGION });
const app = express();
app.use(cors());
app.use(express.json({ limit: '64kb' }));

// ---- in-memory state (restart clears the room directory) ----
// entries: meetingId -> { meeting, roomCode, createdAt, attendees: [{ attendeeId, externalUserId, joinedAt }] }
// rooms: roomCode -> meetingId
const meetings = new Map();
const rooms = new Map();
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
    if (!rooms.has(code)) return code;
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

function getOrCacheEntry(meeting, roomCode = null) {
  let entry = meetings.get(meeting.MeetingId);
  if (!entry) {
    const code = roomCode ?? generateRoomCode();
    entry = {
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

function roomSummary(entry, req) {
  const host = req ? `${req.protocol}://${req.get('host')}` : '';
  return {
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
  res.json({ ok: true, controlRegion: CONTROL_REGION, mediaRegion: MEDIA_REGION });
});

app.get('/api/overview', (req, res) => {
  res.json({
    ok: true,
    controlRegion: CONTROL_REGION,
    mediaRegion: MEDIA_REGION,
    uptimeSec: Math.floor((Date.now() - STARTED_AT) / 1000),
    startedAt: new Date(STARTED_AT).toISOString(),
    roomCount: rooms.size,
    attendeeCount: [...meetings.values()].reduce((n, e) => n + e.attendees.length, 0),
    rooms: [...meetings.values()].map((e) => roomSummary(e, req)),
    events: events.slice(0, 100),
  });
});

app.get('/rooms', (req, res) => {
  res.json({ rooms: [...meetings.values()].map((e) => roomSummary(e, req)) });
});

// ---- room API (primary for the app) ----

// Create a room. Body: { roomCode?, nickname? }.
// If nickname is given the creator joins immediately and attendee is returned too.
app.post('/rooms', async (req, res) => {
  try {
    let code = normalizeRoomCode(req.body?.roomCode);
    if (req.body?.roomCode && !code) {
      return res.status(400).json({ error: 'bad-room-code', hint: 'roomCode must be 4-12 letters/digits' });
    }
    if (code && rooms.has(code)) {
      return res.status(409).json({ error: 'room-exists', hint: 'room taken — join it or pick another code' });
    }
    code ??= generateRoomCode();
    const rawNickname = req.body?.nickname?.trim() || null;
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
      return res.json({ roomCode: code, meeting: entry.meeting, attendee });
    }
    res.json({ roomCode: code, meeting: entry.meeting });
  } catch (err) {
    console.error('create room failed', err);
    logEvent('error', `create room failed: ${err?.name ?? err}`);
    res.status(500).json({ error: 'create-room-failed' });
  }
});

// Join a room by code (or raw meetingId). Body: { userId }.
app.post('/rooms/:code/join', async (req, res) => {
  try {
    const entry = await resolveEntry(req.params.code);
    if (!entry) {
      logEvent('error', `join ${req.params.code} failed: not found`);
      return res.status(404).json({ error: 'room-not-found', hint: 'ask the host for the room number' });
    }
    const userId = req.body?.userId;
    const safeId = normalizeUserId(userId);
    const attendee = await createAttendeeIn(entry, safeId);
    touchHeartbeat(entry);
    logEvent('join', `${safeId} joined room ${entry.roomCode}`);
    res.json({ roomCode: entry.roomCode, meeting: entry.meeting, attendee });
  } catch (err) {
    console.error('room join failed', err);
    logEvent('error', `join room failed: ${err?.name ?? err}`);
    res.status(500).json({ error: 'join-failed' });
  }
});

// Proof-of-life from inside a room. Body: { attendeeId? }.
// Any active client calls this every ~30s; rooms without it get auto-closed.
app.post('/rooms/:code/heartbeat', async (req, res) => {
  const entry = await resolveEntry(req.params.code);
  if (!entry) return res.status(404).json({ error: 'room-not-found' });
  touchHeartbeat(entry);
  res.json({ ok: true, roomCode: entry.roomCode });
});

// Explicit leave notice from the app (best-effort; auto-close covers kills).
// Body: { attendeeId? }. Room closes immediately when the last known
// attendee leaves AND no heartbeat arrives — here we just log it and let
// the sweep handle the close to avoid kicking a second viewer.
app.post('/rooms/:code/leave', async (req, res) => {
  const entry = await resolveEntry(req.params.code);
  if (!entry) return res.status(404).json({ error: 'room-not-found' });
  const who = req.body?.attendeeId ?? req.body?.userId ?? 'someone';
  logEvent('leave', `${who} left room ${entry.roomCode} (auto-close in ~90s if empty)`);
  res.json({ ok: true, roomCode: entry.roomCode });
});

// Force close a room. Deletes the Chime meeting (stops future joins/billing) and drops the directory entry.
app.delete('/rooms/:code', async (req, res) => {
  try {
    const key = String(req.params.code ?? '').trim();
    let meetingId = rooms.has(key) ? rooms.get(key) : key;
    const entry = meetings.get(meetingId);
    await client.send(new DeleteMeetingCommand({ MeetingId: meetingId }));
    if (entry) {
      rooms.delete(entry.roomCode);
      meetings.delete(meetingId);
      logEvent('delete', `room ${entry.roomCode} force-closed (${entry.attendees.length} attendee records)`);
      return res.json({ deleted: true, roomCode: entry.roomCode });
    }
    rooms.delete(key);
    meetings.delete(meetingId);
    logEvent('delete', `meeting ${String(meetingId).slice(0, 8)} force-closed`);
    res.json({ deleted: true });
  } catch (err) {
    const notFound = err?.name === 'NotFoundException';
    if (notFound) {
      const key = String(req.params.code ?? '').trim();
      const id = rooms.get(key);
      if (id) {
        rooms.delete(key);
        meetings.delete(id);
      }
      return res.status(404).json({ error: 'room-not-found' });
    }
    console.error('room delete failed', err);
    res.status(500).json({ error: 'delete-failed' });
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
  console.log(`chime-demo-server on :${port} (control=${CONTROL_REGION} media=${MEDIA_REGION})`);
  console.log('dashboard: http://192.168.31.8:3000/');
});
