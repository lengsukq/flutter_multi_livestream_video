import 'package:flutter_multi_livestream_video_core/flutter_multi_livestream_video_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_media_session.dart';

void main() {
  group('session lifecycle', () {
    late FakeMediaSessionFactory factory;
    late MediaJoinInfo joinInfo;

    setUp(() {
      factory = FakeMediaSessionFactory();
      joinInfo = MediaJoinInfo(
        providerId: 'fake',
        roomCode: '482913',
        participantId: 'leo',
        displayName: 'Leo',
        role: MediaRole.participant,
      );
    });

    test(
      'join moves idle -> connected and seeds the local participant',
      () async {
        final session = factory.createSession(joinInfo);
        final states = <MediaSessionState>[];
        final subscription = session.states.listen(states.add);

        await session.join(joinInfo);
        // Stream events are delivered asynchronously; drain before asserting.
        await pumpEventQueue();

        expect(session.state, MediaSessionState.connected);
        expect(session.snapshot.localParticipantId, 'leo');
        expect(session.snapshot.localParticipant?.isLocal, isTrue);
        expect(session.snapshot.capabilities.canPublishVideo, isTrue);
        expect(states, [
          MediaSessionState.connecting,
          MediaSessionState.connected,
        ]);

        await subscription.cancel();
        await session.dispose();
      },
    );

    test('a failed join reports failed and keeps the error', () async {
      final error = MediaError(
        code: MediaErrorCode.permissionDenied,
        message: 'Microphone denied.',
        providerId: 'fake',
      );
      final failing = FakeMediaSessionFactory(joinError: error);
      final session = failing.createSession(joinInfo);

      await expectLater(session.join(joinInfo), throwsA(same(error)));
      expect(session.state, MediaSessionState.failed);
      expect(session.snapshot.lastError, same(error));
      await session.dispose();
    });

    test('screen sharing follows the declared capability', () async {
      final participant = factory.createSession(joinInfo);
      await participant.join(joinInfo);
      await expectLater(
        participant.setScreenShareEnabled(true),
        throwsA(
          isA<MediaError>().having(
            (error) => error.code,
            'code',
            MediaErrorCode.unsupportedFeature,
          ),
        ),
      );
      await participant.dispose();

      final hostInfo = MediaJoinInfo(
        providerId: 'fake',
        roomCode: '482913',
        participantId: 'host',
        displayName: 'Host',
        role: MediaRole.host,
      );
      final host = factory.createSession(hostInfo);
      await host.join(hostInfo);
      await host.setScreenShareEnabled(true);
      expect(host.actions, contains('screenShare:true'));
      await host.dispose();
    });

    test('leave is safe when never joined and after ending', () async {
      final session = factory.createSession(joinInfo);
      await session.leave();
      expect(session.state, MediaSessionState.ended);
      await session.leave();
      expect(session.state, MediaSessionState.ended);
      expect(session.leaveCount, 2);
      await session.dispose();
      await session.dispose();
      expect(session.disposeCount, 2);
    });

    test('dispose is idempotent through the room wrapper semantics', () async {
      final session = factory.createSession(joinInfo);
      await session.join(joinInfo);
      await session.dispose();
      await session.dispose();
      expect(session.state, MediaSessionState.disposed);
      expect(session.disposeCount, 2);
    });

    test('remote participants and failures surface as events', () async {
      final session = factory.createSession(joinInfo);
      await session.join(joinInfo);

      final events = <MediaEvent>[];
      final subscription = session.events.listen(events.add);

      session.emitRemoteParticipant(id: 'guest-1', name: 'Guest');
      session.emitError(
        const MediaError(
          code: MediaErrorCode.nativeError,
          message: 'temporary',
          providerId: 'fake',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(session.snapshot.remoteParticipants.length, 1);
      expect(events.whereType<MediaParticipantJoined>().length, 1);
      expect(events.whereType<MediaFailureEvent>().length, 1);

      await subscription.cancel();
      await session.dispose();
    });

    test('local media controls update the snapshot', () async {
      final session = factory.createSession(joinInfo);
      await session.join(joinInfo);

      await session.setMuted(false);
      expect(session.snapshot.localMuted, isFalse);
      await session.toggleMute();
      expect(session.snapshot.localMuted, isTrue);

      await session.setVideoEnabled(true);
      expect(session.snapshot.localVideoEnabled, isTrue);

      await session.switchCamera(MediaCameraPosition.back);
      expect(session.actions, contains('camera:back'));

      await session.sendMessage('hello', topic: 'chat');
      expect(session.actions, contains('message:chat:hello'));

      await session.dispose();
    });
  });
}
