import 'package:flutter_realtime_sdk_base/flutter_realtime_sdk_base.dart'
    as base;
import 'package:flutter_realtime_sdk_base/flutter_realtime_sdk_base.dart'
    hide RealtimeSdk, Realtime;
import 'realtime_sdk.dart';
export 'package:flutter_realtime_sdk_base/src/realtime_facade.dart'
    show RealtimeStandaloneChatProvisionerFactory;

class Realtime extends base.Realtime {
  // The narrowed SDK type preserves the full-package API.
  // ignore: use_super_parameters
  Realtime.fromSdk(RealtimeSdk sdk, {super.standaloneChatProvisionerFactory})
    : super.fromSdk(sdk);
  @override
  RealtimeSdk get sdk => super.sdk as RealtimeSdk;

  factory Realtime.standard({
    String? backendUrl,
    RealtimeTokenProvider? tokenProvider,
    RealtimeClientFactory? clientFactory,
    RealtimePlatformResolver platformResolver = resolveRealtimeRuntimePlatform,
    Iterable<RealtimeProviderPlugin> additionalPlugins = const [],
    Iterable<RealtimeProviderDriver>? drivers,
    RealtimeProviderWebAssetsLoader? webAssetsLoader,
  }) {
    final sdk = RealtimeSdk.standard(
      backendUrl: backendUrl,
      tokenProvider: tokenProvider,
      clientFactory: clientFactory,
      platformResolver: platformResolver,
      additionalPlugins: additionalPlugins,
      drivers: drivers,
      webAssetsLoader: webAssetsLoader,
    );
    final url = backendUrl?.trim();
    return Realtime.fromSdk(
      sdk,
      standaloneChatProvisionerFactory: url == null || url.isEmpty
          ? null
          : () => HttpStandaloneChatProvisioner(
              ChatBackendConfig.fromUrl(url, tokenProvider: tokenProvider),
            ),
    );
  }
}
