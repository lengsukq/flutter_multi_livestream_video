import 'package:flutter_realtime_sdk_base/flutter_realtime_sdk_base.dart';
import 'package:flutter_realtime_chat_agora/flutter_realtime_chat_agora.dart';

List<RealtimeProviderDriver> createDrivers(int maxMessages) => [
  RealtimeProviderDriver(
    platforms: const {
      RealtimeRuntimePlatform.android,
      RealtimeRuntimePlatform.ios,
      RealtimeRuntimePlatform.macos,
    },
    plugin: RealtimeProviderPlugin(
      id: 'agora-chat',
      metadata: const RealtimeProviderMetadata(displayName: 'Agora Chat'),
      chatFactory: AgoraChatSessionFactory(maxMessages: maxMessages),
    ),
  ),
];
