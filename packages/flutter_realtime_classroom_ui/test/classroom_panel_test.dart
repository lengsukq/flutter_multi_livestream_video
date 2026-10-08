import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_realtime_classroom_core/flutter_realtime_classroom_core.dart';
import 'package:flutter_realtime_classroom_ui/flutter_realtime_classroom_ui.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeClassroom implements ClassroomRepository {
  FakeClassroom(this.value);
  ClassroomState value;
  final actions = <String>[];
  @override
  Future<ClassroomState> snapshot() async => value;
  @override
  Future<ClassroomState> action(
    String type, {
    Map<String, String> data = const {},
  }) async {
    actions.add(type);
    return value;
  }

  @override
  void close() {}
}

void main() {
  testWidgets('student controls are provided by the SDK UI', (tester) async {
    final repo = FakeClassroom(
      const ClassroomState(
        roomCode: 'class123',
        selfUserId: 'student',
        role: ClassroomRole.student,
        revision: 1,
        students: [
          ClassroomStudent(
            userId: 'student',
            participantId: 's1',
            displayName: 'Student',
            online: true,
            handRaised: false,
            canSpeak: false,
          ),
        ],
        questions: [],
        stats: ClassroomStats(onlineCount: 1),
      ),
    );
    final session = ClassroomSession(
      repo,
      pollInterval: const Duration(hours: 1),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(body: ClassroomPanel(classroom: session)),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('举手'), findsOneWidget);
    await tester.tap(find.text('举手'));
    await tester.pump();
    expect(repo.actions, contains('hand.raise'));
    await tester.pumpWidget(const SizedBox.shrink());
    await session.dispose();
  });

  testWidgets('teacher sees hands and can grant speaking', (tester) async {
    final repo = FakeClassroom(
      const ClassroomState(
        roomCode: 'class123',
        selfUserId: 'teacher',
        role: ClassroomRole.teacher,
        revision: 1,
        students: [
          ClassroomStudent(
            userId: 'student',
            participantId: 's1',
            displayName: 'Student',
            online: true,
            handRaised: true,
            canSpeak: false,
          ),
        ],
        questions: [],
        stats: ClassroomStats(onlineCount: 1, handsRaised: 1),
      ),
    );
    final session = ClassroomSession(
      repo,
      pollInterval: const Duration(hours: 1),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(body: ClassroomPanel(classroom: session)),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Student'), findsOneWidget);
    await tester.tap(find.text('允许发言'));
    await tester.pump();
    expect(repo.actions, contains('speak.grant'));
    await tester.pumpWidget(const SizedBox.shrink());
    await session.dispose();
  });

  testWidgets('English classroom roster can search students', (tester) async {
    final repo = FakeClassroom(
      const ClassroomState(
        roomCode: 'english1',
        selfUserId: 'teacher',
        role: ClassroomRole.teacher,
        revision: 1,
        students: [
          ClassroomStudent(
            userId: 'alice',
            participantId: 'p1',
            displayName: 'Alice',
            online: true,
            handRaised: false,
            canSpeak: false,
          ),
          ClassroomStudent(
            userId: 'bob',
            participantId: 'p2',
            displayName: 'Bob',
            online: true,
            handRaised: false,
            canSpeak: false,
          ),
        ],
        questions: [],
        stats: ClassroomStats(onlineCount: 2),
      ),
    );
    final session = ClassroomSession(
      repo,
      pollInterval: const Duration(hours: 1),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        home: Scaffold(body: ClassroomPanel(classroom: session)),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Students'));
    await tester.pumpAndSettle();
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Bo');
    await tester.pump();
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Alice'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await session.dispose();
  });

  testWidgets('classroom panel fits phone and desktop widths', (tester) async {
    final room = ClassroomState(
      roomCode: 'layout1',
      selfUserId: 'teacher',
      role: ClassroomRole.teacher,
      revision: 1,
      students: const [
        ClassroomStudent(
          userId: 'student1',
          participantId: 'one',
          displayName: 'Student One',
          online: true,
          handRaised: true,
          canSpeak: false,
        ),
      ],
      questions: [
        ClassroomQuestion(
          id: 'q1',
          userId: 'student1',
          displayName: 'Student One',
          text: 'Is this responsive?',
          status: ClassroomQuestionStatus.pending,
          createdAt: DateTime.utc(2026),
        ),
      ],
      stats: const ClassroomStats(
        onlineCount: 2,
        handsRaised: 1,
        pendingQuestions: 1,
        questionsTotal: 1,
      ),
    );
    for (final size in <Size>[
      const Size(360, 700),
      const Size(768, 900),
      const Size(1200, 800),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      final session = ClassroomSession(
        FakeClassroom(room),
        pollInterval: const Duration(hours: 1),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ClassroomPanel(classroom: session)),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'Unexpected layout problem at width ${size.width}',
      );
      await tester.tap(find.text('Q&A'));
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'Q&A layout problem at width ${size.width}',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await session.dispose();
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
