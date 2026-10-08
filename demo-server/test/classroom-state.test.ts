import assert from 'node:assert/strict';
import test from 'node:test';
import { ClassroomStateDirectory } from '../classroom/classroom-state.ts';
import type { RoomEntry } from '../types.ts';

const entry: RoomEntry = {
  provider: 'livekit', roomCode: 'class123', roomMode: 'meeting',
  createdAt: new Date().toISOString(), lastHeartbeatMs: Date.now(),
  attendees: [
    { attendeeId: 't1', userId: 'teacher', displayName: 'Teacher',
      externalUserId: 'teacher', joinedAt: new Date().toISOString() },
    { attendeeId: 's1', userId: 'student', displayName: 'Student',
      externalUserId: 'student', joinedAt: new Date().toISOString() },
  ],
};
const teacher = entry.attendees[0]!;
const student = entry.attendees[1]!;

test('classroom supports hand raise, Q&A and speaker grants with role enforcement', () => {
  const room = new ClassroomStateDirectory();
  let s = room.act(entry, student, false, { action: 'hand.raise', eventId: 'student-a-01' });
  assert.equal(s.stats.handsRaised, 1);
  assert.equal(s.role, 'student');
  const revision = s.revision;
  s = room.act(entry, student, false, { action: 'hand.raise', eventId: 'student-a-01' });
  assert.equal(s.revision, revision);
  assert.throws(
    () => room.act(entry, student, false, { action: 'speak.grant', userId: 'student' }),
    /Teacher permission required/,
  );
  s = room.act(entry, teacher, true, { action: 'speak.grant', userId: 'student' });
  assert.equal(s.stats.handsRaised, 0);
  assert.equal(s.students.find(p => p.userId === 'student')?.canSpeak, true);
  s = room.act(entry, student, false, { action: 'question.ask', text: 'What is RTC?' });
  assert.equal(s.stats.pendingQuestions, 1);
  const qid = s.questions[0]!.id;
  assert.throws(() => room.act(entry, student, false,
    { action: 'question.resolve', questionId: qid }), /Teacher permission required/);
  s = room.act(entry, teacher, true,
    { action: 'question.answer', questionId: qid, text: 'Real time communication' });
  assert.equal(s.questions[0]?.status, 'answered');
  s = room.act(entry, teacher, true,
    { action: 'question.resolve', questionId: qid });
  assert.equal(s.questions[0]?.status, 'resolved');
  s = room.act(entry, teacher, true, { action: 'speak.revoke', userId: 'student' });
  assert.equal(s.students.find(p => p.userId === 'student')?.canSpeak, false);
});

test('raised hands form a stable first-requested FIFO queue', () => {
  const room: RoomEntry = {
    ...entry,
    attendees: entry.attendees.map(a => ({ ...a })),
  };
  const alice = { attendeeId: 'a3', userId: 'alice',
    displayName: 'Alice', externalUserId: 'alice',
    joinedAt: new Date().toISOString() };
  room.attendees.unshift(alice);
  const directory = new ClassroomStateDirectory();
  directory.act(room, room.attendees[2]!, false, { action: 'hand.raise' });
  let state = directory.act(room, alice, false, { action: 'hand.raise' });
  assert.deepEqual(state.students.filter(s => s.handRaised).map(s => s.userId),
    ['student', 'alice']);
  directory.act(room, room.attendees[2]!, false, { action: 'hand.lower' });
  state = directory.act(room, room.attendees[2]!, false, { action: 'hand.raise' });
  assert.deepEqual(state.students.filter(s => s.handRaised).map(s => s.userId),
    ['alice', 'student']);
  assert.equal(state.stats.handRaisesTotal, 3);
});

