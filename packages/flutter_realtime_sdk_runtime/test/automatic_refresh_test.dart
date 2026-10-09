import 'dart:async';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

class _ClassRepository implements ClassroomRepository {
  int reads = 0;
  Completer<ClassroomState>? held;
  final value = ClassroomState(
    roomCode: 'r1',
    role: ClassroomRole.student,
    revision: 1,
    students: [],
    questions: [],
    stats: ClassroomStats(),
  );
  @override
  Future<ClassroomState> snapshot() async {
    reads++;
    return held == null ? value : await held!.future;
  }

  @override
  Future<ClassroomState> action(ClassroomCommand command) async => value;
  @override
  void close() {}
}

class _LiveRepository implements LiveInteractionRepository {
  int reads = 0;
  Completer<LiveInteractionState>? held;
  final value = LiveInteractionState(
    roomCode: 'r1',
    revision: 1,
    selfUserId: 's1',
    recipientId: 'host',
    canSendGift: true,
  );
  @override
  Future<LiveInteractionState> snapshot() async {
    reads++;
    return held == null ? value : await held!.future;
  }

  @override
  Future<LiveInteractionState> sendGift(
    String giftId,
    int quantity, {
    required String eventId,
  }) async => value;
  @override
  void close() {}
}

class _Hints implements ClassroomRevisionTransport, LiveRevisionTransport {
  final controller = StreamController<int>.broadcast();
  @override
  Stream<int> get revisions => controller.stream;
  @override
  Future<void> publish(int revision) async {}
  @override
  Future<void> dispose() => controller.close();
}

void main() {
  for (final live in [false, true]) {
    testWidgets(
      '${live ? 'live' : 'classroom'} automatic reads coalesce, remain single flight and stop on dispose',
      (tester) async {
        final hints = _Hints();
        final classroomRepo = _ClassRepository(), liveRepo = _LiveRepository();
        final classroom = ClassroomSession(
          classroomRepo,
          revisionTransport: hints,
        );
        final gifts = LiveInteractionSession(
          liveRepo,
          revisionTransport: hints,
        );
        Future<void> start() => live ? gifts.start() : classroom.start();
        Future<void> refresh() => live ? gifts.refresh() : classroom.refresh();
        Future<void> dispose() => live ? gifts.dispose() : classroom.dispose();
        int reads() => live ? liveRepo.reads : classroomRepo.reads;
        observeDetached(start());
        await tester.pump();
        expect(reads(), 1);
        for (var i = 2; i < 102; i++) {
          hints.controller.add(i);
        }
        await tester.pump();
        expect(reads(), 1);
        await tester.pump(const Duration(milliseconds: 999));
        expect(reads(), 1);
        if (live) {
          liveRepo.held = Completer();
        } else {
          classroomRepo.held = Completer();
        }
        await tester.pump(const Duration(milliseconds: 1));
        expect(reads(), 2);
        for (var i = 102; i < 202; i++) {
          hints.controller.add(i);
        }
        await tester.pump(const Duration(seconds: 2));
        expect(reads(), 2);
        if (live) {
          liveRepo.held!.complete(liveRepo.value);
          liveRepo.held = null;
        } else {
          classroomRepo.held!.complete(classroomRepo.value);
          classroomRepo.held = null;
        }
        await tester.pump();
        expect(reads(), 3);
        observeDetached(refresh());
        await tester.pump();
        expect(reads(), 4);
        hints.controller.add(999);
        await tester.pump();
        final closing = dispose();
        var closed = false;
        unawaited(closing.then((_) => closed = true));
        for (var i = 0; i < 100 && !closed; i++) {
          await tester.pump();
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        }
        expect(closed, true);
        await closing;
        await tester.pump(const Duration(seconds: 10));
        expect(reads(), 4);
        // Dispose the unused session too; it owns no timers or hint subscription.
        if (live) {
          final unused = classroom.dispose();
          await tester.runAsync(() => unused);
        } else {
          final unused = gifts.dispose();
          await tester.runAsync(() => unused);
        }
      },
    );
  }
}
