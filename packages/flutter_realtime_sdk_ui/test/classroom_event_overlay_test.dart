import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';

void main() {
  testWidgets('student gets a microphone reminder after speaking grant', (
    tester,
  ) async {
    final repo = _TestRepository()..role = ClassroomRole.student;
    final session = ClassroomSession(
      repo,
      pollInterval: const Duration(hours: 1),
    );
    await session.start();
    await tester.pumpWidget(_app(session));

    repo.canSpeak = true;
    repo.revision++;
    await session.refresh();
    await tester.pumpAndSettle();
    expect(
      find.text('Teacher allowed you to speak. Turn on your microphone.'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await session.dispose();
  });

  testWidgets('renders named hand-raise events only after initial state', (
    tester,
  ) async {
    final repo = _TestRepository();
    final session = ClassroomSession(
      repo,
      pollInterval: const Duration(hours: 1),
    );
    await session.start();
    await tester.pumpWidget(_app(session));
    expect(find.byType(Card), findsNothing);

    await session.raiseHand();
    await tester.pumpAndSettle();
    expect(find.text('Student raised a hand'), findsOneWidget);

    await session.lowerHand();
    await tester.pumpAndSettle();
    expect(find.text('Student lowered a hand'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await session.dispose();
  });

  testWidgets(
    'homework notifications and timer are visible outside tools panel',
    (tester) async {
      final repo = _TestRepository();
      final session = ClassroomSession(
        repo,
        pollInterval: const Duration(hours: 1),
      );
      await session.start();
      await tester.pumpWidget(_app(session));

      await session.publishHomework(title: 'Exercises', instructions: '1-5');
      await tester.pumpAndSettle();
      expect(find.text('Homework published: Exercises'), findsOneWidget);

      await session.startTimer(
        title: 'Break',
        duration: const Duration(minutes: 2),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('classroom-shared-timer')), findsOneWidget);
      expect(find.text('Break'), findsOneWidget);
      expect(find.text('Timer started: Break'), findsOneWidget);

      await session.stopTimer();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('classroom-shared-timer')), findsNothing);
      expect(find.text('Classroom timer stopped'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await session.dispose();
    },
  );

  testWidgets('late joiners see timer without replaying old notifications', (
    tester,
  ) async {
    final repo = _TestRepository()
      ..timer = ClassroomTimer(
        title: 'Exam',
        endsAt: DateTime.now().add(const Duration(minutes: 8)),
      );
    final session = ClassroomSession(
      repo,
      pollInterval: const Duration(hours: 1),
    );
    await session.start();
    await tester.pumpWidget(_app(session));
    expect(find.text('Exam'), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await session.dispose();
  });
}

Widget _app(ClassroomSession classroom) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.topCenter,
      child: RealtimeClassroomEventOverlay(classroom: classroom),
    ),
  ),
);

class _TestRepository implements ClassroomRepository {
  bool raised = false;
  bool canSpeak = false;
  ClassroomRole role = ClassroomRole.teacher;
  int revision = 0;
  ClassroomTimer? timer;
  final List<ClassroomHomework> homework = [];

  ClassroomState _snapshot() => ClassroomState(
    roomCode: 'test-room',
    role: role,
    selfUserId: role == ClassroomRole.teacher ? 'teacher' : 'student-1',
    revision: revision,
    students: [
      ClassroomStudent(
        userId: 'student-1',
        participantId: 'student-1',
        displayName: 'Student',
        online: true,
        handRaised: raised,
        canSpeak: canSpeak,
      ),
    ],
    questions: const [],
    stats: const ClassroomStats(),
    tools: ClassroomToolsState(homework: homework, timer: timer),
  );

  @override
  Future<ClassroomState> snapshot() async => _snapshot();

  @override
  Future<ClassroomState> action(ClassroomCommand command) async {
    revision++;
    if (command.action == ClassroomAction.handRaise) raised = true;
    if (command.action == ClassroomAction.handLower) raised = false;
    if (command.tool == ClassroomToolAction.homeworkPublish.wireName) {
      homework.add(
        ClassroomHomework(
          id: 'homework-${homework.length}',
          title: command.payload['title']! as String,
          instructions: command.payload['instructions']! as String,
        ),
      );
    }
    if (command.tool == ClassroomToolAction.timerStart.wireName) {
      timer = ClassroomTimer(
        title: command.payload['title']! as String,
        endsAt: DateTime.now().add(
          Duration(seconds: command.payload['seconds']! as int),
        ),
      );
    }
    if (command.tool == ClassroomToolAction.timerStop.wireName) timer = null;
    return _snapshot();
  }

  @override
  void close() {}
}
