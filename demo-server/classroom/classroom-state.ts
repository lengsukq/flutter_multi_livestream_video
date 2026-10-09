import crypto from 'node:crypto';
import { applyClassroomTool, classroomToolsSnapshot, createClassroomTools, type ClassroomTools } from './classroom-tools.ts';
import { ProviderOperationError } from '../providers/provider-registry.ts';
import type { RoomEntry, RoomAttendee } from '../types.ts';
import type { ClassroomStore, ClassroomStoredState } from './classroom-store.ts';

type QuestionStatus = 'pending' | 'answered' | 'resolved';
type Question = {
  id: string;
  userId: string;
  displayName: string;
  text: string;
  status: QuestionStatus;
  createdAt: string;
  answer?: string;
};
type SeenStudent = {
  userId: string;
  participantId: string;
  displayName: string;
  lastSeenMs: number;
  online: boolean;
  firstJoinedAt?: string;
  lastJoinedAt?: string;
  lastLeftAt?: string;
  onlineSinceMs?: number;
  accumulatedMs?: number;
};
type State = {
  revision: number;
  nextRaiseOrder: number;
  handRaisesTotal: number;
  raised: Map<string, number>;
  grants: Set<string>;
  grantParticipants: Map<string, string>;
  questions: Map<string, Question>;
  handledIds: Map<string, string>;
  questionTimes: Map<string, number[]>;
  seenStudents: Map<string, SeenStudent>;
  speakGrants: number;
  feedback: NonNullable<ClassroomStoredState['feedback']>;
  feedbackTimes: Map<string, number[]>;
};

const fail = (message: string, code = 'invalid-argument', status = 400): never => {
  throw new ProviderOperationError(status, code, message);
};

/** In-memory reference backend. This does not claim persistence across restarts. */
export class ClassroomStateDirectory {
  private readonly rooms = new WeakMap<RoomEntry, State>();
  private readonly store?: ClassroomStore;
  private readonly tools = new WeakMap<RoomEntry, ClassroomTools>();
  private getTools(entry: RoomEntry): ClassroomTools {
    let tools = this.tools.get(entry);
    if (!tools) { tools = createClassroomTools(); this.tools.set(entry, tools); }
    return tools;
  }
  constructor(store?: ClassroomStore) {
    this.store = store;
  }

  /** Validate a privileged microphone action before invoking the remote RTC
   * API. This prevents invalid/replayed events from mutating vendor state. */
  requiresSpeakerProviderUpdate(
    entry: RoomEntry, requester: RoomAttendee, isTeacher: boolean,
    raw: Record<string, unknown>,
  ): boolean {
    if (entry.roomMode !== 'meeting') {
      fail('Classroom requires a meeting room', 'unsupported-feature', 400);
    }
    if (!isTeacher) fail('Teacher permission required', 'forbidden', 403);
    const action = String(raw.action ?? '');
    if (action !== 'speak.grant' && action !== 'speak.revoke') {
      fail('Unsupported speaking action');
    }
    const userId = requester.userId ?? requester.externalUserId;
    if (!userId) fail('Unknown user identity', 'forbidden', 403);
    const target = String(raw.userId ?? '').trim();
    const present = entry.attendees.some(
      attendee => (attendee.userId ?? attendee.externalUserId) === target,
    );
    if (!target || (action === 'speak.grant' && !present)) {
      fail('Target student is not online', 'participant-not-found', 404);
    }
    if (target === entry.classroomTeacherUserId) {
      fail('Teacher microphone cannot be changed here', 'forbidden', 403);
    }
    const idempotency = String(raw.eventId ?? '').trim();
    if (idempotency && !/^[a-zA-Z0-9_-]{8,128}$/.test(idempotency)) {
      fail('Invalid classroom eventId');
    }
    const state = this.get(entry);
    const key = JSON.stringify([userId, action, target, '', '']);
    if (idempotency) {
      const previous = state.handledIds.get(idempotency);
      if (previous && previous !== key) {
        fail('Reused eventId with different payload', 'idempotency-conflict', 409);
      }
      if (previous) return false;
    }
    return action === 'speak.grant'
      ? !state.grants.has(target)
      : state.grants.has(target);
  }

  private persist(entry: RoomEntry, state: State): void {
    this.store?.save(entry, {
      version: 1,
      revision: state.revision,
      nextRaiseOrder: state.nextRaiseOrder,
      handRaisesTotal: state.handRaisesTotal,
      raised: [...state.raised],
      grants: [...state.grants],
      grantParticipants: [...state.grantParticipants],
      questions: [...state.questions],
      handledIds: [...state.handledIds],
      questionTimes: [...state.questionTimes],
      seenStudents: [...state.seenStudents],
      speakGrants: state.speakGrants,
      feedback: state.feedback,
      feedbackTimes: [...state.feedbackTimes],
    });
  }

