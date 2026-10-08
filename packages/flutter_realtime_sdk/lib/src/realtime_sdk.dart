import 'package:flutter_realtime_sdk_base/flutter_realtime_sdk_base.dart'
    as base;
import 'package:flutter_realtime_sdk_base/flutter_realtime_sdk_base.dart'
    hide RealtimeSdk, Realtime, ensureRealtimeProviderWebAssets;
import 'default_driver_catalog.dart';
import 'provider_web_assets.dart';
export 'package:flutter_realtime_sdk_base/src/realtime_sdk.dart'
    show RealtimeClientFactory;

class RealtimeSdk extends base.RealtimeSdk {
  RealtimeSdk({
    super.backendUrl,
    required super.plugins,
    super.tokenProvider,
    super.clientFactory,
    super.driverRegistry,
    RealtimeProviderWebAssetsLoader? webAssetsLoader,
  }) : super(
         webAssetsLoader: webAssetsLoader ?? ensureRealtimeProviderWebAssets,
         chatAssetsLoader: webAssetsLoader == null ? _loadSelectedChat : null,
       );

  factory RealtimeSdk.standard({
    String? backendUrl,
    RealtimeTokenProvider? tokenProvider,
    RealtimeClientFactory? clientFactory,
    RealtimePlatformResolver platformResolver = resolveRealtimeRuntimePlatform,
    Iterable<RealtimeProviderPlugin> additionalPlugins = const [],
    Iterable<RealtimeProviderDriver>? drivers,
    RealtimeProviderWebAssetsLoader? webAssetsLoader,
  }) {
    final registry = RealtimeDriverRegistry(
      drivers ?? createDefaultRealtimeDrivers(),
      platformResolver: platformResolver,
    );
    return RealtimeSdk(
      backendUrl: backendUrl,
      plugins: registry.resolvePlugins(additionalPlugins: additionalPlugins),
      tokenProvider: tokenProvider,
      clientFactory: clientFactory,
      driverRegistry: registry,
      webAssetsLoader: webAssetsLoader,
    );
  }
}

Future<void> _loadSelectedChat(String providerId) async {
  if (!const {'agora-chat', 'ivs-chat', 'tencent-chat'}.contains(providerId)) {
    return;
  }
  await ensureRealtimeProviderWebAssets(
    mediaProviderIds: [providerId],
    includeProductChat: true,
  );
}
