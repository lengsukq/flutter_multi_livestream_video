import assert from 'node:assert/strict';
import test from 'node:test';
import { ClassroomStateDirectory } from '../classroom/classroom-state.ts';
import type { ClassroomStoredState } from '../classroom/classroom-store.ts';
import type { RoomEntry } from '../types.ts';

function room(): RoomEntry {
  return {
    provider: 'livekit', roomCode: 'feedback1', roomMode: 'meeting',
    classroomTeacherUserId: 'teacher',
    createdAt: new Date().toISOString(), lastHeartbeatMs: Date.now(),
    attendees: ['teacher', 'alice', 'bob'].map(userId => ({
      attendeeId: `${userId}-participant`, userId, displayName: userId.toUpperCase(),
      externalUserId: userId, joinedAt: new Date().toISOString(),
    })),
  };
}

test('feedback uses authenticated identity, teacher sees all, students see only their own', () => {
  const entry = room();
  const directory = new ClassroomStateDirectory();
  // No room-level enable operation or configuration is required.
  assert.equal(directory.snapshot(entry, false, 'alice').feedbackSupported, true);
  assert.equal(directory.snapshot(entry, true, 'teacher').feedbackSupported, true);
  const first = directory.act(entry, entry.attendees[1]!, false, {
    action: 'feedback.send', kind: 'question', eventId: 'feedback-alice-1',
    userId: 'bob', displayName: 'Forged',
  });
  assert.equal(first.feedbackSupported, true);
  assert.equal(first.feedback[0]?.userId, 'alice');
  assert.equal(first.feedback[0]?.displayName, 'ALICE');
  assert.equal(first.feedback[0]?.kind, 'question');
  assert.ok(Number.isFinite(Date.parse(first.feedback[0]!.createdAt)));
  directory.act(entry, entry.attendees[2]!, false, { action: 'feedback.send', kind: 'great' });
  const teacher = directory.snapshot(entry, true, 'teacher');
  assert.deepEqual(teacher.feedback.map(item => item.userId), ['alice', 'bob']);
  assert.ok(teacher.revision > first.revision);
  assert.deepEqual(directory.snapshot(entry, false, 'bob').feedback.map(item => item.userId), ['bob']);
  assert.deepEqual(directory.snapshot(entry, false).feedback, []);
  assert.throws(() => directory.act(entry, entry.attendees[0]!, true, {
    action: 'feedback.send', kind: 'great',
  }), /Only students/);
  assert.throws(() => directory.act(entry, entry.attendees[0]!, false, {
    action: 'feedback.send', kind: 'great',
  }), /Only students/);
});

test('feedback retries are idempotent and invalid kinds or floods are rejected', () => {
  const entry = room();
  const directory = new ClassroomStateDirectory();
  const request = { action: 'feedback.send', kind: 'understood', eventId: 'feedback-retry-1' };
  const first = directory.act(entry, entry.attendees[1]!, false, request);
  const retry = directory.act(entry, entry.attendees[1]!, false, request);
  assert.equal(retry.revision, first.revision);
  assert.equal(retry.feedback.length, 1);
  assert.throws(() => directory.act(entry, entry.attendees[1]!, false, {
    ...request, kind: 'question',
  }), /Reused eventId/);
  assert.throws(() => directory.act(entry, entry.attendees[1]!, false, {
    action: 'feedback.send', kind: 'arbitrary',
  }), /Unknown classroom feedback/);
  for (const kind of ['great', 'idea', 'question', 'clap']) {
    directory.act(entry, entry.attendees[1]!, false, { action: 'feedback.send', kind });
  }
  assert.throws(() => directory.act(entry, entry.attendees[1]!, false, {
    action: 'feedback.send', kind: 'understood',
  }), /Please wait/);
  assert.equal(directory.snapshot(entry, true).feedback.length, 5);
});

test('recent feedback is bounded, restored by optional persistence and cleared on room cleanup', () => {
  const entry = room();
  let saved: ClassroomStoredState | null = null;
  const store = {
    load: () => saved,
    save: (_: RoomEntry, state: ClassroomStoredState) => { saved = structuredClone(state); },
    delete: () => { saved = null; },
  };
  const directory = new ClassroomStateDirectory(store);
  const originalNow = Date.now;
  let now = originalNow();
  try {
    Date.now = () => now;
    for (let index = 0; index < 205; index++) {
      now += 10_000;
      directory.act(entry, entry.attendees[1]!, false, {
        action: 'feedback.send', kind: 'clap', eventId: `feedback-history-${index}`,
      });
    }
  } finally { Date.now = originalNow; }
  const before = directory.snapshot(entry, true);
  assert.equal(before.feedback.length, 200);
  const restored = new ClassroomStateDirectory(store);
  assert.deepEqual(restored.snapshot(entry, true).feedback, before.feedback);
  restored.forget(entry);
  assert.equal(saved, null);
  assert.equal(restored.snapshot(entry, true).feedback.length, 0);
});
