import 'package:flutter_realtime_chat_agora/flutter_realtime_chat_agora.dart';
import 'package:flutter_realtime_chat_ivs/flutter_realtime_chat_ivs.dart';
import 'package:flutter_realtime_chat_tencent/flutter_realtime_chat_tencent.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_media_agora/flutter_realtime_media_agora.dart';
import 'package:flutter_realtime_media_artc/flutter_realtime_media_artc.dart';
import 'package:flutter_realtime_media_chime/flutter_realtime_media_chime.dart';
import 'package:flutter_realtime_media_ivs/flutter_realtime_media_ivs.dart';
import 'package:flutter_realtime_media_livekit/flutter_realtime_media_livekit.dart';
import 'package:flutter_realtime_media_trtc/flutter_realtime_media_trtc.dart';

import 'media_adapter.dart';
import 'provider_driver.dart';
import 'provider_plugin.dart';
import 'runtime_platform.dart';

const _mobileAndMac = {
  RealtimeRuntimePlatform.android,
  RealtimeRuntimePlatform.ios,
  RealtimeRuntimePlatform.macos,
};
const _mobileAndDesktop = {
  RealtimeRuntimePlatform.android,
  RealtimeRuntimePlatform.ios,
  RealtimeRuntimePlatform.macos,
  RealtimeRuntimePlatform.windows,
};

List<RealtimeProviderDriver> createDefaultRealtimeDrivers() => [
  RealtimeProviderDriver(
    platforms: _mobileAndDesktop,
    plugin: RealtimeProviderPlugin(
      id: 'livekit',
      metadata: const RealtimeProviderMetadata(displayName: 'LiveKit'),
      mediaFactory: const LiveKitSessionFactory(),
      renderer: LiveKitTrackRenderer(),
    ),
  ),
  RealtimeProviderDriver(
    platforms: _mobileAndDesktop,
    plugin: RealtimeProviderPlugin(
      id: 'agora',
      metadata: const RealtimeProviderMetadata(displayName: 'Agora'),
      mediaFactory: const AgoraSessionFactory(),
      renderer: AgoraTrackRenderer(),
    ),
  ),
  RealtimeProviderDriver(
    platforms: _mobileAndDesktop,
    plugin: const RealtimeProviderPlugin(
      id: 'trtc',
      metadata: RealtimeProviderMetadata(displayName: 'Tencent TRTC'),
      mediaFactory: TrtcSessionFactory(),
      renderer: TrtcTrackRenderer(),
    ),
  ),
  RealtimeProviderDriver(
    platforms: _mobileAndMac,
    plugin: const RealtimeProviderPlugin(
      id: 'artc',
      metadata: RealtimeProviderMetadata(displayName: 'Alibaba ARTC'),
      mediaFactory: ArtcSessionFactory(),
      renderer: ArtcTrackRenderer(),
    ),
  ),
  RealtimeProviderDriver(
    platforms: _mobileAndMac,
    publicProviderId: 'aws',
    mediaRoomModes: const {MediaRoomMode.meeting},
    plugin: RealtimeProviderPlugin(
      id: 'chime',
      metadata: const RealtimeProviderMetadata(displayName: 'AWS'),
      mediaFactory: ChimeSessionFactory(),
      renderer: const ChimeTrackRenderer(),
    ),
  ),
  RealtimeProviderDriver(
    platforms: _mobileAndMac,
    publicProviderId: 'aws',
    mediaRoomModes: const {MediaRoomMode.broadcast},
    plugin: const RealtimeProviderPlugin(
      id: 'ivs',
      metadata: RealtimeProviderMetadata(displayName: 'AWS'),
      mediaFactory: IvsSessionFactory(),
      renderer: IvsTrackRenderer(),
    ),
  ),
  RealtimeProviderDriver(
    platforms: const {
      RealtimeRuntimePlatform.android,
      RealtimeRuntimePlatform.ios,
      RealtimeRuntimePlatform.macos,
    },
    plugin: const RealtimeProviderPlugin(
      id: 'agora-chat',
      metadata: RealtimeProviderMetadata(displayName: 'Agora Chat'),
      chatFactory: AgoraChatSessionFactory(),
    ),
  ),
  RealtimeProviderDriver(
    platforms: _mobileAndMac,
    plugin: const RealtimeProviderPlugin(
      id: 'ivs-chat',
      metadata: RealtimeProviderMetadata(displayName: 'Amazon IVS Chat'),
      chatFactory: IvsChatSessionFactory(),
    ),
  ),
  RealtimeProviderDriver(
    platforms: _mobileAndDesktop,
    plugin: const RealtimeProviderPlugin(
      id: 'tencent-chat',
      metadata: RealtimeProviderMetadata(displayName: 'Tencent Chat'),
      chatFactory: TencentChatSessionFactory(),
    ),
  ),
];
