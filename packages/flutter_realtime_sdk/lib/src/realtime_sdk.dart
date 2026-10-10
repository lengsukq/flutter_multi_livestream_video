import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart'
    as base;
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart'
    hide RealtimeSdk, Realtime;
export 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart'
    show RealtimeClientFactory;

class RealtimeSdk extends base.RealtimeSdk {
  RealtimeSdk({
    super.backendUrl,
    super.requestTimeout,
    required super.plugins,
    super.tokenProvider,
    super.clientFactory,
    super.interactionControlPlaneFactory,
    super.localRecordingDriverFactory,
    super.featurePlugins,
    super.driverRegistry,
    super.webAssetsLoader,
  });

  factory RealtimeSdk.standard({
    String? backendUrl,
    Duration? requestTimeout,
    RealtimeTokenProvider? tokenProvider,
    RealtimeClientFactory? clientFactory,
    InteractionControlPlaneFactory? interactionControlPlaneFactory,
    RealtimeLocalRecordingDriverFactory? localRecordingDriverFactory,
    Iterable<RealtimeFeaturePlugin> featurePlugins = const [],
    RealtimePlatformResolver platformResolver = resolveRealtimeRuntimePlatform,
    Iterable<RealtimeProviderPlugin> additionalPlugins = const [],
    Iterable<RealtimeProviderDriver> drivers = const [],
    RealtimeProviderWebAssetsLoader? webAssetsLoader,
  }) {
    final registry = RealtimeDriverRegistry(
      drivers,
      platformResolver: platformResolver,
    );
    return RealtimeSdk(
      backendUrl: backendUrl,
      requestTimeout: requestTimeout,
      plugins: registry.resolvePlugins(additionalPlugins: additionalPlugins),
      tokenProvider: tokenProvider,
      clientFactory: clientFactory,
      interactionControlPlaneFactory: interactionControlPlaneFactory,
      localRecordingDriverFactory: localRecordingDriverFactory,
      featurePlugins: featurePlugins,
      driverRegistry: registry,
      webAssetsLoader: webAssetsLoader,
    );
  }
}
