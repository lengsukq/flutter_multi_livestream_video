import 'provider_driver.dart';
import 'provider_web_assets.dart';
import 'realtime_video_effects.dart';

/// A provider's platform drivers and their locally bundled Web resources.
class RealtimeProviderBundle {
  RealtimeProviderBundle({
    required List<RealtimeProviderDriver> drivers,
    required this.webAssetsLoader,
    this.videoEffectsFactory,
  }) : drivers = List.unmodifiable(drivers);
  final List<RealtimeProviderDriver> drivers;
  final RealtimeProviderWebAssetsLoader webAssetsLoader;
  final RealtimeVideoEffectsFactory? videoEffectsFactory;
}
