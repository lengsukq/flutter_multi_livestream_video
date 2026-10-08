import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'provider_bundle.dart';
import 'provider_driver.dart';
import 'provider_web_session_wrapper.dart';
import 'realtime_client.dart';
import 'realtime_facade.dart';
import 'realtime_sdk.dart';
import 'runtime_platform.dart';

/// Explicit provider composition without any vendor SDK default dependency.
class RealtimeLite extends Realtime {
  RealtimeLite._(super.sdk, {super.standaloneChatProvisionerFactory})
    : super.fromSdk();

  factory RealtimeLite({
    required Iterable<RealtimeProviderBundle> providers,
    String? backendUrl,
    RealtimeTokenProvider? tokenProvider,
    RealtimePlatformResolver platformResolver = resolveRealtimeRuntimePlatform,
  }) {
    final bundles = providers.toList();
    if (bundles.isEmpty) {
      throw ArgumentError.value(
        providers,
        'providers',
        'At least one provider is required',
      );
    }
    final registry = RealtimeDriverRegistry(
      bundles.expand((b) => b.drivers),
      platformResolver: platformResolver,
    );
    final plugins = bundles.expand((bundle) {
      final ownRegistry = RealtimeDriverRegistry(
        bundle.drivers,
        platformResolver: platformResolver,
      );
      final resolved = ownRegistry.resolvePlugins();
      return registry.platform == RealtimeRuntimePlatform.web
          ? wrapWebProviderPlugins(resolved, bundle.webAssetsLoader)
          : resolved;
    });
    final sdk = RealtimeSdk(
      backendUrl: backendUrl,
      plugins: plugins,
      driverRegistry: registry,
      tokenProvider: tokenProvider,
    );
    final url = backendUrl?.trim();
    return RealtimeLite._(
      sdk,
      standaloneChatProvisionerFactory: url == null || url.isEmpty
          ? null
          : () => HttpStandaloneChatProvisioner(
              ChatBackendConfig.fromUrl(url, tokenProvider: tokenProvider),
            ),
    );
  }
}