test('offline students remain visible while online and hand counts update', () => {
  const directory = new ClassroomStateDirectory();
  const room: RoomEntry = {
    ...entry,
    classroomTeacherUserId: 'teacher',
    attendees: entry.attendees.map(a => ({ ...a })),
  };
  directory.snapshot(room, true, 'teacher');
  const first = directory.act(room, room.attendees[1]!, false, {
    action: 'hand.raise',
  });
  assert.equal(first.stats.handsRaised, 1);
  const previousRevision = first.revision;
  room.attendees = [room.attendees[0]!];
  const afterLeaving = directory.snapshot(room, true, 'teacher');
  assert.equal(afterLeaving.stats.onlineCount, 1);
  assert.equal(afterLeaving.stats.handsRaised, 0);
  assert.ok(afterLeaving.revision > previousRevision);
  assert.equal(afterLeaving.students.find(s => s.userId === 'student')?.online, false);
  assert.equal(afterLeaving.students.find(s => s.userId === 'student')?.role, 'student');
  assert.equal(afterLeaving.students.find(s => s.userId === 'teacher')?.role, 'teacher');
});

test('idempotency keys cannot be reused for different payloads', () => {
  const directory = new ClassroomStateDirectory();
  directory.act(entry, student, false, {
    action: 'question.ask', text: 'Question one', eventId: 'question-event-1',
  });
  assert.throws(() => directory.act(entry, student, false, {
    action: 'question.ask', text: 'Different question', eventId: 'question-event-1',
  }), /Reused eventId/);
});

test('Q&A limits prevent repeated question floods without affecting role enforcement', () => {
  const directory = new ClassroomStateDirectory();
  for (const text of ['One', 'Two', 'Three']) {
    directory.act(entry, student, false, { action: 'question.ask', text });
  }
  assert.throws(() => directory.act(entry, student, false, {
    action: 'question.ask', text: 'Four',
  }), /Please wait before asking/);
  assert.throws(() => directory.act(entry, student, false, {
    action: 'question.resolve', questionId: 'missing',
  }), /Teacher permission required/);
});

test('classroom only applies to meeting rooms and trims invalid actions', () => {
  const directory = new ClassroomStateDirectory();
  assert.throws(() => directory.act(entry, student, false,
    { action: 'question.ask', text: '' }), /Question must contain/);
  assert.throws(() => directory.act(entry, student, false,
    { action: 'unknown' }), /Unknown classroom action/);
  const live = { ...entry, roomMode: 'broadcast' as const };
  assert.throws(() => directory.snapshot(live, false), /Classroom requires a meeting/);
});

test('new participant identities reset grants and hands; unchanged identities keep grants', () => {
  const room:RoomEntry={...entry, attendees:entry.attendees.map(a=>({...a}))};
  const directory=new ClassroomStateDirectory();
  directory.snapshot(room,true);
  directory.act(room,room.attendees[0]!,true,{action:'speak.grant',userId:'student'});
  directory.act(room,room.attendees[1]!,false,{action:'hand.raise'});
  assert.equal(directory.snapshot(room,true).students.find(s=>s.userId==='student')?.canSpeak,true);
  room.attendees[1]={...room.attendees[1]!,attendeeId:'new-student'};
  const changed=directory.snapshot(room,true).students.find(s=>s.userId==='student');
  assert.equal(changed?.canSpeak,false);assert.equal(changed?.handRaised,false);
});

test('heartbeat pruning retains the old RTC identity for revocation before rejoin', () => {
  const room:RoomEntry={...entry, attendees:entry.attendees.map(a=>({...a}))};
  const directory=new ClassroomStateDirectory();
  directory.snapshot(room,true);
  directory.act(room,room.attendees[0]!,true,{action:'speak.grant',userId:'student'});
  room.attendees=room.attendees.filter(a=>a.userId!=='student');
  directory.snapshot(room,true);
  assert.equal(directory.previousParticipantId(room,'student'),'s1');
  directory.resetParticipant(room,'s1');
  room.attendees.push({...student,attendeeId:'s-new'});
  assert.equal(directory.snapshot(room,true).students.find(s=>s.userId==='student')?.canSpeak,false);
});
