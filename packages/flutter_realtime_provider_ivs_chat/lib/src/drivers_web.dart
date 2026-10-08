import 'package:flutter_realtime_sdk_base/flutter_realtime_sdk_base.dart';
import 'package:flutter_realtime_chat_ivs/flutter_realtime_chat_ivs.dart';

const _web = {RealtimeRuntimePlatform.web};
List<RealtimeProviderDriver> createDrivers(int maxMessages) => [
  RealtimeProviderDriver(
    platforms: _web,
    plugin: RealtimeProviderPlugin(
      id: 'ivs-chat',
      metadata: const RealtimeProviderMetadata(displayName: 'Amazon IVS Chat'),
      chatFactory: IvsChatSessionFactory(maxMessages: maxMessages),
    ),
  ),
];
