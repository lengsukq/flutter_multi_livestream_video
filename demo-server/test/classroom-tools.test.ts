import assert from 'node:assert/strict';
import test from 'node:test';
import { ClassroomStateDirectory } from '../classroom/classroom-state.ts';
import type { RoomEntry } from '../types.ts';

function fixture() {
  const entry: RoomEntry = { provider: 'livekit', roomCode: 'tools123', roomMode: 'meeting',
    classroomTeacherUserId: 'teacher', createdAt: new Date().toISOString(), lastHeartbeatMs: Date.now(),
    attendees: ['teacher', 'alice', 'bob'].map((name, index) => ({
      attendeeId: `p${index}`, userId: name, externalUserId: name, displayName: name,
      joinedAt: new Date(Date.now() - 10000).toISOString(),
    })) };
  const directory = new ClassroomStateDirectory();
  const [teacher, alice, bob] = entry.attendees;
  const act = (action: string, data: object, student = false, eventId?: string) => directory.act(entry,
    student ? alice! : teacher!, !student, { action: `tool.${action}`, payload: JSON.stringify(data), eventId });
  return { entry, directory, teacher: teacher!, alice: alice!, bob: bob!, act };
}

test('classroom tool publication is privileged and retains immutable snapshots', () => {
  const { act, entry, directory } = fixture();
  assert.throws(() => act('notice.publish', { kind: 'focus', text: 'Focus' }, true), /Teacher permission required/);
  const first = act('notice.publish', { kind: 'announcement', text: 'Welcome' }, false, 'notice-id-001');
  const replay = act('notice.publish', { kind: 'announcement', text: 'Welcome' }, false, 'notice-id-001');
  assert.equal(replay.revision, first.revision);
  assert.throws(() => act('notice.publish', { kind: 'announcement', text: 'Changed' }, false, 'notice-id-001'), /Reused eventId/);
  act('notice.publish', { kind: 'focus', text: 'Focus' });
  assert.equal(first.tools.notices.length, 1);
  const homework = act('homework.publish', { title: 'Practice', instructions: 'Read chapter 1', dueAt: '2026-10-10T12:00:00Z' });
  assert.equal(homework.tools.homework[0]?.title, 'Practice');
  assert.throws(() => act('material.share', { title: 'Bad link', url: 'javascript:alert(1)' }), /HTTP/);
  const material = act('material.share', { title: 'Slides', url: 'https://example.test/slides.pdf' });
  assert.equal(material.tools.materials[0]?.url, 'https://example.test/slides.pdf');
  const timer = act('timer.start', { title: 'Practice', seconds: 60 });
  const remaining = Date.parse(timer.tools.timer!.endsAt) - Date.now();
  assert.ok(remaining > 59000 && remaining <= 60000);
  act('timer.stop', {});
  assert.equal(directory.snapshot(entry, false).tools.timer, null);
});

test('quiz hides answer until closed; votes replace rather than multiply', () => {
  const { act, entry, directory, bob } = fixture();
  const quiz = act('activity.publish', { kind: 'quiz', title: '2+2?', options: ['3', '4'], correctOption: 1 });
  const id = quiz.tools.activities[0]!.id;
  const student = directory.snapshot(entry, false, 'alice').tools.activities[0]!;
  assert.ok(!('correctOption' in student));
  assert.ok(!('counts' in student));
  assert.ok(!('answers' in student));
  act('activity.answer', { activityId: id, option: 0 }, true);
  act('activity.answer', { activityId: id, option: 1 }, true);
  directory.act(entry, bob, false, { action: 'tool.activity.answer', payload: JSON.stringify({ activityId: id, option: 0 }) });
  const teacher = directory.snapshot(entry, true).tools.activities[0]!;
  assert.equal(teacher.responseCount, 2);
  assert.deepEqual(teacher.counts, [1, 1]);
  assert.deepEqual(teacher.answers, { alice: 1, bob: 0 });
  act('activity.close', { activityId: id });
  const closed = directory.snapshot(entry, false, 'alice').tools.activities[0]!;
  assert.equal(closed.correctOption, 1);
  assert.deepEqual(closed.counts, [1, 1]);
  assert.equal(closed.selfAnswer, 1);
  assert.ok(!('answers' in closed));
  assert.throws(() => act('activity.answer', { activityId: id, option: 0 }, true), /ended/);
  const poll = act('activity.publish', { kind: 'poll', title: 'Understood?', options: ['Yes', 'No'] });
  assert.ok(!('correctOption' in poll.tools.activities[1]!));
});

