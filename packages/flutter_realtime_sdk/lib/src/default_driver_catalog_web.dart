import 'package:flutter_realtime_chat_agora/flutter_realtime_chat_agora.dart';
import 'package:flutter_realtime_chat_ivs/flutter_realtime_chat_ivs.dart';
import 'package:flutter_realtime_chat_tencent/flutter_realtime_chat_tencent.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_media_livekit/flutter_realtime_media_livekit.dart';
import 'package:flutter_realtime_media_web/flutter_realtime_media_web.dart';

import 'media_adapter.dart';
import 'provider_driver.dart';
import 'provider_plugin.dart';
import 'runtime_platform.dart';

const _web = {RealtimeRuntimePlatform.web};

List<RealtimeProviderDriver> createDefaultRealtimeDrivers() => [
  RealtimeProviderDriver(
    platforms: _web,
    plugin: RealtimeProviderPlugin(
      id: 'livekit',
      metadata: const RealtimeProviderMetadata(displayName: 'LiveKit'),
      mediaFactory: const LiveKitSessionFactory(),
      renderer: LiveKitTrackRenderer(),
    ),
  ),
  for (final provider in const [
    ('agora', 'Agora'),
    ('trtc', 'Tencent TRTC'),
    ('artc', 'Alibaba ARTC'),
  ])
    RealtimeProviderDriver(
      platforms: _web,
      plugin: RealtimeProviderPlugin(
        id: provider.$1,
        metadata: RealtimeProviderMetadata(displayName: provider.$2),
        mediaFactory: ProviderWebSessionFactory(provider.$1),
        renderer: ProviderWebTrackRenderer(),
      ),
    ),
  RealtimeProviderDriver(
    platforms: _web,
    publicProviderId: 'aws',
    mediaRoomModes: const {MediaRoomMode.meeting},
    plugin: RealtimeProviderPlugin(
      id: 'chime',
      metadata: const RealtimeProviderMetadata(displayName: 'AWS'),
      mediaFactory: ProviderWebSessionFactory('chime'),
      renderer: ProviderWebTrackRenderer(),
    ),
  ),
  RealtimeProviderDriver(
    platforms: _web,
    publicProviderId: 'aws',
    mediaRoomModes: const {MediaRoomMode.broadcast},
    plugin: RealtimeProviderPlugin(
      id: 'ivs',
      metadata: const RealtimeProviderMetadata(displayName: 'AWS'),
      mediaFactory: ProviderWebSessionFactory('ivs'),
      renderer: ProviderWebTrackRenderer(),
    ),
  ),
  RealtimeProviderDriver(
    platforms: _web,
    plugin: const RealtimeProviderPlugin(
      id: 'agora-chat',
      metadata: RealtimeProviderMetadata(displayName: 'Agora Chat'),
      chatFactory: AgoraChatSessionFactory(),
    ),
  ),
  RealtimeProviderDriver(
    platforms: _web,
    plugin: const RealtimeProviderPlugin(
      id: 'ivs-chat',
      metadata: RealtimeProviderMetadata(displayName: 'Amazon IVS Chat'),
      chatFactory: IvsChatSessionFactory(),
    ),
  ),
  RealtimeProviderDriver(
    platforms: _web,
    plugin: const RealtimeProviderPlugin(
      id: 'tencent-chat',
      metadata: RealtimeProviderMetadata(displayName: 'Tencent Chat'),
      chatFactory: TencentChatSessionFactory(),
    ),
  ),
];
