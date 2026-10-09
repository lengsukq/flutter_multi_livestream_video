import 'package:flutter_realtime_foundation/flutter_realtime_foundation.dart';
import 'dart:async';
import 'package:web/web.dart' as web;
import 'realtime_error.dart';

final Map<String, Future<void>> _loads = {};
Future<void> loadRealtimeBundledWebScript(String assetPath) {
  final existing = _loads[assetPath];
  if (existing != null) return existing;
  final future = _load(assetPath);
  _loads[assetPath] = future;
  return future.catchError((Object error) {
    if (identical(_loads[assetPath], future)) {
      _loads.removeWhere((candidate, _) => candidate == assetPath);
    }
    throw error;
  });
}

Future<void> _load(String assetPath) async {
  final script = web.HTMLScriptElement()
    ..src = Uri.parse(web.document.baseURI).resolve(assetPath).toString()
    ..async = false;
  final ready = Completer<void>();
  final onLoad = script.onLoad.listen((_) {
    if (!ready.isCompleted) ready.complete();
  });
  final onError = script.onError.listen((_) {
    if (!ready.isCompleted) {
      ready.completeError(
        RealtimeException(
          code: RealtimeErrorCode.webSdkUnavailable,
          message: 'Unable to load $assetPath',
          suggestedAction: 'check-web-assets',
        ),
      );
    }
  });
  web.document.head!.append(script);
  try {
    await ready.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw RealtimeException(
        code: RealtimeErrorCode.webSdkUnavailable,
        message: 'Timed out loading $assetPath',
        suggestedAction: 'check-web-assets',
      ),
    );
  } on Object {
    script.remove();
    rethrow;
  } finally {
    await onLoad.cancel();
    await onError.cancel();
  }
}
