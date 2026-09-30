import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_video_effects/flutter_realtime_video_effects.dart';
import 'package:flutter_realtime_video_effects/flutter_realtime_video_effects_method_channel.dart';
import 'package:flutter_realtime_video_effects/flutter_realtime_video_effects_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePlatform
    with MockPlatformInterfaceMixin
    implements FlutterRealtimeVideoEffectsPlatform {
  final List<MediaBackgroundEffect> effects = [];

  @override
  Stream<VideoEffectsFailure> get failures => const Stream.empty();

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<ProcessedVideoSource> createSource(
    VideoEffectsSourceConfig config,
  ) async => ProcessedVideoSource(
    id: 'source-1',
    platform: VideoEffectsPlatform.android,
    kind: ProcessedVideoSourceKind.nativeFrameHub,
    width: config.width,
    height: config.height,
    frameRate: config.frameRate.toDouble(),
    previewTextureId: 7,
  );

  @override
  Future<void> setEffect(String sourceId, MediaBackgroundEffect effect) async {
    effects.add(effect);
  }

  @override
  Future<void> setEnabled(String sourceId, bool enabled) async {}

  @override
  Future<void> selectCamera(String sourceId, String? deviceId) async {}

  @override
  Future<List<VideoEffectsCameraDevice>> listCameras() async => const [
    VideoEffectsCameraDevice(
      id: 'front',
      label: 'Front camera',
      isFrontFacing: true,
    ),
  ];

  @override
  Future<void> disposeSource(String sourceId) async {}
}

void main() {
  final initialPlatform = FlutterRealtimeVideoEffectsPlatform.instance;

  test('method channel is the default native implementation', () {
    expect(initialPlatform, isA<MethodChannelFlutterRealtimeVideoEffects>());
  });

  test('bridge creates source and applies provider-neutral effect', () async {
    final fake = _FakePlatform();
    FlutterRealtimeVideoEffectsPlatform.instance = fake;
    addTearDown(() {
      FlutterRealtimeVideoEffectsPlatform.instance = initialPlatform;
    });

    final bridge = VideoEffectsBridge();
    final source = await bridge.createSource();
    await bridge.setEffect(source, const MediaBackgroundEffect.blur());

    expect(source.id, 'source-1');
    expect(source.previewTextureId, 7);
    expect(fake.effects, [const MediaBackgroundEffect.blur()]);
  });
}
