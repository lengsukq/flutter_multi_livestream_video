import 'package:flutter_realtime_sdk_base/flutter_realtime_sdk_base.dart';

Future<void> loadAssets({
  Iterable<String> mediaProviderIds = const [],
  bool includeProductChat = false,
  bool includeAllMediaProviders = false,
}) async {
  if (!includeAllMediaProviders &&
      !mediaProviderIds.any(const <String>{'trtc'}.contains)) {
    return;
  }
  await loadRealtimeBundledWebScript(
    'assets/packages/flutter_realtime_provider_trtc/assets/asset-path.js',
  );
  await loadRealtimeBundledWebScript(
    'assets/packages/flutter_realtime_provider_trtc/assets/trtc.js',
  );
  await loadRealtimeBundledWebScript(
    'assets/packages/flutter_realtime_sdk_base/assets/media-provider-bridge.js',
  );
}
