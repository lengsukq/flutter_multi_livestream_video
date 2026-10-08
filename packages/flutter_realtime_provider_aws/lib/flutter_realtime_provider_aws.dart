import 'package:flutter_realtime_sdk_base/flutter_realtime_sdk_base.dart';
import 'src/drivers_native.dart'
    if (dart.library.js_interop) 'src/drivers_web.dart'
    as platform;
import 'src/assets.dart';

RealtimeProviderBundle createAwsProvider({int maxMessages = 500}) {
  if (maxMessages <= 0) {
    throw ArgumentError.value(maxMessages, 'maxMessages', 'must be positive');
  }
  return RealtimeProviderBundle(
    drivers: platform.createDrivers(maxMessages),
    webAssetsLoader: loadAssets,
  );
}