test('attendance survives leave/rejoin without counting teacher as student', () => {
  const { entry, directory, alice } = fixture();
  const before = directory.snapshot(entry, true, 'teacher');
  assert.equal(before.stats.onlineCount, 3);
  assert.equal(before.stats.onlineStudents, 2);
  assert.equal(before.stats.studentsTotal, 2);
  assert.equal(before.attendance.length, 2);
  const firstJoined = before.attendance.find(a => a.userId === 'alice')!.firstJoinedAt;
  assert.ok(before.attendance.find(a => a.userId === 'alice')!.onlineMilliseconds >= 10000);
  entry.attendees = entry.attendees.filter(a => a !== alice);
  const left = directory.snapshot(entry, true, 'teacher').attendance.find(a => a.userId === 'alice')!;
  assert.equal(left.online, false); assert.ok(left.lastLeftAt);
  entry.attendees.push({ ...alice, attendeeId: 'rejoined', joinedAt: new Date().toISOString() });
  const joined = directory.snapshot(entry, false, 'alice');
  assert.equal(joined.attendance.length, 1);
  assert.equal(joined.attendance[0]?.firstJoinedAt, firstJoined);
  assert.ok(joined.attendance[0]!.onlineMilliseconds >= left.onlineMilliseconds);
});

test('annotation validates coordinates, source epochs and teacher-only operations', () => {
  const { act } = fixture();
  let state = act('annotation.source', { sourceKey: 'share-1' });
  const canvasId = state.tools.annotation.canvasId;
  const shape = { canvasId, id: 'stroke-1', tool: 'pen', width: 3, color: 0xffffcc00, points: [{ x: .1, y: .2 }] };
  assert.throws(() => act('annotation.begin', shape, true), /Teacher permission required/);
  act('annotation.begin', shape, false, 'stroke-begin-001');
  state = act('annotation.append', { canvasId, id: 'stroke-1', points: [{ x: .3, y: .4 }] }, false, 'stroke-append-001');
  const old = state;
  act('annotation.append', { canvasId, id: 'stroke-1', points: [{ x: .3, y: .4 }] }, false, 'stroke-append-001');
  assert.equal(state.tools.annotation.shapes[0]?.points.length, 2);
  assert.throws(() => act('annotation.append', { canvasId, id: 'stroke-1', points: [{ x: 2, y: 0 }] }), /normalized/);
  for (const tool of ['highlight', 'circle', 'arrow', 'text']) act('annotation.begin', {
    ...shape, id: tool, tool, text: tool === 'text' ? 'Hello' : '',
  });
  assert.equal(old.tools.annotation.shapes.length, 1);
  state = act('annotation.erase', {canvasId,id:'circle'});
  assert.equal(state.tools.annotation.shapes.some((s:{id:string})=>s.id==='circle'),false);
  assert.throws(()=>act('annotation.erase',{canvasId,id:'pen'},true),/Teacher permission/);
  state = act('annotation.undo',{canvasId});
  assert.equal(state.tools.annotation.shapes.some((s:{id:string})=>s.id==='circle'),true);
  state = act('annotation.undo', { canvasId }); assert.equal(state.tools.annotation.shapes.length, 4);
  state = act('annotation.clear', { canvasId }); assert.equal(state.tools.annotation.shapes.length, 0);
  const next = act('annotation.source', { sourceKey: 'share-2' });
  assert.notEqual(next.tools.annotation.canvasId, canvasId);
  assert.throws(() => act('annotation.begin', shape), /Shared screen changed/);
  assert.equal(next.tools.annotation.participantId, 'p0');
});
