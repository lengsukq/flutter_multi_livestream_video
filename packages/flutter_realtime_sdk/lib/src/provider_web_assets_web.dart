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
const _chatScripts = {
  'agora-chat': 'vendors/agora-chat-provider.js',
  'ivs-chat': 'vendors/ivs-chat-provider.js',
  'tencent-chat': 'vendors/tencent-chat-provider.js',
};
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
      final normalized = providerId.trim().toLowerCase();
      final script = _mediaScriptsByProvider[normalized];
      if (script != null) mediaScripts.add(script);
    }
  }

  final loads = <Future<void>>[];
  if (includeProductChat) {
    final selected = mediaProviderIds.where(_chatScripts.containsKey).toList();
    for (final id in selected.isEmpty ? _chatScripts.keys : selected) {
      loads.add(_loadProviderRuntimeScript(_chatScripts[id]!));
    }
  }
  if (mediaScripts.isNotEmpty) {
    for (final scriptPath in mediaScripts) {
      loads.add(_loadProviderRuntimeScript(scriptPath));
    }
    loads.add(_loadProviderRuntimeScript('media-provider-bridge.js'));
  }
  await Future.wait(loads);
}

const _runtimePackages = {
  'vendors/aliyun-rtc-sdk.js': 'flutter_realtime_provider_artc',
  'vendors/agora-rtc-sdk.js': 'flutter_realtime_provider_agora',
  'vendors/trtc.js': 'flutter_realtime_provider_trtc',
  'vendors/amazon-ivs-web-broadcast.js': 'flutter_realtime_provider_aws',
  'vendors/chime-sdk.js': 'flutter_realtime_provider_aws',
  'vendors/agora-chat-provider.js': 'flutter_realtime_provider_agora_chat',
  'vendors/ivs-chat-provider.js': 'flutter_realtime_provider_ivs_chat',
  'vendors/tencent-chat-provider.js': 'flutter_realtime_provider_tencent_chat',
};
Future<void> _loadProviderRuntimeScript(String scriptPath) async {
  final package = _runtimePackages[scriptPath] ?? 'flutter_realtime_sdk_base';
  final file = scriptPath.split('/').last;
  if (file == 'trtc.js') {
    await _loadBundledScript(
      key: 'trtc:asset-path',
      assetPath: 'assets/packages/$package/assets/asset-path.js',
      displayName: 'TRTC asset path',
    );
  }
  await _loadBundledScript(
    key: 'provider:$scriptPath',
    assetPath: 'assets/packages/$package/assets/$file',
    displayName: scriptPath,
  );
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
