import type { Express, Request, Response } from 'express';
import type { RoomEntry } from '../types.ts';
import type { ProviderRegistry } from '../providers/provider-registry.ts';
import type { ClassroomStateDirectory } from '../classroom/classroom-state.ts';
import type { LiveInteractionDirectory } from '../live/live-interactions.ts';
import { requireParticipantCredential } from '../participant-credential.ts';
import { matchesRoomOwnerCredential } from '../room-owner-credential.ts';

export interface InteractionRouteDependencies {
  resolveRoom(ref: unknown): Promise<RoomEntry | null>;
  withRoomOperation: <T>(entry: RoomEntry, action: () => Promise<T> | T) => Promise<T>;
  assertRoomOpen(entry: RoomEntry): void;
  isRoomPartiallyClosed(entry: RoomEntry): boolean;
  pruneStaleAttendees(entry: RoomEntry, now: number, insideOperation?: boolean): void;
  contractError(res: Response, status: number, code: string, message: string, details?: unknown): Response;
  sendProviderError(res: Response, error: unknown): Response | false;
  classroomDirectory: ClassroomStateDirectory;
  liveInteractionDirectory: LiveInteractionDirectory;
  providerRegistry: ProviderRegistry;
}

/** Provider-neutral, credential-checked classroom and live interaction API. */
export function registerInteractionRoutes(app: Express, deps: InteractionRouteDependencies): void {
  const {
    resolveRoom, withRoomOperation, assertRoomOpen, isRoomPartiallyClosed,
    pruneStaleAttendees, contractError, sendProviderError,
    classroomDirectory, liveInteractionDirectory, providerRegistry,
  } = deps;

// Reference control plane for classroom interactions. The Flutter SDK consumes
// these endpoints; the Demo UI never implements classroom business logic.
// HTTP requests are authenticated per joined participant and privileged
// actions additionally require the existing room owner credential.
async function classroomRequest(req: Request, res: Response, mutate: boolean) {
  try {
    const entry = await resolveRoom(req.params.code);
    if (!entry) {
      return contractError(res, 404, 'room-not-found', 'The requested room was not found.');
    }
    return await withRoomOperation(entry, async () => {
      assertRoomOpen(entry);
      if (isRoomPartiallyClosed(entry)) return contractError(res, 409, 'room-closing', 'The room is closing.');
      pruneStaleAttendees(entry, Date.now(), true);
      const participantId = String(req.body?.requesterParticipantId ?? '').trim();
      const attendee = requireParticipantCredential(
        entry, participantId, req.body?.participantCredential,
      );
      const proof = String(req.body?.roomOwnerCredential ?? '').trim();
      // Invalid owner proofs are never silently treated as student sessions.
      if (proof && !matchesRoomOwnerCredential(entry, proof)) {
        return contractError(res, 403, 'forbidden', 'Invalid room owner credential.');
      }
      const isTeacher = Boolean(proof);
      if (mutate && ['speak.grant', 'speak.revoke'].includes(req.body?.action)) {
        if (!isTeacher) {
          return contractError(res, 403, 'forbidden', 'Teacher permission required.');
        }
        classroomDirectory.snapshot(entry, isTeacher, attendee.userId ?? attendee.externalUserId);
        const shouldApply = classroomDirectory.requiresSpeakerProviderUpdate(
          entry, attendee, isTeacher, req.body ?? {},
        );
        const targetUserId = String(req.body?.userId ?? '').trim();
        const target = entry.attendees.find(
          (person) => (person.userId ?? person.externalUserId) === targetUserId,
        );
        if (!target) {
          return contractError(res, 404, 'participant-not-found', 'Target student is not online.');
        }
        if (targetUserId === entry.classroomTeacherUserId) {
          return contractError(res, 403, 'forbidden', 'Teacher microphone cannot be changed here.');
        }
        const provider = providerRegistry.requireConfigured(entry.provider);
        if (shouldApply && provider.setClassroomMicrophonePermission) {
          await provider.setClassroomMicrophonePermission(
            entry, target.attendeeId, req.body.action === 'speak.grant',
          );
        }
      }
      const payload = mutate
        ? classroomDirectory.act(entry, attendee, isTeacher, req.body ?? {})
        : classroomDirectory.snapshot(
            entry, isTeacher, attendee.userId ?? attendee.externalUserId);
      return res.json(payload);
    });
  } catch (error) {
    if (sendProviderError(res, error) !== false) return;
    console.error('classroom control request failed', error);
    return contractError(res, 502, 'classroom-control-failed',
      'Unable to apply the classroom action. Please retry.');
  }
}

app.post('/rooms/:code/classroom/snapshot', (req, res) =>
  classroomRequest(req, res, false));
app.post('/rooms/:code/classroom/action', (req, res) =>
  classroomRequest(req, res, true));

// Independent from the selected Chat vendor. Client signals never apply gifts.
async function liveInteractionRequest(req: Request, res: Response, operation: 'snapshot' | 'gift' | 'like') {
  try {
    const entry = await resolveRoom(req.params.code);
    if (!entry) return contractError(res, 404, 'room-not-found', 'The requested room was not found.');
    return await withRoomOperation(entry, async () => {
      assertRoomOpen(entry);
      if (isRoomPartiallyClosed(entry)) return contractError(res, 409, 'room-closing', 'The room is closing.');
      pruneStaleAttendees(entry, Date.now(), true);
      const attendee = requireParticipantCredential(entry,
        String(req.body?.requesterParticipantId ?? '').trim(), req.body?.participantCredential);
      res.json(operation === 'gift' ? liveInteractionDirectory.send(entry, attendee, req.body ?? {})
        : operation === 'like' ? liveInteractionDirectory.sendLike(entry, attendee, req.body ?? {})
        : liveInteractionDirectory.snapshot(entry, attendee));
    });
  } catch (error) {
    if (sendProviderError(res, error) !== false) return;
    console.error('live interaction failed', error);
    contractError(res, 502, 'live-interaction-failed', 'Unable to apply live interaction.');
  }
}
app.post('/rooms/:code/live/snapshot', (req, res) => liveInteractionRequest(req, res, 'snapshot'));
app.post('/rooms/:code/live/gift', (req, res) => liveInteractionRequest(req, res, 'gift'));
app.post('/rooms/:code/live/like', (req, res) => liveInteractionRequest(req, res, 'like'));


}
