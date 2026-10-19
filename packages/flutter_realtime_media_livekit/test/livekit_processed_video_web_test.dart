@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_media_livekit/flutter_realtime_media_livekit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:web/web.dart' as web;

@JS('globalThis')
external JSObject get _global;

void main() {
  test(
    'Web replaces the old camera, enables its clone and republishes without duplicate tracks',
    () async {
      final canvas = web.HTMLCanvasElement()
        ..width = 640
        ..height = 360;
      final original = canvas.captureStream().getVideoTracks().toDart.single;
      original.enabled = false;
      final controls = <bool>[];
      final bridge = JSObject();
      bridge.setProperty('getTrack'.toJS, ((JSString id) => original).toJS);
      bridge.setProperty(
        'setEnabled'.toJS,
        ((JSString id, JSBoolean value) {
          controls.add(value.toDart);
          original.enabled = value.toDart;
        }).toJS,
      );
      _global.setProperty('RealtimeProcessedVideoBridge'.toJS, bridge);
      final provider = _Room();
      final session = LiveKitInteractiveSession(roomFactory: () => provider);
      addTearDown(() async {
        await session.dispose();
        original.stop();
        _global.delete('RealtimeProcessedVideoBridge'.toJS);
      });
      await session.join(
        LiveKitJoinInfo(
          roomCode: 'room',
          participantId: 'local',
          role: MediaRole.participant,
          url: 'wss://example.invalid',
          token: 'unused',
          identity: 'local',
        ),
      );
      await session.attachProcessedVideoSource(
        const ProcessedVideoSource(
          id: 'processed',
          platform: ProcessedVideoPlatform.web,
          kind: ProcessedVideoSourceKind.mediaStreamTrack,
          width: 640,
          height: 360,
          frameRate: 24,
        ),
      );
      expect(provider.local.removed, ['raw-camera']);
      await session.setVideoEnabled(true);
      expect(provider.local.published, 1);
      final processed = provider.local.camera!.track!;
      expect(processed.mediaStreamTrack.enabled, isTrue);
      expect(processed.mediaStreamTrack.id, isNot(original.id));
      expect(session.snapshot.localVideoEnabled, isTrue);
      await session.setVideoEnabled(false);
      expect(processed.mediaStreamTrack.enabled, isFalse);
      await session.setVideoEnabled(true);
      expect(processed.mediaStreamTrack.enabled, isTrue);
      expect(processed.muted, isFalse);
      expect(provider.local.published, 1);
      expect(controls, [true, false, true]);
      await session.detachProcessedVideoSource();
      expect(provider.local.removed, ['raw-camera', 'processed-camera']);
      expect(
        original.readyState,
        'live',
        reason: 'the supplier owns only its clone',
      );
    },
  );
}

class _Room extends lk.Room {
  final local = _Participant();
  @override
  lk.LocalParticipant get localParticipant => local;
  @override
  Future<void> connect(
    String url,
    String token, {
    lk.ConnectOptions? connectOptions,
    lk.RoomOptions? roomOptions,
    lk.FastConnectOptions? fastConnectOptions,
  }) async {}
  @override
  Future<void> disconnect() async {}
}

class _Participant implements lk.LocalParticipant {
  _Publication? camera = _Publication('raw-camera');
  final removed = <String>[];
  int published = 0;
  @override
  String get identity => 'local';
  @override
  String get name => 'Local';
  @override
  bool get isMuted => true;
  @override
  bool get isSpeaking => false;
  @override
  DateTime get joinedAt => DateTime.utc(2026);
  @override
  lk.ParticipantPermissions get permissions => const lk.ParticipantPermissions(
    canSubscribe: true,
    canPublish: true,
    canPublishData: true,
  );
  @override
  bool isCameraEnabled() => camera?.track != null && !camera!.muted;
  @override
  lk.LocalTrackPublication? getTrackPublicationBySource(
    lk.TrackSource source,
  ) => source == lk.TrackSource.camera ? camera : null;
  @override
  Future<void> removePublishedTrack(String sid, {bool notify = true}) async {
    removed.add(sid);
    camera = null;
  }

  @override
  Future<lk.LocalTrackPublication<lk.LocalVideoTrack>> publishVideoTrack(
    lk.LocalVideoTrack track, {
    lk.VideoPublishOptions? publishOptions,
  }) async {
    expect(
      camera,
      isNull,
      reason: 'remove the old camera before publishing its replacement',
    );
    expect(track.mediaStreamTrack.enabled, isTrue);
    published++;
    await track.start();
    track.sid = 'processed-camera';
    return camera = _Publication('processed-camera', track);
  }

  @override
  Future<bool> dispose() async => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Publication implements lk.LocalTrackPublication<lk.LocalVideoTrack> {
  _Publication(this.sid, [this.track]);
  @override
  final String sid;
  @override
  final lk.LocalVideoTrack? track;
  @override
  bool get muted => track?.muted ?? true;
  @override
  lk.TrackType get kind => lk.TrackType.VIDEO;
  @override
  bool get isScreenShare => false;
  @override
  lk.VideoDimensions? get dimensions => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
