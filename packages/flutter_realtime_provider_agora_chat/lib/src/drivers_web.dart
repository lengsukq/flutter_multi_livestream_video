import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_chat_agora/flutter_realtime_chat_agora.dart';

const _web = {RealtimeRuntimePlatform.web};
List<RealtimeProviderDriver> createDrivers(int maxMessages) => [
  RealtimeProviderDriver(
    platforms: _web,
    plugin: RealtimeProviderPlugin(
      id: 'agora-chat',
      metadata: const RealtimeProviderMetadata(displayName: 'Agora Chat'),
      chatFactory: AgoraChatSessionFactory(maxMessages: maxMessages),
    ),
  ),
];
