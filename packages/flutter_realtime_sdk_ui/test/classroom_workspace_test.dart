import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';

/// One raise-hand entry per role and a teacher queue that actually opens.
void main() {
  testWidgets(
    'teacher is notified outside panels and student receives speaking permission',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(780, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final authority = _ClassAuthority();
      final teacher = await _room(tester, _ClassClient(authority, true));
      final student = await _room(tester, _ClassClient(authority, false));
      addTearDown(teacher.dispose);
      addTearDown(student.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Row(
            children: [
              Expanded(child: RealtimeMeetingPage(room: teacher)),
              Expanded(child: RealtimeMeetingPage(room: student)),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RealtimeMeetingSidePanel), findsNothing);
      await student.classroom!.raiseHand();
      await teacher.classroom!.refresh();
      await tester.pump();
      expect(find.text('Student raised a hand'), findsOneWidget);
      expect(find.byTooltip('Hand requests: 1'), findsOneWidget);
      await teacher.classroom!.refresh();
      await tester.pump();
      expect(find.text('Student raised a hand'), findsOneWidget);
      await teacher.classroom!.grantSpeak('student');
      await student.classroom!.refresh();
      await tester.pump();
      expect(
        find.text('Teacher allowed you to speak. Turn on your microphone.'),
        findsOneWidget,
      );
      expect(find.byTooltip('Hand requests: 0'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        await teacher.dispose();
        await student.dispose();
      });
    },
  );

  Future<RealtimeRoom> teacherRoom(WidgetTester tester) async =>
      _room(tester, _RaisedHandRepository(ClassroomRole.teacher, 'teacher'));

  Future<RealtimeRoom> studentRoom(WidgetTester tester) async =>
      _room(tester, _RaisedHandRepository(ClassroomRole.student, 'student'));

  for (final size in const [Size(390, 844), Size(768, 900), Size(1280, 820)]) {
    testWidgets('teacher sees a single hand queue entry at ${size.width}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final room = await teacherRoom(tester);
      addTearDown(room.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: RealtimeStrings.supportedLocales,
          localizationsDelegates: RealtimeStrings.localizationsDelegates,
          theme: RealtimeUiTheme.light(),
          home: RealtimeMeetingPage(room: room),
        ),
      );
      await tester.pumpAndSettle();

      // The student control is mounted but collapses to nothing for a
      // teacher; only the queue entry may be rendered.
      expect(find.text('Raise hand'), findsNothing);
      expect(find.byType(RealtimeDockHandQueueButton), findsOneWidget);
      // The student raise action must not leak onto the teacher rail or the
      // More menu as a second, inert entry.
      expect(
        find.descendant(
          of: find.byType(RealtimeMeetingRail),
          matching: find.byTooltip('Raise hand'),
        ),
        findsNothing,
      );
    });

    testWidgets('student sees a single raise hand entry at ${size.width}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final room = await studentRoom(tester);
      addTearDown(room.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: RealtimeStrings.supportedLocales,
          localizationsDelegates: RealtimeStrings.localizationsDelegates,
          theme: RealtimeUiTheme.light(),
          home: RealtimeMeetingPage(room: room),
        ),
      );
      await tester.pumpAndSettle();

      // Dock controls are icon-only below the large breakpoint, so the label
      // lives in the tooltip.
      expect(find.byTooltip('Raise hand'), findsOneWidget);
      expect(find.byType(RealtimeDockHandQueueButton), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(RealtimeMeetingDock),
          matching: find.byType(RealtimeDockRaiseHandButton),
        ),
        findsOneWidget,
      );
      if (size.width < 600) {
        // Phones used to expose a second raise-hand item in the More menu.
        final more = find.byType(RealtimeDockMoreButton);
        await tester.ensureVisible(more);
        await tester.pumpAndSettle();
        await tester.tap(more);
        await tester.pumpAndSettle();
        expect(find.text('Raise hand'), findsNothing);
        expect(find.text('Hands'), findsNothing);
        await tester.tapAt(const Offset(20, 40));
        await tester.pumpAndSettle();
      }
    });
  }

  testWidgets('teacher hand queue opens the hands tab from the desktop dock', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final room = await teacherRoom(tester);
    addTearDown(room.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: RealtimeStrings.supportedLocales,
        localizationsDelegates: RealtimeStrings.localizationsDelegates,
        theme: RealtimeUiTheme.light(),
        home: RealtimeMeetingPage(room: room),
      ),
    );
    await tester.pumpAndSettle();

    final handRequests = find.byTooltip('Hand requests: 1');
    await tester.ensureVisible(handRequests);
    await tester.pumpAndSettle();
    await tester.tap(handRequests);
    await tester.pumpAndSettle();

    expect(find.byType(RealtimeMeetingSidePanel), findsOneWidget);
    expect(find.byType(RealtimeClassroomSidePanel), findsOneWidget);
    // The queue content, not Q&A or People, must be the visible tab.
    expect(find.byType(RealtimeClassroomHandQueue), findsOneWidget);
    expect(find.text('Student'), findsOneWidget);
    expect(find.text('Allow'), findsOneWidget);
  });
}

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

class _RaisedHandRepository implements ClassroomRepository {
  _RaisedHandRepository(this.role, this.selfUserId);

  final ClassroomRole role;
  final String selfUserId;

  ClassroomState _snapshot() => ClassroomState(
    roomCode: 'classroom-1',
    role: role,
    selfUserId: selfUserId,
    revision: 1,
    students: [
      ClassroomStudent(
        userId: role == ClassroomRole.teacher ? 'student' : selfUserId,
        participantId: role == ClassroomRole.teacher ? 'student' : selfUserId,
        displayName: 'Student',
        online: true,
        handRaised: role == ClassroomRole.teacher,
        canSpeak: false,
      ),
    ],
    questions: const [],
    stats: const ClassroomStats(),
  );

  @override
  Future<ClassroomState> snapshot() async => _snapshot();

  @override
  Future<ClassroomState> action(ClassroomCommand command) async => _snapshot();

  @override
  void close() {}
}

Future<RealtimeRoom> _room(
  WidgetTester tester,
  ClassroomRepository repository,
) async => (await tester.runAsync(() async {
  final room = RealtimeRoom(
    media: MediaRoomSession.direct(
      roomCode: 'classroom-1',
      participantId: repository is _RaisedHandRepository
          ? repository.selfUserId
          : 'self',
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
  await room.initialize();
  return room;
}))!;

class _ClassAuthority {
  bool raised = false, canSpeak = false;
  int revision = 0;
}

class _ClassClient implements ClassroomRepository {
  _ClassClient(this.authority, this.teacher);
  final _ClassAuthority authority;
  final bool teacher;
  @override
  Future<ClassroomState> snapshot() async => ClassroomState(
    roomCode: 'class',
    role: teacher ? ClassroomRole.teacher : ClassroomRole.student,
    selfUserId: teacher ? 'teacher' : 'student',
    revision: authority.revision,
    students: [
      ClassroomStudent(
        userId: 'student',
        participantId: 'student',
        displayName: 'Student',
        online: true,
        handRaised: authority.raised,
        canSpeak: authority.canSpeak,
      ),
    ],
    questions: const [],
    stats: const ClassroomStats(),
  );
  @override
  Future<ClassroomState> action(ClassroomCommand command) async {
    if (command.action == ClassroomAction.handRaise) authority.raised = true;
    if (command.action == ClassroomAction.speakGrant) {
      authority.canSpeak = true;
      authority.raised = false;
    }
    authority.revision++;
    return snapshot();
  }

  @override
  void close() {}
}
