import 'dart:async';
import 'video_effects_runtime_loader.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:web/web.dart' as web;

final _runtime = VideoEffectsRuntimeLoader(loadScript: _loadScript);
Future<void> ensureVideoEffectsWebAssets() => _runtime.ensureLoaded();

Future<void> _loadScript(String file) async {
  final path =
      'assets/packages/flutter_realtime_video_effects/assets/web/$file';
  final script = web.HTMLScriptElement()
    ..src = Uri.parse(web.document.baseURI).resolve(path).toString()
    ..async = false;
  final ready = Completer<void>();
  final load = script.onLoad.listen((_) {
    if (!ready.isCompleted) ready.complete();
  });
  final error = script.onError.listen((_) {
    if (!ready.isCompleted) {
      ready.completeError(
        MediaError(
          code: MediaErrorCode.nativeError,
          message: 'Unable to load the video effects runtime: $file.',
        ),
      );
    }
  });
  web.document.head!.append(script);
  try {
    await ready.future.timeout(const Duration(seconds: 30));
  } on Object {
    script.remove();
    rethrow;
  } finally {
    await load.cancel();
    await error.cancel();
  }
}
