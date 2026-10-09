import type { Express, RequestHandler } from 'express';
import type { ChimeRoomEntry, ProviderAdapter, RoomEntry } from '../types.ts';
import type { RoomDirectory } from '../providers/room-directory.ts';
import type { ClassroomStateDirectory } from '../classroom/classroom-state.ts';
import type { LiveInteractionDirectory } from '../live/live-interactions.ts';
import { createChimeProvider } from '../providers/chime.ts';

export interface LegacyChimeRouteDependencies {
  chimeProvider: ReturnType<typeof createChimeProvider>;
  roomDirectory: RoomDirectory;
  classroomDirectory: ClassroomStateDirectory;
  liveInteractionDirectory: LiveInteractionDirectory;
  generateRoomCode(): string;
  registerRoom(provider: ProviderAdapter, entry: RoomEntry): RoomEntry;
  resolveChimeRoom(ref: unknown): Promise<RoomEntry | null>;
  logEvent(type: string, message: string): void;
  withRoomOperation: <T>(entry: RoomEntry, action: () => Promise<T> | T) => Promise<T>;
  requireSameOrigin: RequestHandler;
  requireAdmin: RequestHandler;
}

/** The deprecated Chime endpoint routes stay outside the core v1 contract. */
export function registerLegacyChimeRoutes(app: Express, deps: LegacyChimeRouteDependencies): void {
  const {
    chimeProvider, roomDirectory, classroomDirectory, liveInteractionDirectory,
    generateRoomCode, registerRoom, resolveChimeRoom, logEvent, withRoomOperation,
    requireSameOrigin, requireAdmin,
  } = deps;

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
    const entry = roomDirectory.get(meetingId);
    const remove = async () => {
      await chimeProvider.deleteLegacyMeeting(meetingId);
      if (entry?.provider === 'chime') {
        roomDirectory.remove(entry);
        classroomDirectory.forget(entry);
        liveInteractionDirectory.forget(entry);
        logEvent('delete', `room ${entry.roomCode} force-closed`);
      }
    };
    if (entry) await withRoomOperation(entry, remove);
    else await remove();
    res.json({ deleted: true });
  } catch (_) {
    res.status(404).json({ error: 'meeting-not-found' });
  }
});


}
