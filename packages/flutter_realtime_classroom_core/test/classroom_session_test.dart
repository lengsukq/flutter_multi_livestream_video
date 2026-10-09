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
