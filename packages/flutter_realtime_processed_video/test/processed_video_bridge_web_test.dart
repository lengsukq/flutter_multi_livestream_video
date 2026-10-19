@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_processed_video/flutter_realtime_processed_video.dart';
import 'package:flutter_test/flutter_test.dart';

@JS('globalThis')
external JSObject get _global;

void main() {
  const source = ProcessedVideoSource(
    id: 'browser-source',
    platform: ProcessedVideoPlatform.web,
    kind: ProcessedVideoSourceKind.mediaStreamTrack,
    width: 640,
    height: 360,
    frameRate: 24,
  );

  tearDown(() => _global.delete('RealtimeProcessedVideoBridge'.toJS));

  test(
    'browser source controls await the registered JS source without a native plugin',
    () async {
      final calls = <String>[];
      final gate = Completer<JSAny?>();
      final bridge = JSObject();
      bridge.setProperty(
        'setEnabled'.toJS,
        ((JSString id, JSBoolean enabled) {
          calls.add('${id.toDart}:${enabled.toDart}');
          return gate.future.toJS;
        }).toJS,
      );
      bridge.setProperty(
        'selectCamera'.toJS,
        ((JSString id, [JSString? camera]) {
          calls.add('${id.toDart}:${camera?.toDart}');
        }).toJS,
      );
      _global.setProperty('RealtimeProcessedVideoBridge'.toJS, bridge);
      var completed = false;
      final enabling = ProcessedVideoBridge().setEnabled(source, true).then((
        _,
      ) {
        completed = true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      gate.complete(null);
      await enabling;
      await ProcessedVideoBridge().selectCamera(source, 'camera-2');
      await ProcessedVideoBridge().selectCamera(source, null);
      expect(calls, [
        'browser-source:true',
        'browser-source:camera-2',
        'browser-source:null',
      ]);
    },
  );

  test(
    'browser source rejections retain stage, cause and stack in a typed error',
    () async {
      final bridge = JSObject();
      bridge.setProperty(
        'setEnabled'.toJS,
        ((JSString id, JSBoolean enabled) {
          return Future<JSAny?>.error(StateError('processing failed')).toJS;
        }).toJS,
      );
      _global.setProperty('RealtimeProcessedVideoBridge'.toJS, bridge);
      await expectLater(
        ProcessedVideoBridge().setEnabled(source, true),
        throwsA(
          isA<RealtimeException>()
              .having((e) => e.domain, 'domain', 'processedVideo')
              .having((e) => e.operation, 'operation', 'setEnabled')
              .having((e) => e.cause, 'cause', isNotNull)
              .having((e) => e.stackTrace, 'stack', isNotNull),
        ),
      );
    },
  );
}
