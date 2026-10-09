import 'dart:async';

import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_video_effects/flutter_realtime_video_effects.dart';
import 'package:flutter_realtime_video_effects/flutter_realtime_video_effects_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_realtime_sdk/src/video_effects_local_preview.dart';

void main() {
  test(
    'None restores preview after an asynchronous processing failure',
    () async {
      final platform = _PreviewPlatform();
      final preview = await VideoEffectsLocalPreviewSession.create(
        providerId: 'livekit',
        role: MediaRole.participant,
        bridge: VideoEffectsBridge(platform: platform),
      );
      final failure = preview.failures.first;
      await preview.setCameraEnabled(true);
      platform.errors.add(
        const VideoEffectsFailure(
          sourceId: 'camera',
          message: 'GPU frame failed',
        ),
      );
      await failure;
      expect(preview.cameraTrack, isNull);

      await preview.setBackgroundEffect(const MediaBackgroundEffect.none());

      expect(platform.effects, [const MediaBackgroundEffect.none()]);
      expect(platform.enabled, [true, true]);
      expect(preview.settings.cameraEnabled, isTrue);
      expect(preview.cameraTrack, isNotNull);
      await preview.dispose();
      await platform.errors.close();
    },
  );

  test('effect changes preserve an explicitly disabled camera', () async {
    final platform = _PreviewPlatform();
    final preview = await VideoEffectsLocalPreviewSession.create(
      providerId: 'chime',
      role: MediaRole.participant,
      bridge: VideoEffectsBridge(platform: platform),
    );
    await preview.setCameraEnabled(false);
    await preview.setBackgroundEffect(const MediaBackgroundEffect.blur());
    await preview.setBackgroundEffect(const MediaBackgroundEffect.none());

    expect(platform.enabled, isEmpty);
    expect(platform.configs, isEmpty);
    expect(preview.settings.cameraEnabled, isFalse);
    expect(preview.cameraTrack, isNull);
    await preview.dispose();
    await platform.errors.close();
  });

  test(
    'preview starts with capture off and creates one source only on explicit enable',
    () async {
      final platform = _PreviewPlatform();
      final preview = await VideoEffectsLocalPreviewSession.create(
        providerId: 'livekit',
        role: MediaRole.participant,
        bridge: VideoEffectsBridge(platform: platform),
      );
      expect(preview.settings.cameraEnabled, isFalse);
      expect(preview.settings.microphoneEnabled, isFalse);
      expect(preview.cameraTrack, isNull);
      await preview.listMediaDevices();
      await preview.setBackgroundEffect(const MediaBackgroundEffect.blur());
      await preview.selectMediaDevice(
        const MediaDevice(
          id: 'selected-camera',
          label: 'Camera',
          kind: MediaDeviceKind.camera,
        ),
      );
      expect(platform.configs, isEmpty);
      await preview.setCameraEnabled(true);
      expect(platform.configs.single.cameraDeviceId, 'selected-camera');
      expect(
        platform.configs.single.effect,
        const MediaBackgroundEffect.blur(),
      );
      expect(preview.cameraTrack, isNotNull);
      await preview.setCameraEnabled(false);
      await preview.setCameraEnabled(true);
      expect(platform.configs, hasLength(1));
      await preview.dispose();
      expect(platform.disposed, ['camera']);
      await platform.errors.close();
    },
  );

  test(
    'cancel during source creation releases late capture exactly once',
    () async {
      final platform = _PreviewPlatform();
      final gate = Completer<void>();
      platform.pending = gate.future;
      final preview = await VideoEffectsLocalPreviewSession.create(
        providerId: 'chime',
        role: MediaRole.participant,
        bridge: VideoEffectsBridge(platform: platform),
      );
      final enabling = preview.setCameraEnabled(true);
      final failure = expectLater(enabling, throwsA(isA<RealtimeException>()));
      final disposing = preview.dispose();
      gate.complete();
      await failure;
      await disposing;
      expect(platform.disposed, ['camera']);
      expect(preview.cameraTrack, isNull);
      await platform.errors.close();
    },
  );
}

class _PreviewPlatform extends FlutterRealtimeVideoEffectsPlatform {
  final errors = StreamController<VideoEffectsFailure>.broadcast();
  final enabled = <bool>[];
  final effects = <MediaBackgroundEffect>[];
  final configs = <VideoEffectsSourceConfig>[];
  final disposed = <String>[];
  Future<void>? pending;
  @override
  Stream<VideoEffectsFailure> get failures => errors.stream;
  @override
  Future<bool> isSupported() async => true;
  @override
  Future<ProcessedVideoSource> createSource(
    VideoEffectsSourceConfig config,
  ) async {
    configs.add(config);
    await pending;
    return const ProcessedVideoSource(
      id: 'camera',
      platform: VideoEffectsPlatform.android,
      kind: ProcessedVideoSourceKind.nativeFrameHub,
      width: 1280,
      height: 720,
      frameRate: 24,
    );
  }

  @override
  Future<void> setEffect(String sourceId, MediaBackgroundEffect effect) async {
    effects.add(effect);
  }

  @override
  Future<void> setEnabled(String sourceId, bool value) async {
    enabled.add(value);
  }

  @override
  Future<void> selectCamera(String sourceId, String? deviceId) async {}
  @override
  Future<List<VideoEffectsCameraDevice>> listCameras() async => const [];
  @override
  Future<void> disposeSource(String sourceId) async {
    disposed.add(sourceId);
  }
}
