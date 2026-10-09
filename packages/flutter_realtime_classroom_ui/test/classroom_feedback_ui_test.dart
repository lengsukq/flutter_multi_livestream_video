import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_realtime_classroom_core/flutter_realtime_classroom_core.dart';
import 'package:flutter_realtime_classroom_ui/flutter_realtime_classroom_ui.dart';
import 'package:flutter_test/flutter_test.dart';

class _Store {
  int revision = 1;
  final feedback = <ClassroomFeedback>[];
  final signals = StreamController<int>.broadcast();
}

class _Repository implements ClassroomRepository {
  _Repository(this.store, {this.teacher = false, this.supported = true});
  final _Store store;
  final bool teacher, supported;
  Future<void>? pending;
  final commands = <ClassroomCommand>[];
  @override
  Future<ClassroomState> snapshot() async => ClassroomState(
    roomCode: 'lesson1',
    selfUserId: teacher ? 'teacher' : 'alice',
    role: teacher ? ClassroomRole.teacher : ClassroomRole.student,
    revision: store.revision,
    students: const [],
    questions: const [],
    stats: const ClassroomStats(),
    feedbackSupported: supported,
    feedback: store.feedback,
  );
  @override
  Future<ClassroomState> action(ClassroomCommand command) async {
    commands.add(command);
    await pending;
    store.feedback.add(
      ClassroomFeedback(
        id: 'feedback-${store.revision}',
        userId: 'alice',
        displayName: 'Alice',
        kind: ClassroomFeedbackKind.values.byName(command.arguments['kind']!),
        createdAt: DateTime.utc(2026, 10, 9, 10),
      ),
    );
    store.revision++;
    return snapshot();
  }

  @override
  void close() {}
}

class _Transport implements ClassroomRevisionTransport {
  _Transport(this.store);
  final _Store store;
  @override
  Stream<int> get revisions => store.signals.stream;
  @override
  Future<void> publish(int revision) async => store.signals.add(revision);
  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets(
    'student sends feedback, teacher sees a bubble and opens retained history',
    (tester) async {
      final store = _Store();
      final studentRepo = _Repository(store);
      final teacher = ClassroomSession(
        _Repository(store, teacher: true),
        revisionTransport: _Transport(store),
        pollInterval: const Duration(hours: 1),
      );
      final student = ClassroomSession(
        studentRepo,
        revisionTransport: _Transport(store),
        pollInterval: const Duration(hours: 1),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(child: ClassroomPanel(classroom: student)),
                ClassroomControlButton(classroom: teacher),
              ],
            ),
          ),
        ),
      );
      // Keep pumping bounded: the session owns polling/timers and must not
      // require every animation to settle before interacting.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Puzzled'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(studentRepo.commands.single.wireName, 'feedback.send');
      expect(studentRepo.commands.single.arguments, {'kind': 'question'});
      expect(find.text('Alice sent feedback: Puzzled'), findsOneWidget);
      expect(find.text('View feedback'), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // Unread classroom badge.
      await tester.tap(find.text('View feedback'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byKey(const ValueKey('classroom-feedback-feedback-1')),
        findsOneWidget,
      );
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Recent classroom feedback'), findsOneWidget);
      expect(find.text('Alice sent feedback: Puzzled'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await student.dispose();
        await teacher.dispose();
        await store.signals.close();
      });
    },
  );

  testWidgets('failed feedback never claims success and can be retried', (
    tester,
  ) async {
    final store = _Store();
    final gate = Completer<void>();
    final repo = _Repository(store)..pending = gate.future;
    final session = ClassroomSession(
      repo,
      pollInterval: const Duration(hours: 1),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ClassroomPanel(classroom: session)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Awesome'));
    await tester.pump();
    expect(find.textContaining('Feedback sent'), findsNothing);
    await tester.tap(find.text('Awesome'));
    expect(repo.commands, hasLength(1));
    gate.completeError(const RealtimeException(
      code: RealtimeErrorCode.network, message: 'Feedback delivery failed'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    // The SDK normalizes provider exceptions; the UI must show the safe,
    // provider-independent operation failure, not raw provider text.
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.textContaining('Feedback sent'), findsNothing);
    repo.pending = null;
    await tester.tap(find.text('Awesome'));
    await tester.pump();
    await tester.pump();
    expect(repo.commands, hasLength(2));
    expect(session.state!.feedback, hasLength(1));
    expect(find.textContaining('Feedback sent'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await session.dispose();
      await store.signals.close();
    });
  });

  testWidgets(
    'bubble expires while history remains and overlay is cleaned up',
    (tester) async {
      final store = _Store();
      final teacher = ClassroomSession(
        _Repository(store, teacher: true),
        pollInterval: const Duration(hours: 1),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: ClassroomOverlayButton(classroom: teacher)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      store.feedback.add(
        ClassroomFeedback(
          id: 'one',
          userId: 'alice',
          displayName: 'Alice',
          kind: ClassroomFeedbackKind.idea,
          createdAt: DateTime.utc(2026),
        ),
      );
      store.revision++;
      await teacher.refresh();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Alice sent feedback: Idea'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Alice sent feedback: Idea'), findsNothing);
      expect(teacher.state!.feedback.single.id, 'one');
      store.feedback.add(
        ClassroomFeedback(
          id: 'two',
          userId: 'alice',
          displayName: 'Alice',
          kind: ClassroomFeedbackKind.clap,
          createdAt: DateTime.utc(2026),
        ),
      );
      store.revision++;
      await teacher.refresh();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        await teacher.dispose();
        await store.signals.close();
      });
    },
  );

  testWidgets('unsupported feedback is disabled instead of faking a send', (
    tester,
  ) async {
    final store = _Store();
    final repo = _Repository(store, supported: false);
    final session = ClassroomSession(
      repo,
      pollInterval: const Duration(hours: 1),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ClassroomPanel(classroom: session)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Understood'));
    expect(repo.commands, isEmpty);
    expect(
      find.text('Quick feedback is unavailable in this classroom.'),
      findsOneWidget,
    );
    expect(find.textContaining('Feedback sent'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await session.dispose();
      await store.signals.close();
    });
  });
}
