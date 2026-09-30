import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_video_effects/flutter_realtime_video_effects.dart';
import 'package:flutter_realtime_video_effects/flutter_realtime_video_effects_method_channel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelFlutterRealtimeVideoEffects();
  const channel = MethodChannel('flutter_realtime_video_effects');
  final calls = <MethodCall>[];

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'isSupported') return true;
          if (call.method == 'createSource') {
            return <String, Object?>{
              'id': 'native-source',
              'platform': 'android',
              'kind': 'nativeFrameHub',
              'width': 1280,
              'height': 720,
              'frameRate': 24,
              'previewTextureId': 9,
            };
          }
          if (call.method == 'listCameras') {
            return [
              {'id': 'front', 'label': 'Front camera', 'isFrontFacing': true},
            ];
          }
          return null;
        });
  });

  tearDown(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('creates and configures native source without frame transfer', () async {
    expect(await platform.isSupported(), isTrue);
    final source = await platform.createSource(
      const VideoEffectsSourceConfig(),
    );
    await platform.setEffect(source.id, const MediaBackgroundEffect.blur());

    expect(source.id, 'native-source');
    expect(source.kind, ProcessedVideoSourceKind.nativeFrameHub);
    expect(calls.map((call) => call.method), [
      'isSupported',
      'createSource',
      'setEffect',
    ]);
  });

  test(
    'native failures carry the owning source id back to SDK listeners',
    () async {
      await platform.isSupported();
      final failure = platform.failures.first;
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            channel.name,
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('sourceError', {
                'sourceId': 'native-source',
                'message': 'segmentation failed',
              }),
            ),
            (_) {},
          );
      final value = await failure;
      expect(value.sourceId, 'native-source');
      expect(value.message, 'segmentation failed');
    },
  );

  test('replacement bytes travel only as an effect control payload', () async {
    final effect = MediaBackgroundEffect.replaceImage(
      imageBytes: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0]),
    );
    await platform.setEffect('native-source', effect);
    expect(calls, hasLength(1));
    expect(calls.single.method, 'setEffect');
    expect(calls.single.arguments, {
      'sourceId': 'native-source',
      'effect': effect.toJson(),
    });
  });
}
