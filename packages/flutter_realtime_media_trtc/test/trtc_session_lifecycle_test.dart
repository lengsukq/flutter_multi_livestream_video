import 'dart:convert';

import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_media_trtc/flutter_realtime_media_trtc.dart';
import 'package:flutter_realtime_media_trtc/src/trtc_engine.dart';
import 'package:flutter_test/flutter_test.dart';

TrtcJoinInfo joinInfo({MediaRole role = MediaRole.participant}) => TrtcJoinInfo(
  roomCode: '482913',
  participantId: 'u-person1',
  role: role,
  displayName: 'Person 1',
  sdkAppId: 1400000000,
  strRoomId: 'media-482913',
  userId: 'u-person1',
  userSig: 'short-lived-user-sig',
  privateMapKey: 'room-scoped-private-map-key',
  expiresAtMs: DateTime.now().millisecondsSinceEpoch + 600000,
);

void main() {
  test(
    'joins, publishes controls, maps events, renders tracks, and leaves',
    () async {
      final engine = _FakeTrtcEngine();
      final session = TrtcSessionFactory(
        engineFactory: () async => engine,
      ).createSession(joinInfo());
      final events = <MediaEvent>[];
      final subscription = session.events.listen(events.add);

      await session.join(joinInfo());
      expect(session.state, MediaSessionState.connected);
      expect(session.snapshot.localParticipantId, 'u-person1');
      expect(engine.enteredRooms, hasLength(1));

      final interactive = session as InteractiveMediaSession;
      await interactive.setMuted(false);
      await interactive.setVideoEnabled(true);
      await interactive.switchCamera(MediaCameraPosition.back);
      expect(session.snapshot.localMuted, isFalse);
      expect(session.snapshot.localVideoEnabled, isTrue);
      expect(
        engine.calls,
        containsAll([
          'audio:start',
          'audio:mute:false',
          'video:mute:false',
          'camera:false',
        ]),
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
      await expectLater(
        interactive.sendMessage(List.filled(1000, 'x').join()),
        throwsA(
          isA<MediaError>().having(
            (error) => error.code,
            'code',
            MediaErrorCode.invalidArgument,
          ),
        ),
      );

      final engineEvents = engine.lastEvents!;
      engineEvents.onRemoteUserEnterRoom?.call('u-remote');
      engineEvents.onUserVideoAvailable?.call('u-remote', true);
      engineEvents.onUserAudioAvailable?.call('u-remote', true);
      final remote = session.snapshot.remoteParticipants.single;
      expect(remote.id, 'u-remote');
      expect(remote.isVideoEnabled, isTrue);
      expect(remote.isMuted, isFalse);
      expect(remote.videoTrack, isA<TrtcMediaVideoTrack>());

      final remoteTrack = remote.videoTrack! as TrtcMediaVideoTrack;
      remoteTrack.startRendering(77);
      remoteTrack.stopRendering();
      expect(
        engine.calls,
        containsAll(['remote:start:u-remote:77', 'remote:stop:u-remote']),
      );

      engineEvents.onRecvCustomCmdMsg?.call(
        'u-remote',
        1,
        jsonEncode({'topic': 'chat', 'message': 'hello'}),
      );
      await interactive.sendMessage('ack', topic: 'chat');
      await Future<void>.delayed(Duration.zero);
      expect(session.snapshot.messages.map((message) => message.message), [
        'hello',
        'ack',
      ]);
      expect(events.whereType<MediaMessageReceived>(), hasLength(1));
      expect(engine.calls, contains('message:1'));

      engineEvents.onRemoteUserLeaveRoom?.call('u-remote');
      expect(session.snapshot.remoteParticipants, isEmpty);
      engineEvents.onConnectionLost?.call();
      expect(session.state, MediaSessionState.reconnecting);
      engineEvents.onConnectionRecovery?.call();
      expect(session.state, MediaSessionState.connected);
      engineEvents.onError?.call(-42, 'native failure');
      await Future<void>.delayed(Duration.zero);
      expect(session.snapshot.lastError?.code, MediaErrorCode.nativeError);
      await session.leave();
      expect(session.state, MediaSessionState.ended);
      expect(engine.exitCount, 1);
      await subscription.cancel();
      await session.dispose();
      expect(session.state, MediaSessionState.disposed);
      expect(engine.disposed, isTrue);
    },
  );

  test(
    'viewer cannot publish or send messages and remains subscribe-only',
    () async {
      final engine = _FakeTrtcEngine();
      final session = TrtcSessionFactory(
        engineFactory: () async => engine,
      ).createSession(joinInfo(role: MediaRole.viewer));
      await session.join(joinInfo(role: MediaRole.viewer));

      expect(session, isA<BroadcastViewerSession>());
      expect(session, isNot(isA<InteractiveMediaSession>()));
      expect(engine.calls, isNot(contains('audio:start')));
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
      await session.dispose();
    },
  );

  test(
    'expired credentials refresh once and re-enter as the same identity',
    () async {
      final engine = _FakeTrtcEngine()..enterResults.addAll([-100018, 1]);
      final session = TrtcSessionFactory(
        engineFactory: () async => engine,
      ).createSession(joinInfo());
      var refreshCalls = 0;
      (session as MediaCredentialRefreshable).setCredentialRefreshCallback((
        current,
      ) async {
        refreshCalls++;
        final trtcCurrent = current as TrtcJoinInfo;
        return TrtcJoinInfo(
          roomCode: trtcCurrent.roomCode,
          participantId: trtcCurrent.participantId,
          role: trtcCurrent.role,
          displayName: trtcCurrent.displayName,
          sdkAppId: trtcCurrent.sdkAppId,
          strRoomId: trtcCurrent.strRoomId,
          userId: trtcCurrent.userId,
          userSig: 'renewed-user-sig',
          privateMapKey: 'renewed-private-map-key',
          expiresAtMs: DateTime.now().millisecondsSinceEpoch + 600000,
        );
      });

      await session.join(joinInfo());
      expect(refreshCalls, 1);
      expect(engine.enteredRooms, hasLength(2));
      expect(engine.enteredRooms.last.userId, 'u-person1');
      expect(engine.enteredRooms.last.userSig, 'renewed-user-sig');
      expect(session.state, MediaSessionState.connected);
      await session.dispose();
    },
  );

  test(
    'maps an unrecoverable native enter failure to a typed provider error',
    () async {
      final engine = _FakeTrtcEngine()..enterResults.add(-42);
      final session = TrtcSessionFactory(
        engineFactory: () async => engine,
      ).createSession(joinInfo());

      await expectLater(
        session.join(joinInfo()),
        throwsA(
          isA<MediaError>().having(
            (error) => error.providerId,
            'providerId',
            'trtc',
          ),
        ),
      );
      expect(session.state, MediaSessionState.failed);
      await session.dispose();
    },
  );
}

class _FakeTrtcEngine implements TrtcEngine {
  final List<int> enterResults = [];
  final List<TrtcJoinInfo> enteredRooms = [];
  final List<String> calls = [];
  TrtcEngineEvents? lastEvents;
  int exitCount = 0;
  bool disposed = false;

  @override
  Future<int> enterRoom(TrtcJoinInfo joinInfo, TrtcEngineEvents events) async {
    enteredRooms.add(joinInfo);
    lastEvents = events;
    return enterResults.isEmpty ? 1 : enterResults.removeAt(0);
  }

  @override
  Future<void> exitRoom() async {
    exitCount++;
  }

  @override
  void startLocalAudio() => calls.add('audio:start');

  @override
  void muteLocalAudio(bool muted) => calls.add('audio:mute:$muted');

  @override
  void muteLocalVideo(bool muted) => calls.add('video:mute:$muted');

  @override
  void stopLocalPreview() => calls.add('preview:stop');

  @override
  void startLocalPreview(int viewId) => calls.add('preview:start:$viewId');

  @override
  void clearLocalView() => calls.add('preview:clear');

  @override
  void startRemoteView(String userId, int viewId) =>
      calls.add('remote:start:$userId:$viewId');

  @override
  void stopRemoteView(String userId) => calls.add('remote:stop:$userId');

  @override
  int switchCamera(bool frontCamera) {
    calls.add('camera:$frontCamera');
    return 0;
  }

  @override
  bool sendCustomCmdMsg(int commandId, String data) {
    calls.add('message:$commandId');
    return true;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}
