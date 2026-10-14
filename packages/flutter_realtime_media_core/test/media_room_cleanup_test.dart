import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_media_session.dart';

void main() {
  test('failed media leave still notifies presence exactly once', () async {
    final media = _FailingLeave();
    final backend = _Backend();
    final room = _attach(media, backend);
    final first = room.leave();
    final second = room.leave();
    expect(identical(first, second), isTrue);
    await expectLater(first, throwsA(isA<RealtimeException>()));
    expect(media.leaveCount, 1);
    expect(backend.leaves, 1);
    await room.dispose();
    expect(backend.leaves, 1);
  });

  test(
    'closed backend reports local cleanup failure without failing close',
    () async {
      final media = _FailingLeave();
      final backend = _Backend();
      final room = _attach(media, backend);
      final errors = <RealtimeException>[];
      var done = false;
      final subscription = room.cleanupErrors.listen(
        errors.add,
        onDone: () => done = true,
      );
      await room.closeRoom();
      await Future<void>.delayed(Duration.zero);
      expect(backend.closes, 1);
      expect(backend.leaves, 0);
      expect(errors.single.code, RealtimeErrorCode.cleanupFailed);
      expect(errors.single.operation, 'closeRoom.localLeave');
      expect(errors.single.details, containsPair('roomClosed', true));
      expect(errors.single.message, isNot(contains('private native payload')));
      final lateErrors = <RealtimeException>[];
      final lateSubscription = room.cleanupErrors.listen(lateErrors.add);
      await Future<void>.delayed(Duration.zero);
      expect(lateErrors, isEmpty);
      await room.dispose();
      expect(done, isTrue);
      await subscription.cancel();
      await lateSubscription.cancel();
    },
  );
}

MediaRoomSession _attach(MediaSession media, _Backend backend) =>
    MediaRoomSession.attach(
      roomCode: 'room',
      participantId: 'host',
      roomOwnerCredential: 'owner',
      session: media,
      presence: backend,
      management: backend,
      heartbeatInterval: Duration.zero,
    );

class _FailingLeave extends FakeMediaSession {
  _FailingLeave() : super(providerId: 'fake', role: MediaRole.host);
  @override
  Future<void> leave() async {
    leaveCount++;
    await Future<void>.delayed(Duration.zero);
    throw const RealtimeException(
      code: RealtimeErrorCode.providerError,
      message: 'private native payload',
    );
  }
}

class _Backend extends Fake implements MediaRoomPresence, MediaRoomManagement {
  int leaves = 0;
  int closes = 0;
  @override
  Future<void> heartbeat(String roomCode, {String? participantId}) async {}
  @override
  Future<void> leave(String roomCode, {String? participantId}) async {
    leaves++;
  }

  @override
  Future<void> closeRoomManaged(
    String roomCode, {
    required String requesterParticipantId,
    String? participantCredential,
    String? roomOwnerCredential,
  }) async {
    closes++;
  }
}
