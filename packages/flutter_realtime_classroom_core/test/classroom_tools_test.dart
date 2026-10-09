import 'dart:convert';
import 'package:flutter_realtime_classroom_core/flutter_realtime_classroom_core.dart';
import 'package:test/test.dart';

class Repository implements ClassroomRepository {
  final calls = <(String, Map<String, String>)>[];
  final bool supported;
  Repository({this.supported = true});
  @override
  Future<ClassroomState> snapshot() async => ClassroomState(
    roomCode: 'room1',
    selfUserId: 'teacher',
    role: ClassroomRole.teacher,
    revision: 1,
    students: const [],
    questions: const [],
    stats: const ClassroomStats(),
    tools: supported ? ClassroomToolsState() : null,
  );
  @override
  Future<ClassroomState> action(ClassroomCommand command) {
    calls.add((command.wireName, command.toWireData()));
    return snapshot();
  }

  @override
  void close() {}
}

void main() {
  test(
    'tools delegate structured actions while serializing typed repository commands',
    () async {
      final repository = Repository();
      final session = ClassroomSession(
        repository,
        pollInterval: const Duration(hours: 1),
      );
      await session.start();
      await session.publishAnnouncement('Welcome');
      await session.remindFocus('Focus');
      await session.publishHomework(title: 'Practice', instructions: 'Read');
      await session.shareMaterial(
        title: 'PDF',
        url: 'https://example.test/file.pdf',
      );
      await session.startTimer(
        title: 'Practice',
        duration: const Duration(seconds: 60),
      );
      await session.stopTimer();
      await session.publishActivity(
        kind: ClassroomActivityKind.quiz,
        title: '2+2?',
        options: ['3', '4'],
        correctOption: 1,
      );
      await session.answerActivity('q1', 1);
      await session.closeActivity('q1');
      await session.annotations.setSource('screen');
      await session.annotations.begin(
        AnnotationShape(
          id: 's1',
          tool: AnnotationTool.pen,
          points: [AnnotationPoint(.1, .2)],
        ),
        canvasId: 'canvas1',
      );
      await session.annotations.append('s1', const [
        AnnotationPoint(.2, .3),
      ], canvasId: 'canvas1');
      await session.annotations.undo();
      await session.annotations.clear();
      expect(repository.calls.map((c) => c.$1), [
        'tool.notice.publish',
        'tool.notice.publish',
        'tool.homework.publish',
        'tool.material.share',
        'tool.timer.start',
        'tool.timer.stop',
        'tool.activity.publish',
        'tool.activity.answer',
        'tool.activity.close',
        'tool.annotation.source',
        'tool.annotation.begin',
        'tool.annotation.append',
        'tool.annotation.undo',
        'tool.annotation.clear',
      ]);
      expect(
        jsonDecode(repository.calls[6].$2['payload']!),
        containsPair('correctOption', 1),
      );
      expect(session.state!.withChatMessages(10).tools, isNotNull);
      expect(session.state!.withMedia({}).tools, isNotNull);
      await session.dispose();
    },
  );
  test('a legacy backend does not expose tools or accept tool calls', () async {
    final session = ClassroomSession(Repository(supported: false));
    await session.start();
    expect(session.state!.capabilities.canUseTools, false);
    await expectLater(
      session.publishAnnouncement('Hello'),
      throwsA(
        isA<RealtimeException>().having(
          (e) => e.code,
          'code',
          RealtimeErrorCode.unsupportedFeature,
        ),
      ),
    );
    await session.dispose();
  });
  test('quiz parsing keeps hidden results absent and timer clamps at zero', () {
    final activity = ClassroomActivity.fromJson({
      'id': 'q',
      'kind': 'quiz',
      'title': '?',
      'options': ['A', 'B'],
      'closed': false,
    });
    expect(activity.correctOption, isNull);
    expect(activity.counts, isNull);
    expect(activity.answers, isEmpty);
    final timer = ClassroomTimer(title: 'Practice', endsAt: DateTime.utc(2026));
    expect(timer.remaining(now: DateTime.utc(2027)), Duration.zero);
    expect(
      timer.remaining(now: DateTime.utc(2025, 12, 31, 23, 59, 30)),
      const Duration(seconds: 30),
    );
  });
}
