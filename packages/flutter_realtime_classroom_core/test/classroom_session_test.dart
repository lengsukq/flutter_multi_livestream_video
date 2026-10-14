import 'dart:async';

import 'package:flutter_realtime_classroom_core/flutter_realtime_classroom_core.dart';
import 'package:test/test.dart';

class FakeClassroomRepository implements ClassroomRepository {
  ClassroomState next;
  bool closed = false;
  FakeClassroomRepository(this.next);
  @override
  Future<ClassroomState> snapshot() async => next;
  @override
  Future<ClassroomState> action(ClassroomCommand command) async {
    final type = command.wireName;
    calls.add(type);
    return next;
  }

  final List<String> calls = [];
  @override
  void close() {
    closed = true;
  }
}

class FakeRevisionTransport implements ClassroomRevisionTransport {
  final controller = StreamController<int>.broadcast();
  final sent = <int>[];
  @override
  Stream<int> get revisions => controller.stream;
  @override
  Future<void> publish(int revision) async {
    sent.add(revision);
  }

  @override
  Future<void> dispose() => controller.close();
}

void main() {
  test(
    'coalesced notices retain each item and poll answers/closure reach recipients',
    () async {
      final now = DateTime.utc(2026);
      ClassroomState snapshot(
        int revision,
        ClassroomRole role,
        ClassroomToolsState tools,
      ) => ClassroomState(
        roomCode: 'shared-lesson',
        role: role,
        selfUserId: role == ClassroomRole.teacher ? 'teacher' : 'alice',
        revision: revision,
        students: const [],
        questions: const [],
        stats: const ClassroomStats(),
        tools: tools,
      );
      final teacherRepo = FakeClassroomRepository(
        snapshot(1, ClassroomRole.teacher, ClassroomToolsState()),
      );
      final studentRepo = FakeClassroomRepository(
        snapshot(1, ClassroomRole.student, ClassroomToolsState()),
      );
      final teacher = ClassroomSession(
        teacherRepo,
        pollInterval: const Duration(hours: 1),
      );
      final student = ClassroomSession(
        studentRepo,
        pollInterval: const Duration(hours: 1),
      );
      final teacherNotices = <ClassroomNotification>[];
      final studentNotices = <ClassroomNotification>[];
      final a = teacher.notifications.listen(teacherNotices.add);
      final b = student.notifications.listen(studentNotices.add);
      await teacher.start();
      await student.start();
      final initialTools = ClassroomToolsState(
        notices: [
          ClassroomNotice(
            id: 'n1',
            kind: 'announcement',
            text: 'First',
            createdAt: now,
          ),
          ClassroomNotice(
            id: 'n2',
            kind: 'focus',
            text: 'Second',
            createdAt: now,
          ),
        ],
        activities: [
          ClassroomActivity(
            id: 'poll1',
            kind: ClassroomActivityKind.poll,
            title: 'Question?',
            options: ['A', 'B'],
            closed: false,
          ),
        ],
      );
      teacherRepo.next = snapshot(2, ClassroomRole.teacher, initialTools);
      studentRepo.next = snapshot(2, ClassroomRole.student, initialTools);
      await teacher.refresh();
      await student.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(
        studentNotices
            .where((n) => n.kind == ClassroomNotificationKind.noticePublished)
            .map((n) => n.itemId),
        ['n1', 'n2'],
      );
      expect(
        studentNotices.last.kind,
        ClassroomNotificationKind.activityPublished,
      );

      final responded = ClassroomToolsState(
        notices: initialTools.notices,
        activities: [
          ClassroomActivity(
            id: 'poll1',
            kind: ClassroomActivityKind.poll,
            title: 'Question?',
            options: ['A', 'B'],
            closed: false,
            responseCount: 1,
            selfAnswer: 0,
            answers: {'alice': 0},
          ),
        ],
      );
      teacherRepo.next = snapshot(3, ClassroomRole.teacher, responded);
      studentRepo.next = snapshot(3, ClassroomRole.student, responded);
      await teacher.refresh();
      await student.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(
        teacherNotices.last.kind,
        ClassroomNotificationKind.activityUpdated,
      );
      expect(
        studentNotices.last.kind,
        ClassroomNotificationKind.activityUpdated,
      );
      expect(studentNotices.last.itemId, 'poll1');

      // An answer can be changed without changing responseCount.
      final changedAnswer = ClassroomToolsState(
        notices: initialTools.notices,
        activities: [
          ClassroomActivity(
            id: 'poll1',
            kind: ClassroomActivityKind.poll,
            title: 'Question?',
            options: ['A', 'B'],
            closed: false,
            responseCount: 1,
            selfAnswer: 1,
            answers: {'alice': 1},
          ),
        ],
      );
      teacherRepo.next = snapshot(4, ClassroomRole.teacher, changedAnswer);
      studentRepo.next = snapshot(4, ClassroomRole.student, changedAnswer);
      await teacher.refresh();
      await student.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(
        teacherNotices.where(
          (n) => n.kind == ClassroomNotificationKind.activityUpdated,
        ),
        hasLength(2),
      );
      expect(
        studentNotices.last.kind,
        ClassroomNotificationKind.activityUpdated,
      );

      final finished = ClassroomToolsState(
        notices: initialTools.notices,
        activities: [
          ClassroomActivity(
            id: 'poll1',
            kind: ClassroomActivityKind.poll,
            title: 'Question?',
            options: ['A', 'B'],
            closed: true,
            responseCount: 1,
            selfAnswer: 1,
            answers: {'alice': 1},
          ),
        ],
      );
      studentRepo.next = snapshot(5, ClassroomRole.student, finished);
      await student.refresh();
      await student.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(
        studentNotices.where(
          (n) => n.kind == ClassroomNotificationKind.activityClosed,
        ),
        hasLength(1),
      );

      await a.cancel();
      await b.cancel();
      await teacher.dispose();
      await student.dispose();
    },
  );

  test(
    'teacher and student each observe the other side of classroom actions',
    () async {
      const user = 'alice';
      final allQuestions = <ClassroomQuestion>[];
      var hand = false;
      var speaking = false;
      var revision = 1;
      ClassroomToolsState tools = ClassroomToolsState();
      ClassroomState snapshot(ClassroomRole role) => ClassroomState(
        roomCode: 'shared-lesson',
        role: role,
        selfUserId: role == ClassroomRole.teacher ? 'teacher' : user,
        revision: revision,
        students: [
          ClassroomStudent(
            userId: user,
            participantId: 'p-alice',
            displayName: 'Alice',
            online: true,
            handRaised: hand,
            canSpeak: speaking,
          ),
        ],
        questions: allQuestions,
        stats: const ClassroomStats(),
        tools: tools,
      );
      final teacherRepo = FakeClassroomRepository(
        snapshot(ClassroomRole.teacher),
      );
      final studentRepo = FakeClassroomRepository(
        snapshot(ClassroomRole.student),
      );
      final teacher = ClassroomSession(
        teacherRepo,
        pollInterval: const Duration(hours: 1),
      );
      final student = ClassroomSession(
        studentRepo,
        pollInterval: const Duration(hours: 1),
      );
      final hostEvents = <ClassroomStateEvent>[];
      final studentEvents = <ClassroomStateEvent>[];
      final studentNotices = <ClassroomNotification>[];
      final teacherSubscription = teacher.events.listen(hostEvents.add);
      final studentSubscription = student.events.listen(studentEvents.add);
      final noticeSubscription = student.notifications.listen(
        studentNotices.add,
      );
      Future<void> update(
        ClassroomSession recipient,
        FakeClassroomRepository repo,
        ClassroomRole role,
      ) async {
        repo.next = snapshot(role);
        await recipient.refresh();
        await Future<void>.delayed(Duration.zero);
      }

      await teacher.start();
      await student.start();
      hand = true;
      revision++;
      studentRepo.next = snapshot(ClassroomRole.student);
      await student.raiseHand();
      await update(teacher, teacherRepo, ClassroomRole.teacher);
      expect(hostEvents.last.kind, ClassroomStateEventKind.handRaised);
      expect(hostEvents.last.userId, user);

      speaking = true;
      revision++;
      teacherRepo.next = snapshot(ClassroomRole.teacher);
      await teacher.grantSpeak(user);
      await update(student, studentRepo, ClassroomRole.student);
      expect(studentEvents.last.kind, ClassroomStateEventKind.speakGranted);
      expect(studentNotices.last.kind, ClassroomNotificationKind.speakGranted);

      allQuestions.add(
        ClassroomQuestion(
          id: 'question1',
          userId: user,
          displayName: 'Alice',
          text: 'Can you explain?',
          status: ClassroomQuestionStatus.pending,
          createdAt: DateTime.utc(2026),
        ),
      );
      revision++;
      studentRepo.next = snapshot(ClassroomRole.student);
      await student.askQuestion('Can you explain?');
      await update(teacher, teacherRepo, ClassroomRole.teacher);
      expect(hostEvents.last.kind, ClassroomStateEventKind.questionAsked);

      allQuestions[0] = ClassroomQuestion(
        id: 'question1',
        userId: user,
        displayName: 'Alice',
        text: 'Can you explain?',
        status: ClassroomQuestionStatus.answered,
        answer: 'Of course',
        createdAt: DateTime.utc(2026),
      );
      revision++;
      teacherRepo.next = snapshot(ClassroomRole.teacher);
      await teacher.answerQuestion('question1', 'Of course');
      await update(student, studentRepo, ClassroomRole.student);
      expect(studentEvents.last.kind, ClassroomStateEventKind.questionAnswered);
      expect(
        studentNotices.last.kind,
        ClassroomNotificationKind.questionAnswered,
      );

      tools = ClassroomToolsState(
        notices: [
          ClassroomNotice(
            id: 'n1',
            kind: 'announcement',
            text: 'Class starts',
            createdAt: DateTime.utc(2026),
          ),
        ],
      );
      revision++;
      teacherRepo.next = snapshot(ClassroomRole.teacher);
      await teacher.publishAnnouncement('Class starts');
      await update(student, studentRepo, ClassroomRole.student);
      expect(
        studentNotices.last.kind,
        ClassroomNotificationKind.noticePublished,
      );
      await student.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(
        studentNotices.where(
          (n) => n.kind == ClassroomNotificationKind.noticePublished,
        ),
        hasLength(1),
        reason: 'A repeated snapshot must not repeat a remote notification',
      );

      await teacherSubscription.cancel();
      await studentSubscription.cancel();
      await noticeSubscription.cancel();
      await teacher.dispose();
      await student.dispose();
    },
  );

  ClassroomState state(int revision, {bool hand = false, int questions = 0}) =>
      ClassroomState(
        roomCode: 'room1',
        role: ClassroomRole.teacher,
        revision: revision,
        students: [
          ClassroomStudent(
            userId: 'alice',
            participantId: 'a1',
            displayName: 'Alice',
            online: true,
            handRaised: hand,
            canSpeak: false,
          ),
        ],
        questions: const [],
        stats: ClassroomStats(
          handsRaised: hand ? 1 : 0,
          questionsTotal: questions,
        ),
      );

  test(
    'room state notifies once for a new hand and rejects stale revisions',
    () async {
      final repo = FakeClassroomRepository(state(1));
      final sdk = ClassroomSession(
        repo,
        pollInterval: const Duration(hours: 1),
      );
      final events = <ClassroomNotification>[];
      final subscription = sdk.notifications.listen(events.add);
      final stateEvents = <ClassroomStateEvent>[];
      final eventSubscription = sdk.events.listen(stateEvents.add);
      await sdk.start();
      expect(sdk.state!.stats.handsRaised, 0);
      repo.next = state(2, hand: true);
      await sdk.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(sdk.state!.raisedHands.length, 1);
      expect(events.single.kind, ClassroomNotificationKind.handRaised);
      expect(
        stateEvents.any(
          (event) =>
              event.kind == ClassroomStateEventKind.handRaised &&
              event.userId == 'alice',
        ),
        isTrue,
      );
      expect(sdk.state!.capabilities.canGrantSpeak, isTrue);
      expect(sdk.state!.capabilities.enforcesMicrophone, isFalse);
      repo.next = state(1);
      await sdk.refresh();
      expect(sdk.state!.revision, 2);
      expect(events.length, 1);
      await subscription.cancel();
      await eventSubscription.cancel();
      await sdk.dispose();
      expect(repo.closed, true);
    },
  );

  test('student receives a notification when granted speaking', () async {
    ClassroomState studentState(int revision, bool granted) => ClassroomState(
      roomCode: 'room1',
      role: ClassroomRole.student,
      selfUserId: 'alice',
      revision: revision,
      students: [
        ClassroomStudent(
          userId: 'alice',
          participantId: 'a1',
          displayName: 'Alice',
          online: true,
          handRaised: false,
          canSpeak: granted,
        ),
      ],
      questions: const [],
      stats: const ClassroomStats(onlineCount: 1),
    );
    final repo = FakeClassroomRepository(studentState(1, false));
    final session = ClassroomSession(
      repo,
      pollInterval: const Duration(hours: 1),
    );
    final notifications = <ClassroomNotification>[];
    final subscription = session.notifications.listen(notifications.add);
    await session.start();
    expect(session.state!.capabilities.canGrantSpeak, isFalse);
    repo.next = studentState(2, true);
    await session.refresh();
    await Future<void>.delayed(Duration.zero);
    expect(notifications.map((e) => e.kind), [
      ClassroomNotificationKind.speakGranted,
    ]);
    await subscription.cancel();
    await session.dispose();
  });

  test(
    'actions delegate to the backend and use its authoritative result',
    () async {
      final repo = FakeClassroomRepository(state(3));
      final sdk = ClassroomSession(repo);
      await sdk.start();
      await sdk.raiseHand();
      await sdk.lowerHand();
      await sdk.grantSpeak('alice');
      await sdk.revokeSpeak('alice');
      await sdk.askQuestion('Hello?');
      await sdk.answerQuestion('q1', 'Yes');
      await sdk.resolveQuestion('q1');
      expect(repo.calls, [
        'hand.raise',
        'hand.lower',
        'speak.grant',
        'speak.revoke',
        'question.ask',
        'question.answer',
        'question.resolve',
      ]);
      await sdk.dispose();
    },
  );

  test(
    'revision hints refresh trusted state; actions publish only revisions',
    () async {
      final repo = FakeClassroomRepository(state(1));
      final transport = FakeRevisionTransport();
      final sdk = ClassroomSession(
        repo,
        revisionTransport: transport,
        pollInterval: const Duration(hours: 1),
      );
      await sdk.start();
      repo.next = state(2, hand: true);
      transport.controller.add(2);
      await Future<void>.delayed(const Duration(milliseconds: 1050));
      expect(sdk.state?.revision, 2);
      await sdk.lowerHand();
      expect(transport.sent, [2]);
      await sdk.dispose();
    },
  );
}
