import 'dart:async';

import 'package:flutter_realtime_classroom_core/flutter_realtime_classroom_core.dart';
import 'package:test/test.dart';

ClassroomFeedback feedback(String id, ClassroomFeedbackKind kind) =>
    ClassroomFeedback(
      id: id,
      userId: 'alice',
      displayName: 'Alice',
      kind: kind,
      createdAt: DateTime.utc(2026, 10, 9, 10),
    );

ClassroomState state(
  int revision, {
  bool teacher = true,
  bool supported = true,
  List<ClassroomFeedback> feedback = const [],
}) => ClassroomState(
  roomCode: 'lesson1',
  role: teacher ? ClassroomRole.teacher : ClassroomRole.student,
  selfUserId: teacher ? 'teacher' : 'alice',
  revision: revision,
  students: const [],
  questions: const [],
  stats: const ClassroomStats(),
  feedbackSupported: supported,
  feedback: feedback,
);

class _Repository implements ClassroomRepository {
  _Repository(this.value);
  ClassroomState value;
  final commands = <ClassroomCommand>[];
  @override
  Future<ClassroomState> snapshot() async => value;
  @override
  Future<ClassroomState> action(ClassroomCommand command) async {
    commands.add(command);
    return value;
  }

  @override
  void close() {}
}

class _Transport implements ClassroomRevisionTransport {
  final controller = StreamController<int>.broadcast();
  final published = <int>[];
  @override
  Stream<int> get revisions => controller.stream;
  @override
  Future<void> publish(int revision) async {
    published.add(revision);
  }

  @override
  Future<void> dispose() => controller.close();
}

void main() {
  test(
    'teacher notifications contain each new response once, without replaying history',
    () async {
      final historic = feedback('old', ClassroomFeedbackKind.great);
      final repo = _Repository(state(1, feedback: [historic]));
      final session = ClassroomSession(
        repo,
        pollInterval: const Duration(hours: 1),
      );
      final notifications = <ClassroomNotification>[];
      final events = <ClassroomStateEvent>[];
      final n = session.notifications.listen(notifications.add);
      final e = session.events.listen(events.add);
      await session.start();
      await Future<void>.delayed(Duration.zero);
      expect(notifications, isEmpty);
      repo.value = state(
        2,
        feedback: [
          historic,
          feedback('new-1', ClassroomFeedbackKind.question),
          feedback('new-2', ClassroomFeedbackKind.idea),
        ],
      );
      await session.refresh();
      await session.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(
        notifications.single.kind,
        ClassroomNotificationKind.feedbackReceived,
      );
      expect(notifications.single.feedback.map((item) => item.id), [
        'new-1',
        'new-2',
      ]);
      expect(events.map((item) => item.feedbackId), ['new-1', 'new-2']);
      repo.value = state(1);
      await session.refresh();
      expect(session.state!.feedback, hasLength(3));
      expect(notifications, hasLength(1));
      expect(session.state!.withMedia({}).feedback, hasLength(3));
      expect(
        session.state!.withChatMessages(5).capabilities.canViewFeedback,
        isTrue,
      );
      await n.cancel();
      await e.cancel();
      await session.dispose();
    },
  );

  test(
    'student submits typed feedback and publishes only the accepted revision',
    () async {
      final repo = _Repository(state(1, teacher: false));
      final transport = _Transport();
      final session = ClassroomSession(
        repo,
        revisionTransport: transport,
        pollInterval: const Duration(hours: 1),
      );
      await session.start();
      repo.value = state(
        2,
        teacher: false,
        feedback: [feedback('one', ClassroomFeedbackKind.understood)],
      );
      await session.sendFeedback(ClassroomFeedbackKind.understood);
      expect(repo.commands.single.wireName, 'feedback.send');
      expect(repo.commands.single.toWireData(), {'kind': 'understood'});
      expect(transport.published, [2]);
      expect(session.state!.feedback.single.id, 'one');
      await session.dispose();
    },
  );

  test('teacher and unsupported repositories cannot send feedback', () async {
    for (final teacher in [true, false]) {
      final repo = _Repository(state(1, teacher: teacher, supported: teacher));
      final session = ClassroomSession(
        repo,
        pollInterval: const Duration(hours: 1),
      );
      await session.start();
      await expectLater(
        session.sendFeedback(ClassroomFeedbackKind.clap),
        throwsA(
          isA<RealtimeException>().having(
            (error) => error.code,
            'code',
            teacher
                ? RealtimeErrorCode.forbidden
                : RealtimeErrorCode.unsupportedFeature,
          ),
        ),
      );
      expect(repo.commands, isEmpty);
      expect(session.state!.capabilities.canSendFeedback, isFalse);
      await session.dispose();
    }
  });

  test('legacy snapshots disable feedback and typed records parse safely', () {
    final base = <String, dynamic>{
      'roomCode': 'lesson1',
      'role': 'student',
      'revision': 1,
      'students': <Object>[],
      'questions': <Object>[],
      'stats': <String, Object>{},
    };
    expect(ClassroomState.fromJson(base).capabilities.canSendFeedback, isFalse);
    final parsed = ClassroomState.fromJson({
      ...base,
      'feedbackSupported': true,
      'feedback': [
        {
          'id': 'one',
          'userId': 'alice',
          'displayName': 'Alice',
          'kind': 'question',
          'createdAt': '2026-10-09T10:00:00Z',
        },
      ],
    });
    expect(parsed.capabilities.canSendFeedback, isTrue);
    expect(parsed.feedback.single.kind, ClassroomFeedbackKind.question);
    expect(() => parsed.feedback.clear(), throwsUnsupportedError);
  });
}
