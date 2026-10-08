import 'package:flutter_realtime_sdk_base/flutter_realtime_sdk_base.dart';

Future<void> loadAssets({
  Iterable<String> mediaProviderIds = const [],
  bool includeProductChat = false,
  bool includeAllMediaProviders = false,
}) async {
  if (!includeAllMediaProviders &&
      !mediaProviderIds.any(const <String>{'chime', 'ivs'}.contains)) {
    return;
  }
  if (includeAllMediaProviders || mediaProviderIds.contains('chime')) {
    await loadRealtimeBundledWebScript(
      'assets/packages/flutter_realtime_provider_aws/assets/chime-sdk.js',
    );
  }
  if (includeAllMediaProviders || mediaProviderIds.contains('ivs')) {
    await loadRealtimeBundledWebScript(
      'assets/packages/flutter_realtime_provider_aws/assets/amazon-ivs-web-broadcast.js',
    );
  }
  await loadRealtimeBundledWebScript(
    'assets/packages/flutter_realtime_sdk_base/assets/media-provider-bridge.js',
  );
}
