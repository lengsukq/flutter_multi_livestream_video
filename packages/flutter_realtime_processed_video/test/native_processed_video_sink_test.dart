import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_processed_video/flutter_realtime_processed_video.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_realtime_media_test/processed_video');
  const first = ProcessedVideoSource(
    id: 'first',
    platform: ProcessedVideoPlatform.android,
    kind: ProcessedVideoSourceKind.nativeFrameHub,
    width: 640,
    height: 480,
    frameRate: 24,
  );
  test('native sink accepts iOS and Windows descriptors, not Web tracks', () {
    final sink = NativeProcessedVideoSink(providerId: 'test');
    for (final platform in [
      ProcessedVideoPlatform.android,
      ProcessedVideoPlatform.ios,
      ProcessedVideoPlatform.macos,
      ProcessedVideoPlatform.windows,
    ]) {
      expect(
        sink.supports(
          ProcessedVideoSource(
            id: 'native',
            platform: platform,
            kind: ProcessedVideoSourceKind.nativeFrameHub,
            width: 640,
            height: 480,
            frameRate: 24,
          ),
        ),
        isTrue,
      );
    }
    expect(
      sink.supports(
        const ProcessedVideoSource(
          id: 'web',
          platform: ProcessedVideoPlatform.web,
          kind: ProcessedVideoSourceKind.mediaStreamTrack,
          width: 640,
          height: 480,
          frameRate: 24,
        ),
      ),
      isFalse,
    );
  });
  const second = ProcessedVideoSource(
    id: 'second',
    platform: ProcessedVideoPlatform.android,
    kind: ProcessedVideoSourceKind.nativeFrameHub,
    width: 640,
    height: 480,
    frameRate: 24,
  );
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  test(
    'replacement waits for the previous binding and disposal shares one future',
    () async {
      final calls = <String>[];
      final gate = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            final args = call.arguments as Map<Object?, Object?>;
            calls.add('${call.method}:${args['sourceId']}');
            if (call.method == 'attachProvider' &&
                args['sourceId'] == 'first') {
              await gate.future;
            }
            return null;
          });
      final sink = NativeProcessedVideoSink(providerId: 'test');
      final initial = sink.attach(first);
      final replacement = sink.attach(second);
      await Future<void>.delayed(Duration.zero);
      expect(calls, ['attachProvider:first']);
      gate.complete();
      await Future.wait([initial, replacement]);
      final disposal = sink.dispose();
      expect(identical(disposal, sink.dispose()), isTrue);
      await disposal;
      expect(calls, [
        'attachProvider:first',
        'detachProvider:first',
        'attachProvider:second',
        'detachProvider:second',
      ]);
      expect(sink.source, isNull);
    },
  );
  test('a failed detach retains the binding for an explicit retry', () async {
    var fail = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'detachProvider' && fail) {
            throw PlatformException(
              code: 'temporary',
              message: 'private-native-payload',
            );
          }
          return null;
        });
    final sink = NativeProcessedVideoSink(providerId: 'test');
    await sink.attach(first);
    await expectLater(sink.detach(), throwsA(isA<RealtimeException>()));
    expect(sink.source, same(first));
    fail = false;
    await sink.detach();
    expect(sink.source, isNull);
    await sink.dispose();
  });
  test(
    'untrusted frame descriptors cannot invent platform or geometry defaults',
    () {
      expect(
        () => ProcessedVideoSource.fromJson({
          'id': 'source',
          'width': 640,
          'height': 480,
          'frameRate': 24,
        }),
        throwsA(isA<RealtimeException>()),
      );
    },
  );
}
