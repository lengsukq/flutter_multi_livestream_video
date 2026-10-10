import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart'
    as base;
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart'
    hide RealtimeSdk, Realtime;
import 'realtime_sdk.dart';
export 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart'
    show RealtimeStandaloneChatProvisionerFactory;

class Realtime extends base.Realtime {
  // ignore: use_super_parameters
  Realtime.fromSdk(
    base.RealtimeSdk sdk, {
    super.standaloneChatProvisionerFactory,
  }) : super.fromSdk(sdk);
  factory Realtime({
    required Iterable<RealtimeProviderBundle> providers,
    String? backendUrl,
    Duration? requestTimeout,
    RealtimeTokenProvider? tokenProvider,
    InteractionControlPlaneFactory? interactionControlPlaneFactory,
    RealtimeLocalRecordingDriverFactory? localRecordingDriverFactory,
    Iterable<RealtimeFeaturePlugin> featurePlugins = const [],
    RealtimePlatformResolver platformResolver = resolveRealtimeRuntimePlatform,
  }) {
    final configured = base.Realtime(
      providers: providers,
      backendUrl: backendUrl,
      requestTimeout: requestTimeout,
      tokenProvider: tokenProvider,
      interactionControlPlaneFactory: interactionControlPlaneFactory,
      localRecordingDriverFactory: localRecordingDriverFactory,
      featurePlugins: featurePlugins,
      platformResolver: platformResolver,
    );
    return Realtime.fromSdk(
      configured.sdk,
      standaloneChatProvisionerFactory:
          backendUrl == null || backendUrl.trim().isEmpty
          ? null
          : () => HttpStandaloneChatProvisioner(
              ChatBackendConfig.fromUrl(
                backendUrl,
                tokenProvider: tokenProvider,
                requestTimeout: requestTimeout ?? const Duration(seconds: 15),
              ),
            ),
    );
  }

  factory Realtime.standard({
    String? backendUrl,
    Duration? requestTimeout,
    RealtimeTokenProvider? tokenProvider,
    InteractionControlPlaneFactory? interactionControlPlaneFactory,
    Iterable<RealtimeFeaturePlugin> featurePlugins = const [],
    RealtimeClientFactory? clientFactory,
    RealtimePlatformResolver platformResolver = resolveRealtimeRuntimePlatform,
    Iterable<RealtimeProviderPlugin> additionalPlugins = const [],
    Iterable<RealtimeProviderDriver> drivers = const [],
    RealtimeProviderWebAssetsLoader? webAssetsLoader,
  }) {
    final sdk = RealtimeSdk.standard(
      backendUrl: backendUrl,
      requestTimeout: requestTimeout,
      tokenProvider: tokenProvider,
      interactionControlPlaneFactory: interactionControlPlaneFactory,
      featurePlugins: featurePlugins,
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
              ChatBackendConfig.fromUrl(
                url,
                tokenProvider: tokenProvider,
                requestTimeout: requestTimeout ?? const Duration(seconds: 15),
              ),
            ),
    );
  }
}
