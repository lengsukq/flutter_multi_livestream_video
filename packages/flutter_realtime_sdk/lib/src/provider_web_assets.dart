import 'provider_web_assets_stub.dart'
    if (dart.library.js_interop) 'provider_web_assets_web.dart'
    as platform;

export 'package:flutter_realtime_sdk_base/src/provider_web_assets.dart'
    show RealtimeProviderWebAssetsLoader;

/// Loads only the SDK-bundled browser runtimes required by a connection.
///
/// Native targets intentionally compile to a no-op implementation.
Future<void> ensureRealtimeProviderWebAssets({
  Iterable<String> mediaProviderIds = const [],
  bool includeProductChat = false,
  bool includeAllMediaProviders = false,
}) => platform.ensureRealtimeProviderWebAssets(
  mediaProviderIds: mediaProviderIds,
  includeProductChat: includeProductChat,
  includeAllMediaProviders: includeAllMediaProviders,
);