  private rehydrate(saved: ClassroomStoredState): State {
    if (!Array.isArray(saved.raised) || !Array.isArray(saved.grants) ||
        !Array.isArray(saved.questions) || !Array.isArray(saved.handledIds) ||
        !Array.isArray(saved.questionTimes) || !Array.isArray(saved.seenStudents)) {
      throw new Error('Invalid saved classroom collections.');
    }
    return {
      revision: saved.revision,
      nextRaiseOrder: saved.nextRaiseOrder ??
        Math.max(0, ...saved.raised.map(([, order]) => order)),
      handRaisesTotal: saved.handRaisesTotal ?? saved.raised.length,
      raised: new Map(saved.raised),
      grants: new Set(saved.grants),
      grantParticipants: new Map(saved.grantParticipants ?? []),
      questions: new Map(saved.questions),
      handledIds: new Map(saved.handledIds),
      questionTimes: new Map(saved.questionTimes),
      seenStudents: new Map(saved.seenStudents),
      speakGrants: saved.speakGrants,
      feedback: (saved.feedback ?? []).slice(-200),
      feedbackTimes: new Map(saved.feedbackTimes ?? []),
    };
  }

  private get(entry: RoomEntry): State {
    let state = this.rooms.get(entry);
    if (!state) {
      const saved = this.store?.load(entry);
      state = saved ? this.rehydrate(saved) : {
        revision: 0, nextRaiseOrder: 0, handRaisesTotal: 0,
        raised: new Map(), grants: new Set(), grantParticipants: new Map(),
        questions: new Map(), handledIds: new Map(),
        questionTimes: new Map(), seenStudents: new Map(), speakGrants: 0,
        feedback: [], feedbackTimes: new Map(),
      };
      this.rooms.set(entry, state);
    }
    return state;
  }

  snapshot(entry: RoomEntry, isTeacher: boolean, selfUserId = '') {
    if (entry.roomMode !== 'meeting') fail('Classroom requires a meeting room', 'unsupported-feature', 400);
    const state = this.get(entry);
    const attendees = new Map<string, RoomAttendee>();
    let changed = false;
    const now = Date.now();
    for (const attendee of entry.attendees) {
      const userId = attendee.userId ?? attendee.externalUserId;
      if (userId) {
        attendees.set(userId, attendee);
        const previous = state.seenStudents.get(userId);
        if (!previous || !previous.online ||
            previous.participantId !== attendee.attendeeId) changed = true;
        if (previous && previous.participantId !== attendee.attendeeId) {
          changed = state.raised.delete(userId) || changed;
        }
        state.seenStudents.set(userId, {
          userId, participantId: attendee.attendeeId,
          displayName: attendee.displayName ?? attendee.externalUserId ?? userId,
          lastSeenMs: now, online: true,
          firstJoinedAt: previous?.firstJoinedAt ?? attendee.joinedAt,
          lastJoinedAt: !previous?.online || previous.participantId !== attendee.attendeeId ? attendee.joinedAt : previous.lastJoinedAt,
          lastLeftAt: previous?.lastLeftAt,
          onlineSinceMs: previous?.online ? previous.onlineSinceMs ?? now : Math.min(now, Date.parse(attendee.joinedAt) || now),
          accumulatedMs: previous?.accumulatedMs ?? 0,
        });
      }
    }
    for (const [userId, student] of state.seenStudents) {
      if (!attendees.has(userId) && student.online) {
        state.seenStudents.set(userId, { ...student, online: false,
          lastLeftAt: new Date(now).toISOString(), onlineSinceMs: undefined,
          accumulatedMs: (student.accumulatedMs ?? 0) + Math.max(0, now - (student.onlineSinceMs ?? now)),
        });
        changed = true;
      }
    }
    // A missing participant cannot leave a stale raised hand or speaking grant.
    for (const id of state.raised.keys()) {
      if (!attendees.has(id)) changed = state.raised.delete(id) || changed;
    }
    for (const id of state.grants.keys()) {
      if (!attendees.has(id) || state.grantParticipants.get(id) !== attendees.get(id)?.attendeeId) {
        changed = state.grants.delete(id) || changed;
        state.grantParticipants.delete(id);
      }
    }
    if (changed) state.revision++;
    if (changed) this.persist(entry, state);
    const students = [...state.seenStudents.values()].map((person) => ({
      userId: person.userId,
      participantId: attendees.get(person.userId)?.attendeeId ?? person.participantId,
      displayName: person.displayName,
      role: entry.classroomTeacherUserId === person.userId ? 'teacher' : 'student',
      online: person.online,
      handRaised: state.raised.has(person.userId),
      canSpeak: state.grants.has(person.userId),
    }));
    students.sort((a, b) =>
      (state.raised.get(a.userId) ?? Number.MAX_SAFE_INTEGER) -
      (state.raised.get(b.userId) ?? Number.MAX_SAFE_INTEGER));
    const questions = [...state.questions.values()];
    questions.sort((a, b) => a.createdAt.localeCompare(b.createdAt));
    return {
      contractVersion: 1, roomCode: entry.roomCode,
      role: isTeacher ? 'teacher' : 'student',
      selfUserId,
      revision: state.revision,
      speakEnforcement: entry.classroomSpeakEnforcement ?? 'advisory',
      students, questions,
      feedbackSupported: true,
      feedback: state.feedback.filter(item => isTeacher || item.userId === selfUserId),
      tools: classroomToolsSnapshot(this.getTools(entry), isTeacher, selfUserId),
      attendance: [...state.seenStudents.values()]
        .filter(person => person.userId !== entry.classroomTeacherUserId && (isTeacher || person.userId === selfUserId))
        .map(person => ({ userId: person.userId, displayName: person.displayName,
          online: person.online, firstJoinedAt: person.firstJoinedAt ?? null,
          lastJoinedAt: person.lastJoinedAt ?? null, lastLeftAt: person.lastLeftAt ?? null,
          onlineMilliseconds: (person.accumulatedMs ?? 0) + (person.online ? Math.max(0, now - (person.onlineSinceMs ?? now)) : 0),
        })),
      stats: {
        onlineCount: attendees.size,
        onlineStudents: students.filter(s => s.role === 'student' && s.online).length,
        studentsTotal: students.filter(s => s.role === 'student').length,
        handsRaised: state.raised.size,
        pendingQuestions: questions.filter(q => q.status === 'pending').length,
        questionsTotal: questions.length, speakGrants: state.speakGrants,
        handRaisesTotal: state.handRaisesTotal,
        chatMessages: 0,
      },
    };
  }

