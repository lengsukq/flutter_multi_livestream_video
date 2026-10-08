import 'provider_driver.dart';
import 'provider_web_assets.dart';

/// A provider's platform drivers and their locally bundled Web resources.
class RealtimeProviderBundle {
  const RealtimeProviderBundle({
    required this.drivers,
    required this.webAssetsLoader,
  });
  final List<RealtimeProviderDriver> drivers;
  final RealtimeProviderWebAssetsLoader webAssetsLoader;
}
