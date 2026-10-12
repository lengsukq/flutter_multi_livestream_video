import 'package:agora_rtc_engine/agora_rtc_engine.dart' as agora;
import 'package:flutter/foundation.dart';
import 'package:flutter_realtime_media_agora/flutter_realtime_media_agora.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_test/flutter_test.dart';

AgoraJoinInfo _credential() => AgoraJoinInfo(
  roomCode: 'r-android',
  participantId: '123',
  role: MediaRole.participant,
  appId: 'app-id',
  channelName: 'channel',
  token: 'token',
  uid: 123,
);

class _ScreenEngine extends Fake implements agora.RtcEngine {
  agora.RtcEngineEventHandler? handler;
  int startCount = 0;
  int stopCount = 0;
  int updates = 0;
  bool failStart = false;
  final List<agora.ChannelMediaOptions> mediaOptions = [];
  @override
  Future<void> initialize(agora.RtcEngineContext context) async {}
  @override
  void registerEventHandler(agora.RtcEngineEventHandler eventHandler) {
    handler = eventHandler;
  }

  @override
  void unregisterEventHandler(agora.RtcEngineEventHandler eventHandler) {
    handler = null;
  }

  @override
  Future<void> enableAudio() async {}
  @override
  Future<void> enableVideo() async {}
  @override
  Future<void> enableAudioVolumeIndication({
    required int interval,
    required int smooth,
    required bool reportVad,
  }) async {}
  @override
  Future<void> joinChannel({
    required String token,
    required String channelId,
    required int uid,
    required agora.ChannelMediaOptions options,
  }) async {
    mediaOptions.add(options);
    await Future.microtask(() {
      handler?.onJoinChannelSuccess?.call(
        agora.RtcConnection(channelId: channelId, localUid: uid),
        1,
      );
    });
  }

  @override
  Future<void> updateChannelMediaOptions(
    agora.ChannelMediaOptions options,
  ) async {
    updates++;
    mediaOptions.add(options);
  }

  @override
  Future<void> startScreenCapture(agora.ScreenCaptureParameters2 params) async {
    startCount++;
    expect(params.captureVideo, isTrue);
    expect(params.captureAudio, isFalse);
    if (failStart) throw StateError('permission rejected');
  }

  @override
  Future<void> stopScreenCapture() async {
    stopCount++;
  }

  @override
  Future<void> leaveChannel({agora.LeaveChannelOptions? options}) async {}
  @override
  Future<void> release({bool sync = false}) async {}
}

void main() {
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'Agora Android publishes the captured screen and restores camera options on stop',
    () async {
      final engine = _ScreenEngine();
      final session = AgoraInteractiveSession(engineFactory: () => engine);
      await session.join(_credential());
      expect(session.capabilities.canScreenShare, isTrue);
      expect(session.snapshot.localScreenShareEnabled, isFalse);
      final published = <MediaTrackPublished>[];
      final subscription = session.events.listen((event) {
        if (event is MediaTrackPublished) published.add(event);
      });
      await session.setScreenShareEnabled(true);
      expect(engine.startCount, 1);
      expect(session.snapshot.localScreenShareEnabled, isTrue);
      expect(session.snapshot.contentShareTrack?.isScreenShare, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(published.any((event) => event.track.isScreenShare), isTrue);
      expect(engine.mediaOptions.last.publishScreenCaptureVideo, isTrue);
      expect(engine.mediaOptions.last.publishCameraTrack, isFalse);
      await session.setScreenShareEnabled(true);
      expect(engine.startCount, 1);
      await session.setScreenShareEnabled(false);
      expect(engine.stopCount, 1);
      expect(engine.mediaOptions.last.publishScreenCaptureVideo, isFalse);
      expect(session.snapshot.localScreenShareEnabled, isFalse);
      expect(session.snapshot.contentShareTrack, isNull);
      await subscription.cancel();
      await session.dispose();
    },
  );

  test(
    'Agora Android screen capture errors do not create phantom active screens',
    () async {
      final engine = _ScreenEngine()..failStart = true;
      final session = AgoraInteractiveSession(engineFactory: () => engine);
      await session.join(_credential());
      await expectLater(
        session.setScreenShareEnabled(true),
        throwsA(isA<RealtimeException>()),
      );
      expect(session.snapshot.localScreenShareEnabled, isFalse);
      expect(session.snapshot.contentShareTrack, isNull);
      expect(engine.updates, 0);
      await session.dispose();
    },
  );

  test(
    'Agora Android session disposal stops an ongoing MediaProjection capture',
    () async {
      final engine = _ScreenEngine();
      final session = AgoraInteractiveSession(engineFactory: () => engine);
      await session.join(_credential());
      await session.setScreenShareEnabled(true);
      await session.dispose();
      expect(engine.stopCount, 1);
    },
  );
}