  act(
    entry: RoomEntry, requester: RoomAttendee, isTeacher: boolean,
    raw: Record<string, unknown>,
  ) {
    if (entry.roomMode !== 'meeting') fail('Classroom requires a meeting room', 'unsupported-feature', 400);
    const state = this.get(entry);
    const userId = requester.userId ?? requester.externalUserId;
    if (!userId) fail('Unknown user identity', 'forbidden', 403);
    const action = String(raw.action ?? '');
    const teacherOnly = new Set(['speak.grant', 'speak.revoke', 'question.answer', 'question.resolve']);
    if (teacherOnly.has(action) && !isTeacher) fail('Teacher permission required', 'forbidden', 403);

    const idempotency = String(raw.eventId ?? '').trim();
    if (idempotency && !/^[a-zA-Z0-9_-]{8,128}$/.test(idempotency)) {
      fail('Invalid classroom eventId');
    }
    const target = String(raw.userId ?? '').trim();
    const questionId = String(raw.questionId ?? '').trim();
    const text = String(raw.text ?? '').trim();
    const feedbackKind = String(raw.kind ?? '');
    const operationKey = JSON.stringify(action === 'feedback.send'
      ? [userId, action, feedbackKind]
      : action.startsWith('tool.')
      ? [userId, action, target, questionId, text, raw.payload ?? '']
      : [userId, action, target, questionId, text]);
    if (idempotency) {
      const previous = state.handledIds.get(idempotency);
      if (previous && previous !== operationKey) {
        fail('Reused eventId with different payload', 'idempotency-conflict', 409);
      }
      if (previous) return this.snapshot(entry, isTeacher, userId);
    }
    let changed = false;
    switch (action) {
      case 'feedback.send': {
        if (isTeacher || userId === entry.classroomTeacherUserId) {
          fail('Only students can send classroom feedback', 'forbidden', 403);
        }
        const kinds = ['understood', 'great', 'idea', 'question', 'clap'] as const;
        const kind = kinds.find(value => value === feedbackKind);
        if (!kind) fail('Unknown classroom feedback kind');
        const now = Date.now();
        const recent = (state.feedbackTimes.get(userId) ?? []).filter(time => now - time < 10_000);
        if (recent.length >= 5) fail('Please wait before sending more feedback', 'rate-limited', 429);
        // Only authenticated participant metadata supplies the sender identity.
        state.feedback.push({
          id: crypto.randomUUID(), userId,
          displayName: requester.displayName ?? userId,
          kind: kind!, createdAt: new Date(now).toISOString(),
        });
        if (state.feedback.length > 200) state.feedback.splice(0, state.feedback.length - 200);
        recent.push(now);
        state.feedbackTimes.set(userId, recent);
        changed = true;
        break;
      }
      case 'hand.raise':
        if (!state.raised.has(userId)) {
          state.raised.set(userId, ++state.nextRaiseOrder);
          state.handRaisesTotal++;
          changed = true;
        }
        break;
      case 'hand.lower':
        changed = state.raised.delete(userId);
        break;
      case 'speak.grant':
        if (!target || !entry.attendees.some(a => (a.userId ?? a.externalUserId) === target)) {
          fail('Target student is not online', 'participant-not-found', 404);
        }
        if (!state.grants.has(target)) {
          state.grants.add(target);
          state.grantParticipants.set(target, entry.attendees.find(a => (a.userId ?? a.externalUserId) === target)!.attendeeId);
          state.raised.delete(target);
          state.speakGrants++;
          changed = true;
        }
        break;
      case 'speak.revoke':
        if (!target) fail('userId is required');
        changed = state.grants.delete(target);
        state.grantParticipants.delete(target);
        break;
      case 'question.ask':
        if (!text || text.length > 500) fail('Question must contain 1-500 characters');
        if (state.questions.size >= 1000) {
          fail('Classroom question limit reached', 'resource-limit', 429);
        }
        {
          const now = Date.now();
          const recent = (state.questionTimes.get(userId) ?? [])
            .filter(time => now - time < 30_000);
          if (recent.length >= 3) {
            fail('Please wait before asking more questions', 'rate-limited', 429);
          }
          recent.push(now);
          state.questionTimes.set(userId, recent);
        }
        {
          const id = crypto.randomUUID();
          state.questions.set(id, {
          id, userId, displayName: requester.displayName ?? userId,
          text, status: 'pending', createdAt: new Date().toISOString(),
          });
        }
        changed = true;
        break;
      case 'question.answer': {
        if (!text || text.length > 1000) fail('Answer must contain 1-1000 characters');
        const q = state.questions.get(questionId);
        if (!q) fail('Question does not exist', 'question-not-found', 404);
        if (q!.status === 'resolved') fail('Resolved question cannot be answered', 'invalid-state', 409);
        if (q!.answer !== text || q!.status !== 'answered') {
          q!.answer = text; q!.status = 'answered'; changed = true;
        }
        break;
      }
      case 'question.resolve': {
        const q = state.questions.get(questionId);
        if (!q) fail('Question does not exist', 'question-not-found', 404);
        if (q!.status !== 'resolved') { q!.status = 'resolved'; changed = true; }
        break;
      }
      default:
        if (action.startsWith('tool.')) {
          changed = applyClassroomTool(this.getTools(entry), action, raw, requester, isTeacher);
        } else fail('Unknown classroom action');
    }
    if (idempotency) {
      state.handledIds.set(idempotency, operationKey);
      if (state.handledIds.size > 1000) {
        state.handledIds.delete(state.handledIds.keys().next().value!);
      }
    }
    if (changed) state.revision++;
    if (changed || idempotency) this.persist(entry, state);
    return this.snapshot(entry, isTeacher, userId);
  }

  /** Presence history survives heartbeat pruning, which does not terminate RTC. */
  previousParticipantId(entry: RoomEntry, userId: string): string | undefined {
    return this.get(entry).seenStudents.get(userId)?.participantId;
  }

  /** Called after the old provider permission has been revoked successfully. */
  resetParticipant(entry: RoomEntry, participantId: string): void {
    const attendee = entry.attendees.find(a => a.attendeeId === participantId);
    const remembered = [...this.get(entry).seenStudents.values()].find(s => s.participantId === participantId);
    const userId = attendee?.userId ?? attendee?.externalUserId ?? remembered?.userId;
    if (!userId) return;
    const state = this.get(entry);
    const hand = state.raised.delete(userId);
    const grant = state.grants.delete(userId);
    state.grantParticipants.delete(userId);
    if (hand || grant) { state.revision++; this.persist(entry, state); }
  }

  forget(entry: RoomEntry): void {
    this.rooms.delete(entry);
    this.tools.delete(entry);
    this.store?.delete?.(entry);
  }
}
