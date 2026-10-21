import assert from 'node:assert/strict';
import test from 'node:test';
import { mkdtempSync, readdirSync, rmSync, statSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { ClassroomStateDirectory } from '../classroom/classroom-state.ts';
import type { ClassroomStoredState } from '../classroom/classroom-store.ts';
import { FileClassroomStore } from '../classroom/classroom-store.ts';
import type { RoomEntry } from '../types.ts';

test('classroom state and idempotency survive directory recreation', () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), 'classroom-persist-'));
  try {
    const store = new FileClassroomStore(dir);
    const room: RoomEntry = {
      provider: 'livekit', roomCode: 'lesson003', roomMode: 'meeting',
      createdAt: new Date().toISOString(), lastHeartbeatMs: Date.now(),
      classroomTeacherUserId: 'teacher',
      attendees: [
        { attendeeId: 'a1', userId: 'teacher', displayName: 'Teacher',
          externalUserId: 'teacher', joinedAt: new Date().toISOString() },
        { attendeeId: 'a2', userId: 'student', displayName: 'Student',
          externalUserId: 'student', joinedAt: new Date().toISOString() },
      ],
    };
    const teacher = room.attendees[0]!;
    const student = room.attendees[1]!;
    const first = new ClassroomStateDirectory(store);
    first.snapshot(room, true, 'teacher');
    first.act(room, student, false, {
      action: 'hand.raise', eventId: 'hand-on-123',
    });
    const asked = first.act(room, student, false, {
      action: 'question.ask', text: 'Persistent question',
      eventId: 'ask-q-123',
    });
    first.act(room, teacher, true, { action: 'speak.grant', userId: 'student' });
    first.act(room, teacher, true, {
      action: 'note.add', kind: 'chapter', text: 'Find roots',
      eventId: 'chapter-file-001',
    });
    const persistedRevision = first.snapshot(room, true, 'teacher').revision;
    const files = readdirSync(dir);
    assert.equal(files.length, 1);
    if (process.platform !== 'win32') {
      assert.equal(statSync(path.join(dir, files[0]!)).mode & 0o777, 0o600);
    }
    // Simulate a fresh process restoring exactly the same active room.
    const restartedRoom = { ...room, attendees: room.attendees.map(a => ({ ...a })) };
    const afterRestart = new ClassroomStateDirectory(new FileClassroomStore(dir));
    const snapshot = afterRestart.snapshot(restartedRoom, true, 'teacher');
    assert.equal(snapshot.questions.length, 1);
    assert.equal(snapshot.questions[0]?.id, asked.questions[0]?.id);
    assert.equal(snapshot.stats.speakGrants, 1);
    assert.equal(snapshot.students.find(s => s.userId === 'student')?.canSpeak, true);
    assert.equal(snapshot.stats.handRaisesTotal, 1);
    assert.equal(snapshot.notesPersistence, 'file');
    assert.equal(snapshot.notes![0]?.text, 'Find roots');
    assert.equal(snapshot.revision, persistedRevision);
    const replay = afterRestart.act(restartedRoom, student, false, {
      action: 'question.ask', text: 'Persistent question',
      eventId: 'ask-q-123',
    });
    assert.equal(replay.questions.length, 1);
    assert.equal(replay.revision, persistedRevision);
    assert.throws(() => afterRestart.act(restartedRoom, student, false, {
      action: 'question.ask', text: 'Changed payload',
      eventId: 'ask-q-123',
    }), /Reused eventId/);
    // A newly created room with the same human-readable code must not
    // inherit students, grants or questions from the previous room.
    const reusedRoom = {
      ...room, createdAt: new Date(Date.now() + 1000).toISOString(),
    };
    const independent = new ClassroomStateDirectory(store);
    assert.equal(independent.snapshot(reusedRoom, true).questions.length, 0);
    afterRestart.forget(restartedRoom);
    assert.equal(readdirSync(dir).length, 1);
  } finally {
    rmSync(dir, { force: true, recursive: true });
  }
});

test('legacy grants lacking a participant binding are discarded', () => {
  const saved:ClassroomStoredState={version:1,revision:1,raised:[],grants:['s'],questions:[],handledIds:[],questionTimes:[],seenStudents:[],speakGrants:1};
  const room:RoomEntry={provider:'livekit',roomCode:'oldGrant1',roomMode:'meeting',createdAt:new Date().toISOString(),lastHeartbeatMs:Date.now(),
    attendees:[{attendeeId:'new-s',userId:'s',externalUserId:'S',joinedAt:new Date().toISOString()}]};
  const directory=new ClassroomStateDirectory({load:()=>saved,save:()=>{}});
  assert.equal(directory.snapshot(room,false,'s').students[0]?.canSpeak,false);
});
