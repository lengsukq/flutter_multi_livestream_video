import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';

void main() {
  testWidgets('student dock exposes raise and lower directly', (tester) async {
    final repository = _ClassroomRepository(ClassroomRole.student);
    final room = await _initializedRoom(tester, repository);
    addTearDown(room.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: RealtimeRoomUiScope(
          room: room,
          child: const Scaffold(body: RealtimeDockRaiseHandButton()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Raise hand'), findsOneWidget);
    await tester.tap(find.text('Raise hand'));
    await tester.pumpAndSettle();
    expect(repository.actions, contains('hand.raise'));
    expect(find.text('Hand raised'), findsOneWidget);
    await tester.tap(find.text('Hand raised'));
    await tester.pumpAndSettle();
    expect(repository.actions, contains('hand.lower'));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(room.dispose);
  });

  testWidgets('teacher dock shows hand count and panel opens on hands tab', (
    tester,
  ) async {
    final repository = _ClassroomRepository(ClassroomRole.teacher);
    final room = await _initializedRoom(tester, repository);
    addTearDown(room.dispose);
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: RealtimeRoomUiScope(
          room: room,
          child: Scaffold(
            body: Column(
              children: [
                RealtimeDockHandQueueButton(onPressed: () => opened = true),
                const Expanded(child: RealtimeClassroomPanel(initialTab: 1)),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Allow'), findsOneWidget);
    await tester.tap(find.byTooltip('Hand requests: 1'));
    expect(opened, isTrue);
    await tester.tap(find.text('Allow'));
    await tester.pump();
    expect(repository.actions, contains('speak.grant'));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(room.dispose);
  });

  testWidgets('hand queue dock is not shown for students', (tester) async {
    final repository = _ClassroomRepository(ClassroomRole.student);
    final room = await _initializedRoom(tester, repository);
    addTearDown(room.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: RealtimeRoomUiScope(
          room: room,
          child: Scaffold(body: RealtimeDockHandQueueButton(onPressed: () {})),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(RealtimeDockItem), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(room.dispose);
  });

  testWidgets('student hand raise, question and feedback use SDK commands', (
    tester,
  ) async {
    final repository = _ClassroomRepository(ClassroomRole.student);
    final room = await _initializedRoom(tester, repository);
    addTearDown(room.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: RealtimeRoomUiScope(
          room: room,
          child: const Scaffold(
            body: Column(
              children: [
                RealtimeRaiseHandButton(),
                RealtimeClassroomFeedbackButton(),
                Expanded(child: RealtimeClassroomQuestions()),
                RealtimeClassroomQuestionComposer(),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(RealtimeRaiseHandButton), findsOneWidget);
    await tester.tap(find.text('Raise hand'));
    await tester.pump();
    expect(repository.actions, contains('hand.raise'));
    await tester.enterText(find.byType(TextField).first, 'Question from class');
    await tester.tap(find.byTooltip('Ask question'));
    await tester.pump();
    expect(repository.actions, contains('question.ask'));
    await tester.tap(find.byTooltip('Classroom feedback'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('clap').last);
    await tester.pump();
    expect(repository.actions, contains('feedback.send'));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(room.dispose);
  });

  testWidgets('teacher hand queue, Q&A and roster are separately placeable', (
    tester,
  ) async {
    final repository = _ClassroomRepository(ClassroomRole.teacher);
    final room = await _initializedRoom(tester, repository);
    addTearDown(room.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: RealtimeRoomUiScope(
          room: room,
          child: Scaffold(
            body: Column(
              children: [
                const Expanded(child: RealtimeClassroomHandQueue()),
                const Expanded(child: RealtimeClassroomRoster()),
                const Expanded(child: RealtimeClassroomQuestions()),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Allow'), findsOneWidget);
    await tester.tap(find.text('Allow'));
    await tester.pump();
    expect(repository.actions, contains('speak.grant'));
    await tester.tap(find.byTooltip('Manage question'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resolve').last);
    await tester.pump();
    expect(repository.actions, contains('question.resolve'));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(room.dispose);
  });

  testWidgets('teacher answers a question via popup menu and dialog', (
    tester,
  ) async {
    final repository = _ClassroomRepository(ClassroomRole.teacher);
    final room = await _initializedRoom(tester, repository);
    addTearDown(room.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: RealtimeRoomUiScope(
          room: room,
          child: const Scaffold(body: RealtimeClassroomQuestions()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Manage question'), findsOneWidget);
    await tester.tap(find.byTooltip('Manage question'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Answer').last);
    await tester.pumpAndSettle();
    expect(find.text('Answer question'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Here is the answer');
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(repository.actions, contains('question.answer'));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(room.dispose);
  });

  testWidgets('tools button renders dock item with label when enabled', (
    tester,
  ) async {
    final repository = _ClassroomRepository(
      ClassroomRole.teacher,
      withActivity: true,
    );
    final room = await _initializedRoom(tester, repository);
    addTearDown(room.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: RealtimeRoomUiScope(
          room: room,
          child: const Scaffold(
            body: RealtimeClassroomToolsButton(showLabel: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(RealtimeDockItem), findsOneWidget);
    expect(find.byIcon(Icons.build_outlined), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(room.dispose);
  });

  testWidgets(
    'teacher empty questions prompt for student questions and hides composer',
    (tester) async {
      final repository = _ClassroomRepository(
        ClassroomRole.teacher,
        withQuestions: false,
      );
      final room = await _initializedRoom(tester, repository);
      addTearDown(room.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh', 'CN'),
          supportedLocales: RealtimeStrings.supportedLocales,
          localizationsDelegates: RealtimeStrings.localizationsDelegates,
          home: RealtimeRoomUiScope(
            room: room,
            child: const Scaffold(
              body: Column(
                children: [
                  Expanded(child: RealtimeClassroomQuestions()),
                  RealtimeClassroomQuestionComposer(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('暂无课堂提问'), findsOneWidget);
      expect(find.text('学生提问后将在此展示，可直接在此解答'), findsOneWidget);
      expect(find.text('输入问题后点击发送，向老师请教'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(room.dispose);
    },
  );

  testWidgets(
    'student empty questions prompt to ask teacher and shows composer',
    (tester) async {
      final repository = _ClassroomRepository(
        ClassroomRole.student,
        withQuestions: false,
      );
      final room = await _initializedRoom(tester, repository);
      addTearDown(room.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh', 'CN'),
          supportedLocales: RealtimeStrings.supportedLocales,
          localizationsDelegates: RealtimeStrings.localizationsDelegates,
          home: RealtimeRoomUiScope(
            room: room,
            child: const Scaffold(
              body: Column(
                children: [
                  Expanded(child: RealtimeClassroomQuestions()),
                  RealtimeClassroomQuestionComposer(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('暂无课堂提问'), findsOneWidget);
      expect(find.text('输入问题后点击发送，向老师请教'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(room.dispose);
    },
  );

  testWidgets('classroom panel with showHeader false still displays TabBar', (
    tester,
  ) async {
    final repository = _ClassroomRepository(ClassroomRole.teacher);
    final room = await _initializedRoom(tester, repository);
    addTearDown(room.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: RealtimeStrings.supportedLocales,
        localizationsDelegates: RealtimeStrings.localizationsDelegates,
        home: RealtimeRoomUiScope(
          room: room,
          child: const Scaffold(
            body: RealtimeClassroomPanel(showHeader: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.text('提问'), findsOneWidget);
    expect(find.text('举手'), findsOneWidget);
    expect(find.text('花名册'), findsOneWidget);
    expect(find.text('测验'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(room.dispose);
  });

  testWidgets('independent quiz and poll list delegates answer and close', (
    tester,
  ) async {
    final studentRepository = _ClassroomRepository(
      ClassroomRole.student,
      withActivity: true,
    );
    final studentRoom = await _initializedRoom(tester, studentRepository);
    addTearDown(studentRoom.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: RealtimeRoomUiScope(
          room: studentRoom,
          child: const Scaffold(body: RealtimeClassroomActivityList()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blue'));
    await tester.pump();
    expect(studentRepository.actions, contains('tool.activity.answer'));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(studentRoom.dispose);

    final teacherRepository = _ClassroomRepository(
      ClassroomRole.teacher,
      withActivity: true,
    );
    final teacherRoom = await _initializedRoom(tester, teacherRepository);
    addTearDown(teacherRoom.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: RealtimeRoomUiScope(
          room: teacherRoom,
          child: const Scaffold(body: RealtimeClassroomActivityList()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close'));
    await tester.pump();
    expect(teacherRepository.actions, contains('tool.activity.close'));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(teacherRoom.dispose);
  });
}

Future<RealtimeRoom> _initializedRoom(
  WidgetTester tester,
  _ClassroomRepository repository,
) async => (await tester.runAsync(() async {
  // The Classroom session owns a periodic refresh timer and asynchronous
  // cleanup deadlines. Create and start both in the real event loop.
  final room = _room(repository);
  await room.initialize();
  return room;
}))!;

RealtimeRoom _room(_ClassroomRepository repository) => RealtimeRoom(
  media: MediaRoomSession.direct(
    roomCode: 'room-1',
    participantId: 'self',
    session: _MediaSession(),
  ),
  renderer: const _Renderer(),
  featurePlugins: [
    ClassroomPreset(
      enableForDirectRooms: true,
      repositoryFactory: (_) => repository,
      pollInterval: const Duration(hours: 1),
    ),
  ],
  disposeClients: () {},
);

class _Renderer extends MediaTrackRenderer {
  const _Renderer();
  @override
  Widget buildView(BuildContext context, MediaVideoTrack track) =>
      const SizedBox.shrink();
}

class _MediaSession extends Fake implements MediaSession {
  @override
  String get providerId => 'fake';
  @override
  MediaRole get role => MediaRole.participant;
  @override
  MediaCapabilities get capabilities => const MediaCapabilities.meeting();
  @override
  MediaSessionState get state => MediaSessionState.connected;
  @override
  MediaSnapshot get snapshot => MediaSnapshot(
    state: MediaSessionState.connected,
    capabilities: capabilities,
  );
  @override
  Stream<MediaSessionState> get states => const Stream.empty();
  @override
  Stream<MediaSnapshot> get snapshots => const Stream.empty();
  @override
  Stream<MediaEvent> get events => const Stream.empty();
  @override
  Future<void> leave() async {}
  @override
  Future<void> dispose() async {}
}

class _ClassroomRepository implements ClassroomRepository {
  _ClassroomRepository(
    this.role, {
    this.withActivity = false,
    this.withQuestions = true,
  }) : raised = role == ClassroomRole.teacher;
  final ClassroomRole role;
  final bool withActivity;
  final bool withQuestions;
  final actions = <String>[];
  bool raised;
  bool speaking = false;
  int? chosenOption;
  bool closed = false;
  var revision = 0;
  ClassroomState _current() => ClassroomState(
    roomCode: 'room-1',
    role: role,
    selfUserId: role == ClassroomRole.student ? 'self' : 'teacher',
    revision: revision,
    students: [
      ClassroomStudent(
        userId: role == ClassroomRole.student ? 'self' : 'student',
        participantId: 'student',
        displayName: 'Student',
        online: true,
        handRaised: raised,
        canSpeak: speaking,
      ),
    ],
    questions: withQuestions
        ? [
            ClassroomQuestion(
              id: 'question-1',
              userId: 'student',
              displayName: 'Student',
              text: 'Previous question',
              status: ClassroomQuestionStatus.pending,
              createdAt: DateTime(2026),
            ),
          ]
        : const [],
    stats: const ClassroomStats(),
    tools: withActivity
        ? ClassroomToolsState(
            activities: [
              ClassroomActivity(
                id: 'quiz-1',
                kind: ClassroomActivityKind.poll,
                title: 'Your favorite color?',
                options: const ['Blue', 'Red'],
                closed: closed,
                selfAnswer: chosenOption,
              ),
            ],
          )
        : null,
  );
  @override
  Future<ClassroomState> snapshot() async => _current();
  @override
  Future<ClassroomState> action(ClassroomCommand command) async {
    actions.add(command.wireName);
    revision++;
    switch (command.action) {
      case ClassroomAction.handRaise:
        raised = true;
      case ClassroomAction.handLower:
        raised = false;
      case ClassroomAction.speakGrant:
        speaking = true;
      case ClassroomAction.speakRevoke:
        speaking = false;
      default:
        break;
    }
    if (command.tool == ClassroomToolAction.activityAnswer.wireName) {
      chosenOption = command.payload['option'] as int;
    }
    if (command.tool == ClassroomToolAction.activityClose.wireName) {
      closed = true;
    }
    return _current();
  }

  @override
  void close() {}
}
