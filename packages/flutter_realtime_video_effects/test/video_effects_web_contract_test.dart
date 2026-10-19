@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_video_effects/flutter_realtime_video_effects_web.dart';
import 'package:flutter_test/flutter_test.dart';

@JS('globalThis')
external JSObject get _global;

void main() {
  tearDown(() => _global.delete('RealtimeVideoEffectsBridge'.toJS));
  for (final version in <int?>[null, 99]) {
    test(
      'incompatible effects bridge $version is rejected before camera control',
      () async {
        final bridge = JSObject();
        if (version != null) {
          bridge.setProperty('bridgeVersion'.toJS, version.toJS);
        }
        _global.setProperty('RealtimeVideoEffectsBridge'.toJS, bridge);
        await expectLater(
          () => FlutterRealtimeVideoEffectsWeb().setEnabled('one', true),
          throwsA(
            isA<RealtimeException>()
                .having(
                  (e) => e.message,
                  'message',
                  'webBridge.versionMismatch',
                )
                .having(
                  (e) => e.suggestedAction,
                  'action',
                  'reload-web-runtime',
                ),
          ),
        );
      },
    );
  }
}
