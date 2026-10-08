import 'dart:async';
import 'package:flutter_realtime_video_effects/src/video_effects_runtime_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'construction performs no load; concurrent effect operations load once',
    () async {
      final gate = Completer<void>();
      final calls = <String>[];
      final loader = VideoEffectsRuntimeLoader(
        loadScript: (file) async {
          calls.add(file);
          await gate.future;
        },
      );
      expect(calls, isEmpty);
      final first = loader.ensureLoaded();
      final second = loader.ensureLoaded();
      gate.complete();
      await Future.wait([first, second]);
      await loader.ensureLoaded();
      expect(calls, ['vision.js', 'video-effects-bridge.js']);
    },
  );
  test(
    'failed initialization can retry without loading completed scripts again',
    () async {
      final calls = <String>[];
      var fail = true;
      final loader = VideoEffectsRuntimeLoader(
        loadScript: (file) async {
          calls.add(file);
          if (file == 'video-effects-bridge.js' && fail) {
            throw StateError('missing');
          }
        },
      );
      await expectLater(loader.ensureLoaded(), throwsStateError);
      fail = false;
      await loader.ensureLoaded();
      expect(calls, [
        'vision.js',
        'video-effects-bridge.js',
        'video-effects-bridge.js',
      ]);
    },
  );
}
