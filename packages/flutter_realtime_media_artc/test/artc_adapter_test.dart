import 'dart:convert';

import 'package:flutter_realtime_media_artc/flutter_realtime_media_artc.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_test/flutter_test.dart';

ArtcJoinInfo joinInfo({MediaRole role = MediaRole.participant}) => ArtcJoinInfo(
  roomCode: '482913',
  participantId: 'u-person1',
  role: role,
  displayName: 'Person 1',
  appId: 'demo-app',
  channelId: 'media-482913',
  userId: 'u-person1',
  authInfo: 'short-lived-base64-auth-info',
  expiresAtMs: DateTime.now().millisecondsSinceEpoch + 600000,
);

Map<String, Object?> response({MediaRole role = MediaRole.participant}) => {
  'provider': 'artc',
  'roomCode': '482913',
  'participantId': 'u-person1',
  'role': role.wireName,
  'displayName': 'Person 1',
  'artc': {
    'appId': 'demo-app',
    'channelId': 'media-482913',
    'userId': 'u-person1',
    'authInfo': 'short-lived-base64-auth-info',
    'expiresAtMs': DateTime.now().millisecondsSinceEpoch + 600000,
  },
};

void main() {
  test('parses provider credentials and maps roles to room modes', () {
    final factory = ArtcSessionFactory(
      engineFactory: () async => _FakeArtcEngine(),
    );
    final participant = factory.parseJoinInfo(response());
    final broadcast = ArtcJoinInfo.fromJson(response(role: MediaRole.host));

    expect(factory.providerId, 'artc');
    expect(factory.supportedRoles, containsAll(MediaRole.values));
    expect(participant.roomMode, ArtcRoomMode.communication);
    expect(broadcast.roomMode, ArtcRoomMode.interactiveLive);
  });

  test('rejects malformed or mismatched ARTC join information', () {
    final invalidProvider = response()..['provider'] = 'trtc';
    expect(
      () => ArtcJoinInfo.fromJson(invalidProvider),
      throwsA(
        isA<MediaError>().having(
          (error) => error.code,
          'code',
          MediaErrorCode.invalidJoinInfo,
        ),
      ),
    );
    final wrongUser = response();
    (wrongUser['artc'] as Map<String, Object?>)['userId'] = 'different-user';
    expect(
      () => ArtcJoinInfo.fromJson(wrongUser),
      throwsA(
        isA<MediaError>().having(
          (error) => error.code,
          'code',
          MediaErrorCode.invalidJoinInfo,
        ),
      ),
    );
    final noExpiry = response();
    (noExpiry['artc'] as Map<String, Object?>).remove('expiresAtMs');
    expect(
      () => ArtcJoinInfo.fromJson(noExpiry),
      throwsA(
        isA<MediaError>().having(
          (error) => error.code,
          'code',
          MediaErrorCode.invalidJoinInfo,
        ),
      ),
    );
  });

  test(
    'joins, controls media, maps participants, tracks, messages, and leaves',
    () async {
      final engine = _FakeArtcEngine();
      final session = ArtcSessionFactory(
        engineFactory: () async => engine,
      ).createSession(joinInfo());
      final events = <MediaEvent>[];
      final subscription = session.events.listen(events.add);

      await session.join(joinInfo());
      expect(session.state, MediaSessionState.connected);
      expect(engine.joined.single.userId, 'u-person1');
      expect(engine.joined.single.roomMode, ArtcRoomMode.communication);
      expect(session.snapshot.localParticipantId, 'u-person1');
      expect(session.capabilities.canScreenShare, isFalse);
      expect(session.capabilities.canEnumerateAudioDevices, isFalse);
      final interactive = session as InteractiveMediaSession;
      await expectLater(
        interactive.sendMessage('too early'),
        throwsA(
          isA<MediaError>().having(
            (error) => error.code,
            'code',
            MediaErrorCode.invalidState,
          ),
        ),
      );

      await interactive.setMuted(false);
      await interactive.setVideoEnabled(true);
      await interactive.switchCamera(MediaCameraPosition.back);
      expect(session.snapshot.localMuted, isFalse);
      expect(session.snapshot.localVideoEnabled, isTrue);
      expect(
        engine.calls,
        containsAll(['mute:false', 'video:true', 'camera:back']),
      );
      expect(events.whereType<MediaTrackPublished>(), hasLength(1));
      await expectLater(
        interactive.setScreenShareEnabled(true),
        throwsA(
          isA<MediaError>().having(
            (error) => error.code,
            'code',
            MediaErrorCode.unsupportedFeature,
          ),
        ),
      );

      engine.events!.onParticipantJoined?.call('u-remote');
      engine.events!.onRemoteVideoChanged?.call('u-remote', true);
      engine.events!.onRemoteAudioChanged?.call('u-remote', false);
      await Future<void>.delayed(Duration.zero);
      final remote = session.snapshot.remoteParticipants.single;
      expect(remote.videoTrack, isA<ArtcMediaVideoTrack>());
      expect(remote.isMuted, isTrue);
      expect(events.whereType<MediaParticipantJoined>(), hasLength(1));

      engine.events!.onMessage?.call(
        'u-remote',
        jsonEncode({'topic': 'chat', 'message': 'hello'}),
      );
      await interactive.sendMessage('ack', topic: 'chat');
      expect(session.snapshot.messages.map((message) => message.message), [
        'hello',
        'ack',
      ]);
      expect(engine.calls, contains('message:ack:chat'));
      expect(events.whereType<MediaMessageReceived>(), hasLength(1));

      engine.events!.onParticipantLeft?.call('u-remote');
      expect(session.snapshot.remoteParticipants, isEmpty);
      engine.events!.onReconnecting?.call();
      expect(session.state, MediaSessionState.reconnecting);
      engine.events!.onRecovered?.call();
      expect(session.state, MediaSessionState.connected);

      await session.leave();
      expect(session.state, MediaSessionState.ended);
      expect(engine.leaveCount, 1);
      await subscription.cancel();
      await session.dispose();
      expect(session.state, MediaSessionState.disposed);
      expect(engine.disposed, isTrue);
    },
  );

  test('host advertises backend room management but not native removal', () async {
    final session = ArtcSessionFactory(
      engineFactory: () async => _FakeArtcEngine(),
    ).createSession(joinInfo(role: MediaRole.host));
    await session.join(joinInfo(role: MediaRole.host));

    expect(session.capabilities.canListParticipants, isTrue);
    expect(session.capabilities.canCloseRoom, isTrue);
    expect(session.capabilities.canRemoveParticipants, isFalse);
    expect(session.capabilities.maxDataMessageBytes, 1024);
    await session.dispose();
  });

  test(
    'viewer surface is subscribe-only and receives but cannot send data',
    () async {
      final engine = _FakeArtcEngine();
      final session = ArtcSessionFactory(
        engineFactory: () async => engine,
      ).createSession(joinInfo(role: MediaRole.viewer));
      await session.join(joinInfo(role: MediaRole.viewer));

      expect(session, isA<BroadcastViewerSession>());
      expect(session, isNot(isA<InteractiveMediaSession>()));
      expect(session.capabilities.canPublishAudio, isFalse);
      expect(session.capabilities.canPublishVideo, isFalse);
      expect(session.capabilities.canSendData, isFalse);
      await expectLater(
        (session as BroadcastViewerSession).sendMessage('not allowed'),
        throwsA(
          isA<MediaError>().having(
            (error) => error.code,
            'code',
            MediaErrorCode.unsupportedFeature,
          ),
        ),
      );
      engine.events!.onMessage?.call(
        'u-host',
        jsonEncode({'topic': 'chat', 'message': 'welcome'}),
      );
      expect(session.snapshot.messages.single.message, 'welcome');
      await session.dispose();
    },
  );

  test(
    'refresh rejoins same channel and identity; changed identity is rejected',
    () async {
      final engine = _FakeArtcEngine();
      final session = ArtcSessionFactory(
        engineFactory: () async => engine,
      ).createSession(joinInfo());
      var refreshCalls = 0;
      (session as MediaCredentialRefreshable).setCredentialRefreshCallback((
        current,
      ) async {
        refreshCalls++;
        final original = current as ArtcJoinInfo;
        return ArtcJoinInfo(
          roomCode: original.roomCode,
          participantId: original.participantId,
          role: original.role,
          displayName: original.displayName,
          appId: original.appId,
          channelId: original.channelId,
          userId: original.userId,
          authInfo: 'renewed-auth-info',
          expiresAtMs: DateTime.now().millisecondsSinceEpoch + 600000,
        );
      });
      await session.join(joinInfo());
      engine.events!.onAuthWillExpire?.call();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(refreshCalls, 1);
      expect(engine.joined, hasLength(2));
      expect(engine.joined.last.authInfo, 'renewed-auth-info');
      expect(session.state, MediaSessionState.connected);
      await session.dispose();

      final changedEngine = _FakeArtcEngine();
      final changedSession = ArtcSessionFactory(
        engineFactory: () async => changedEngine,
      ).createSession(joinInfo());
      (changedSession as MediaCredentialRefreshable)
          .setCredentialRefreshCallback((current) async {
            final original = current as ArtcJoinInfo;
            return ArtcJoinInfo(
              roomCode: original.roomCode,
              participantId: original.participantId,
              role: original.role,
              displayName: original.displayName,
              appId: original.appId,
              channelId: 'other-channel',
              userId: original.userId,
              authInfo: 'wrong-room-auth',
              expiresAtMs: DateTime.now().millisecondsSinceEpoch + 600000,
            );
          });
      await changedSession.join(joinInfo());
      changedEngine.events!.onAuthWillExpire?.call();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(changedSession.state, MediaSessionState.failed);
      expect(changedEngine.joined, hasLength(1));
      await changedSession.dispose();
    },
  );

  test('only one ARTC engine session can be active at a time', () async {
    final engine = _FakeArtcEngine();
    final factory = ArtcSessionFactory(engineFactory: () async => engine);
    final first = factory.createSession(joinInfo());
    final second = factory.createSession(joinInfo());
    await first.join(joinInfo());
    await expectLater(
      second.join(joinInfo()),
      throwsA(
        isA<MediaError>().having(
          (error) => error.code,
          'code',
          MediaErrorCode.sessionAlreadyActive,
        ),
      ),
    );
    await first.dispose();
    await second.dispose();
  });
}

class _FakeArtcEngine implements ArtcEngine {
  final List<ArtcJoinInfo> joined = [];
  final List<String> calls = [];
  ArtcEngineEvents? events;
  int leaveCount = 0;
  bool disposed = false;

  @override
  Future<void> join(ArtcJoinInfo info, ArtcEngineEvents events) async {
    joined.add(info);
    this.events = events;
  }

  @override
  Future<void> leave() async {
    leaveCount++;
  }

  @override
  Future<void> setMuted(bool muted) async => calls.add('mute:$muted');

  @override
  Future<void> setVideoEnabled(bool enabled) async =>
      calls.add('video:$enabled');

  @override
  Future<void> switchCamera(MediaCameraPosition position) async =>
      calls.add('camera:${position.name}');

  @override
  Future<void> sendMessage(String message, String topic) async =>
      calls.add('message:$message:$topic');

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}
