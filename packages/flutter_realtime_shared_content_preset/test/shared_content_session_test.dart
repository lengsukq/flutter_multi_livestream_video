import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_realtime_shared_content_preset/flutter_realtime_shared_content_preset.dart';

void main() {
  test(
    'synchronization errors remain observable and stop after disposal',
    () async {
      final repo = await _Repository.create();
      final session = SharedContentSession(repo, pollInterval: null);
      final errors = <RealtimeException>[];
      final sub = session.errors.listen(errors.add);
      await session.start();
      repo.updates.addError(StateError('sync failed'), StackTrace.current);
      await pumpEventQueue();
      expect(errors, hasLength(1));
      expect(session.lastError, same(errors.single));
      await session.refresh();
      expect(session.lastError, isNull);
      await session.dispose();
      await sub.cancel();
      expect(repo.closes, 1);
    },
  );

  test(
    'disposal waits for an in-flight command and rejects subsequent starts',
    () async {
      final repo = await _Repository.create();
      final session = SharedContentSession(repo, pollInterval: null);
      await session.start();
      repo.pendingAction = Completer<SharedContentState>();
      final action = session.setSource('new');
      var closed = false;
      final disposal = session.dispose().then((_) => closed = true);
      await pumpEventQueue();
      expect(closed, false);
      repo.pendingAction!.complete(repo.snapshotAt(1, 'new'));
      await action;
      await disposal;
      expect(repo.closes, 1);
      await expectLater(session.start(), throwsA(isA<RealtimeException>()));
    },
  );

  test(
    'an older in-flight snapshot cannot overwrite a newer canvas edit',
    () async {
      final repo = await _Repository.create();
      final session = SharedContentSession(repo, pollInterval: null);
      await session.start();
      repo.pending = Completer<SharedContentState>();
      final refresh = session.refresh();
      await session.execute(
        SharedContentCommand(SharedContentAction.source, {'sourceKey': 'new'}),
      );
      repo.pending!.complete(repo.snapshotAt(1, 'old'));
      await refresh;
      expect(session.canvas.sourceKey, 'new');
      await session.dispose();
    },
  );

  test(
    'a failed snapshot can be retried and disposal is shared and closes once',
    () async {
      final repo = await _Repository.create();
      repo.fail = true;
      final session = SharedContentSession(repo, pollInterval: null);
      await expectLater(session.start(), throwsA(isA<StateError>()));
      repo.fail = false;
      await session.start();
      expect(session.state, isNotNull);
      final first = session.dispose();
      expect(identical(first, session.dispose()), isTrue);
      await first;
      expect(repo.closes, 1);
      await expectLater(session.refresh(), throwsA(isA<RealtimeException>()));
    },
  );

  test(
    'canvas and content commands retain separate revision semantics',
    () async {
      final repo = await _Repository.create();
      final session = SharedContentSession(repo, pollInterval: null);
      await session.start();
      await session.setSource('new');
      expect(session.state!.revision, 0);
      expect(session.state!.snapshotRevision, 2);
      expect(session.canvas.sourceKey, 'new');
      await session.dispose();
    },
  );
}

class _Repository extends SharedContentRepository {
  _Repository(this.board);
  final WhiteboardState board;
  Completer<SharedContentState>? pending;
  Completer<SharedContentState>? pendingAction;
  final updates = StreamController<SharedContentState>.broadcast();
  @override
  Stream<SharedContentState> get states => updates.stream;
  bool fail = false;
  int closes = 0;
  static Future<_Repository> create() async {
    final memory = MemoryWhiteboardRepository();
    final board = await memory.snapshot();
    await memory.close();
    return _Repository(board);
  }

  SharedContentState snapshotAt(int revision, String source) =>
      SharedContentState(
        mode: SharedContentMode.screen,
        whiteboard: board,
        screen: AnnotationCanvas(sourceKey: source),
        canManage: true,
        snapshotRevision: revision,
      );
  @override
  Future<SharedContentState> snapshot() async {
    if (fail) throw StateError('snapshot failed');
    return pending?.future ?? snapshotAt(0, 'initial');
  }

  @override
  Future<SharedContentState> action(SharedContentCommand command) async =>
      pendingAction?.future ?? snapshotAt(2, 'new');
  @override
  Future<void> close() async {
    closes++;
    await updates.close();
  }
}
