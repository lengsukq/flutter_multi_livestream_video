import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';

Future<void> loadAssets({
  Iterable<String> mediaProviderIds = const [],
  bool includeProductChat = false,
  bool includeAllMediaProviders = false,
}) async {
  if (!includeProductChat) return;
  await loadRealtimeBundledWebScript(
    'assets/packages/flutter_realtime_provider_ivs_chat/assets/ivs-chat-provider.js',
  );
}
