import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_realtime_sdk_base/flutter_realtime_sdk_base.dart';

class _Media extends Fake implements InteractiveMediaSession {
  final changes = StreamController<MediaSnapshot>.broadcast();
  final calls = <bool>[];
  bool failStart = false, failStop = false, cancel = false;
  MediaSnapshot current = MediaSnapshot(
    capabilities: const MediaCapabilities(canScreenShare: true),
  );
  @override
  MediaSnapshot get snapshot => current;
  @override
  MediaCapabilities get capabilities => current.capabilities;
  @override
  Stream<MediaSnapshot> get snapshots => changes.stream;
  @override
  Future<void> setScreenShareEnabled(bool enabled) async {
    calls.add(enabled);
    if (enabled && failStart || !enabled && failStop) {
      throw StateError('Capture failed');
    }
    if (enabled && cancel) return;
    current = current.copyWith(localScreenShareEnabled: enabled);
    changes.add(current);
  }
}

class _Repository implements ClassroomRepository {
  _Repository(this.whiteboard);
  final WhiteboardState whiteboard;
  int revision = 0;
  bool failCommit = false, teacher = true, legacy = false;
  SharedContentMode mode = SharedContentMode.whiteboard;
  final calls = <String>[];
  ClassroomState get value => ClassroomState(
    roomCode: 'lesson',
    role: teacher ? ClassroomRole.teacher : ClassroomRole.student,
    revision: revision,
    students: const [],
    questions: const [],
    stats: const ClassroomStats(),
    tools: ClassroomToolsState(
      content: legacy
          ? null
          : SharedContentState(
              revision: revision,
              mode: mode,
              whiteboard: whiteboard,
              screen: const AnnotationCanvas(),
              canManage: teacher,
            ),
    ),
  );
  @override
  Future<ClassroomState> snapshot() async => value;
  @override
  Future<ClassroomState> action(
    String type, {
    Map<String, String> data = const {},
  }) async {
    calls.add(type);
    if (failCommit) throw StateError('Commit failed');
    final payload = jsonDecode(data['payload']!) as Map<String, dynamic>;
    if (type == 'tool.content.mode') {
      mode = SharedContentMode.values.byName(payload['mode'] as String);
    }
    revision++;
    return value;
  }

  @override
  void close() {}
}

void main() {
  Future<(_Media, _Repository, ClassroomSession, SharedContentController)>
  fixture({bool screen = false, bool start = true}) async {
    final memory = MemoryWhiteboardRepository();
    final board = await memory.snapshot();
    await memory.close();
    final media = _Media();
    if (screen) {
      media.current = media.current.copyWith(localScreenShareEnabled: true);
    }
    final repo = _Repository(board);
    if (screen) repo.mode = SharedContentMode.screen;
    final classroom = ClassroomSession(
      repo,
      pollInterval: const Duration(hours: 1),
    );
    final controller = SharedContentController(
      media: media,
      classroom: classroom,
    );
    if (start) await controller.start();
    addTearDown(() async {
      await controller.dispose();
      await classroom.dispose();
      await media.changes.close();
    });
    return (media, repo, classroom, controller);
  }

  test(
    'loaded legacy capability invalidates initial pending controls once',
    () async {
      final (media, repo, _, c) = await fixture(start: false);
      repo.legacy = true;
      final updates = <Object?>[];
      final subscription = c.stageUpdates.listen(updates.add);
      media.changes.add(media.snapshot);
      await Future<void>.delayed(Duration.zero);
      await c.start();
      await Future<void>.delayed(Duration.zero);
      expect(updates.length, 2);
      expect(updates.first, isNot(updates.last));
      expect(c.supported, false);
      await subscription.cancel();
    },
  );
  test(
    'screen stop failure preserves screen mode and never commits whiteboard',
    () async {
      final (media, repo, _, c) = await fixture(screen: true);
      media.failStop = true;
      await expectLater(
        c.selectMode(SharedContentMode.whiteboard),
        throwsStateError,
      );
      expect(c.content!.mode, SharedContentMode.screen);
      expect(c.status.captureActive, true);
      expect(repo.calls, isEmpty);
      expect(c.status.busy, false);
      expect(c.status.error, isNotNull);
    },
  );
  test(
    'stopped capture plus commit failure is retryable without restarting capture',
    () async {
      final (media, repo, _, c) = await fixture(screen: true);
      repo.failCommit = true;
      await expectLater(
        c.selectMode(SharedContentMode.whiteboard),
        throwsStateError,
      );
      expect(c.status.captureActive, false);
      expect(c.content!.mode, SharedContentMode.screen);
      expect(media.calls, [false]);
      repo.failCommit = false;
      await c.selectMode(SharedContentMode.whiteboard);
      expect(c.content!.mode, SharedContentMode.whiteboard);
      expect(media.calls, [false]);
    },
  );
  test('cancelled or failed system selection preserves whiteboard', () async {
    final (media, repo, _, c) = await fixture();
    media.cancel = true;
    await expectLater(c.selectMode(SharedContentMode.screen), throwsStateError);
    expect(repo.calls, isEmpty);
    expect(c.content!.mode, SharedContentMode.whiteboard);
    media.cancel = false;
    media.failStart = true;
    await expectLater(c.selectMode(SharedContentMode.screen), throwsStateError);
    expect(repo.calls, isEmpty);
  });
  test(
    'failed screen commit rolls back new capture and reports rollback failure',
    () async {
      final (media, repo, _, c) = await fixture();
      repo.failCommit = true;
      await expectLater(
        c.selectMode(SharedContentMode.screen),
        throwsStateError,
      );
      expect(media.calls, [true, false]);
      expect(c.status.captureActive, false);
      expect(c.content!.mode, SharedContentMode.whiteboard);
      media.failStop = true;
      await expectLater(
        c.selectMode(SharedContentMode.screen),
        throwsStateError,
      );
      expect(c.status.captureActive, true);
      expect('${c.status.error}', contains('Capture remains active'));
      media.failStop = false;
      repo.failCommit = false;
      await c.selectMode(SharedContentMode.members);
      expect(c.status.captureActive, false);
      expect(c.content!.mode, SharedContentMode.members);
    },
  );
  test(
    'successful transitions never invoke camera or microphone APIs; student and legacy blocked',
    () async {
      final (media, repo, classroom, c) = await fixture();
      await c.selectMode(SharedContentMode.screen);
      await c.selectMode(SharedContentMode.whiteboard);
      expect(media.calls, [true, false]);
      expect(c.whiteboard.state!.pages.length, 1);
      repo.teacher = false;
      repo.revision++;
      await classroom.refresh();
      await expectLater(
        c.selectMode(SharedContentMode.members),
        throwsStateError,
      );
      repo.legacy = true;
      repo.revision++;
      await classroom.refresh();
      expect(c.supported, false);
      await expectLater(
        c.selectMode(SharedContentMode.screen),
        throwsUnsupportedError,
      );
    },
  );
}
