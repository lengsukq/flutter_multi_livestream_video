import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_video_effects/flutter_realtime_video_effects.dart';
import 'src/drivers_native.dart'
    if (dart.library.js_interop) 'src/drivers_web.dart'
    as platform;
import 'src/assets.dart';

RealtimeProviderBundle createArtcProvider({int maxMessages = 500}) {
  if (maxMessages <= 0) {
    throw ArgumentError.value(maxMessages, 'maxMessages', 'must be positive');
  }
  return RealtimeProviderBundle(
    drivers: platform.createDrivers(maxMessages),
    webAssetsLoader: loadAssets,
    videoEffectsFactory: DefaultRealtimeVideoEffects.new,
  );
}
