import 'package:flutter_realtime_sdk_base/flutter_realtime_sdk_base.dart';

Future<void> loadAssets({
  Iterable<String> mediaProviderIds = const [],
  bool includeProductChat = false,
  bool includeAllMediaProviders = false,
}) async {
  if (!includeAllMediaProviders &&
      !mediaProviderIds.any(const <String>{'agora'}.contains)) {
    return;
  }
  await loadRealtimeBundledWebScript(
    'assets/packages/flutter_realtime_provider_agora/assets/agora-rtc-sdk.js',
  );
  await loadRealtimeBundledWebScript(
    'assets/packages/flutter_realtime_sdk_base/assets/media-provider-bridge.js',
  );
}
