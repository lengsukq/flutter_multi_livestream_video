import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_chat_tencent/flutter_realtime_chat_tencent.dart';

const _web = {RealtimeRuntimePlatform.web};
List<RealtimeProviderDriver> createDrivers(int maxMessages) => [
  RealtimeProviderDriver(
    platforms: _web,
    plugin: RealtimeProviderPlugin(
      id: 'tencent-chat',
      metadata: const RealtimeProviderMetadata(displayName: 'Tencent Chat'),
      chatFactory: TencentChatSessionFactory(maxMessages: maxMessages),
    ),
  ),
];
