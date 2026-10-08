import 'package:flutter_realtime_sdk_base/flutter_realtime_sdk_base.dart';

Future<void> loadAssets({
  Iterable<String> mediaProviderIds = const [],
  bool includeProductChat = false,
  bool includeAllMediaProviders = false,
}) async {
  if (!includeProductChat) return;
  await loadRealtimeBundledWebScript(
    'assets/packages/flutter_realtime_provider_agora_chat/assets/agora-chat-provider.js',
  );
}
