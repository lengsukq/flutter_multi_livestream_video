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
  if (includeAllMediaProviders) {
    mediaScripts.addAll(_allMediaScripts);
  } else {
    for (final providerId in mediaProviderIds) {
      final script = _mediaScriptsByProvider[providerId.trim().toLowerCase()];
      if (script != null) mediaScripts.add(script);
    }
  }

  final loads = <Future<void>>[];
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
  final current = _loadedScripts[scriptPath];
  if (current != null) return current;
  final load = _loadScript(scriptPath);
  _loadedScripts[scriptPath] = load;
  return load.catchError((Object error) {
    _loadedScripts.remove(scriptPath);
    throw error;
  });
}

Future<void> _loadScript(String scriptPath) {
  final uri = Uri.parse(web.document.baseURI).resolve(
    'assets/packages/flutter_realtime_sdk/assets/provider_web_runtime/$scriptPath',
  );
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
          message: 'Unable to load the bundled provider runtime: $scriptPath.',
          suggestedAction: 'check-web-assets',
          details: {'asset': scriptPath, 'url': source},
        ),
      );
    }
  });
  web.document.head!.append(script);
  return completer.future.timeout(
    const Duration(seconds: 30),
    onTimeout: () => throw RealtimeException(
      code: RealtimeErrorCode.webSdkUnavailable,
      message: 'Timed out loading the bundled provider runtime: $scriptPath.',
      suggestedAction: 'check-web-assets',
      details: {'asset': scriptPath, 'url': source},
    ),
  );
}
