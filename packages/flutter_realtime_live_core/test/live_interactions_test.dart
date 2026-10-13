import 'dart:async';
import 'package:flutter_realtime_live_core/flutter_realtime_live_core.dart';
import 'package:test/test.dart';

LiveGiftEvent event(int sequence) => LiveGiftEvent(
  id: '$sequence',
  sequence: sequence,
  userId: 'alice',
  displayName: 'Alice',
  recipientId: 'host',
  giftId: 'star',
  quantity: 1,
  timestamp: DateTime.utc(2026),
);
LiveInteractionState state(int revision) => LiveInteractionState(
  roomCode: 'live1',
  revision: revision,
  selfUserId: 'alice',
  recipientId: 'host',
  canSendGift: true,
  catalog: const [LiveGift(id: 'star', name: 'Star', icon: 'star')],
  events: [event(revision)],
);

class Repository implements LiveInteractionRepository {
  LiveInteractionState next = state(1);
  final ids = <String>[];
  bool closed = false, fail = false;
  @override
  Future<LiveInteractionState> sendLike({required String eventId}) async {
    ids.add(eventId);
    if (fail) throw StateError('Connection failed');
    return next;
  }

  @override
  Future<LiveInteractionState> snapshot() async => next;
  @override
  Future<LiveInteractionState> sendGift(
    String giftId,
    int quantity, {
    required String eventId,
  }) async {
    ids.add(eventId);
    if (fail) throw StateError('Connection failed');
    return next;
  }

  @override
  void close() {
    closed = true;
  }
}

class Hints implements LiveRevisionTransport {
  final controller = StreamController<int>.broadcast();
  final sent = <int>[];
  @override
  Stream<int> get revisions => controller.stream;
  @override
  Future<void> publish(int revision) async {
    sent.add(revision);
  }

  @override
  Future<void> dispose() => controller.close();
}

void main() {
  test(
    'initial history is quiet; newer revisions animate once even with bounded history',
    () async {
      final repository = Repository();
      final hints = Hints();
      final session = LiveInteractionSession(
        repository,
        revisionTransport: hints,
        pollInterval: const Duration(hours: 1),
      );
      final events = <LiveGiftEvent>[];
      final subscription = session.events.listen(events.add);
      await session.start();
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);
      repository.next = state(2);
      hints.controller.add(2);
      await Future<void>.delayed(const Duration(milliseconds: 1050));
      expect(events.map((e) => e.sequence), [2]);
      await session.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(events.length, 1);
      repository.next = state(1);
      await session.refresh();
      expect(session.state!.revision, 2);
      await subscription.cancel();
      await session.dispose();
      expect(repository.closed, true);
    },
  );
  test(
    'failed gifts can retry their event id and invalid quantity is rejected locally',
    () async {
      final repository = Repository();
      final session = LiveInteractionSession(
        repository,
        pollInterval: const Duration(hours: 1),
      );
      repository.fail = true;
      await expectLater(
        session.sendGift('star', eventId: 'retry-gift-001'),
        throwsA(
          isA<RealtimeException>().having(
            (e) => e.code,
            'code',
            RealtimeErrorCode.invalidState,
          ),
        ),
      );
      repository.fail = false;
      await session.sendGift('star', eventId: 'retry-gift-001');
      expect(repository.ids, ['retry-gift-001', 'retry-gift-001']);
      await expectLater(
        session.sendGift('star', quantity: 100),
        throwsA(
          isA<RealtimeException>().having(
            (e) => e.code,
            'code',
            RealtimeErrorCode.invalidArgument,
          ),
        ),
      );
      await session.dispose();
    },
  );
  test(
    'likes reach all subscribers once; initial history and repeat snapshots do not replay',
    () async {
      final repository = Repository();
      final session = LiveInteractionSession(
        repository,
        pollInterval: const Duration(hours: 1),
      );
      final received = <LiveLikeEvent>[];
      final sub = session.likes.listen(received.add);
      await session.start();
      expect(received, isEmpty);
      final like = LiveLikeEvent(
        id: 'like-1',
        sequence: 2,
        userId: 'bob',
        quantity: 1,
        timestamp: DateTime.utc(2026),
      );
      repository.next = LiveInteractionState(
        roomCode: 'live1',
        revision: 2,
        selfUserId: 'alice',
        recipientId: 'host',
        canSendGift: true,
        totalLikes: 1,
        likeEvents: [like],
      );
      await session.refresh();
      await session.refresh();
      expect(received.map((e) => e.id), ['like-1']);
      expect(session.state!.totalLikes, 1);
      repository.fail = true;
      await expectLater(
        session.sendLike(eventId: 'retry-like-001'),
        throwsA(isA<Exception>()),
      );
      expect(session.state!.totalLikes, 1);
      repository.fail = false;
      await session.sendLike(eventId: 'retry-like-001');
      expect(repository.ids, ['retry-like-001', 'retry-like-001']);
      expect(received.length, 1);
      await sub.cancel();
      await session.dispose();
    },
  );
}
