import 'dart:async';

import 'package:web/web.dart' as web;

import 'realtime_error.dart';

const _mediaScriptsByProvider = <String, String>{
  'artc': 'vendors/aliyun-rtc-sdk.js',
  'agora': 'vendors/agora-rtc-sdk.js',
  'trtc': 'vendors/trtc.js',
  'ivs': 'vendors/amazon-ivs-web-broadcast.js',
  'chime': 'vendors/chime-sdk.js',
};
const _allMediaScripts = <String>[
  'vendors/aliyun-rtc-sdk.js',
  'vendors/agora-rtc-sdk.js',
  'vendors/trtc.js',
  'vendors/amazon-ivs-web-broadcast.js',
  'vendors/chime-sdk.js',
];
final Map<String, Future<void>> _loadedScripts = {};

Future<void> ensureRealtimeProviderWebAssets({
  Iterable<String> mediaProviderIds = const [],
  bool includeProductChat = false,
  bool includeAllMediaProviders = false,
}) async {
  final mediaScripts = <String>{};
  var includeVideoEffects = false;
  if (includeAllMediaProviders) {
    mediaScripts.addAll(_allMediaScripts);
    includeVideoEffects = true;
  } else {
    for (final providerId in mediaProviderIds) {
      final normalized = providerId.trim().toLowerCase();
      final script = _mediaScriptsByProvider[normalized];
      if (script != null) mediaScripts.add(script);
      if (normalized.isNotEmpty) includeVideoEffects = true;
    }
  }

  final loads = <Future<void>>[];
  if (includeVideoEffects) {
    loads.add(_loadVideoEffectsRuntimeScript());
  }
  if (includeProductChat) {
    loads.add(
      _loadProviderRuntimeScript('vendors/realtime-chat-provider-bridge.js'),
    );
  }
  if (mediaScripts.isNotEmpty) {
    for (final scriptPath in mediaScripts) {
      loads.add(_loadProviderRuntimeScript(scriptPath));
    }
    loads.add(_loadProviderRuntimeScript('media-provider-bridge.js'));
  }
  await Future.wait(loads);
}

Future<void> _loadProviderRuntimeScript(String scriptPath) {
  return _loadBundledScript(
    key: 'provider:$scriptPath',
    assetPath:
        'assets/packages/flutter_realtime_sdk/'
        'assets/provider_web_runtime/$scriptPath',
    displayName: scriptPath,
  );
}

Future<void> _loadVideoEffectsRuntimeScript() {
  final current = _loadedScripts['effects:runtime'];
  if (current != null) return current;
  final load = () async {
    await _loadBundledScript(
      key: 'effects:vision',
      assetPath:
          'assets/packages/flutter_realtime_video_effects/'
          'assets/web/vision.js',
      displayName: 'video-effects/vision.js',
    );
    await _loadBundledScript(
      key: 'effects:bridge',
      assetPath:
          'assets/packages/flutter_realtime_video_effects/'
          'assets/web/video-effects-bridge.js',
      displayName: 'video-effects/video-effects-bridge.js',
    );
  }();
  _loadedScripts['effects:runtime'] = load;
  return load.catchError((Object error) {
    _loadedScripts.remove('effects:runtime');
    throw error;
  });
}

Future<void> _loadBundledScript({
  required String key,
  required String assetPath,
  required String displayName,
}) {
  final current = _loadedScripts[key];
  if (current != null) return current;
  final load = _loadScript(assetPath, displayName: displayName);
  _loadedScripts[key] = load;
  return load.catchError((Object error) {
    _loadedScripts.remove(key);
    throw error;
  });
}

Future<void> _loadScript(String assetPath, {required String displayName}) {
  final uri = Uri.parse(web.document.baseURI).resolve(assetPath);
  final source = uri.toString();
  final completer = Completer<void>();
  final script = web.HTMLScriptElement()
    ..src = source
    ..async = false;
  script.onLoad.first.then((_) {
    if (!completer.isCompleted) completer.complete();
  });
  script.onError.first.then((_) {
    if (!completer.isCompleted) {
      completer.completeError(
        RealtimeException(
          code: RealtimeErrorCode.webSdkUnavailable,
          message: 'Unable to load the bundled runtime: $displayName.',
          suggestedAction: 'check-web-assets',
          details: {'asset': assetPath, 'url': source},
        ),
      );
    }
  });
  web.document.head!.append(script);
  return completer.future.timeout(
    const Duration(seconds: 30),
    onTimeout: () => throw RealtimeException(
      code: RealtimeErrorCode.webSdkUnavailable,
      message: 'Timed out loading the bundled runtime: $displayName.',
      suggestedAction: 'check-web-assets',
      details: {'asset': assetPath, 'url': source},
    ),
  );
}
