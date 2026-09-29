import 'package:flutter_realtime_media_livekit/flutter_realtime_media_livekit.dart';
import 'package:flutter_realtime_media_web/flutter_realtime_media_web.dart';
import 'package:flutter_realtime_chat_ivs/flutter_realtime_chat_ivs.dart';
import 'package:flutter_realtime_chat_tencent/flutter_realtime_chat_tencent.dart';
import 'package:flutter_realtime_chat_agora/flutter_realtime_chat_agora.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';

import 'provider_adapters_model.dart';

/// Only adapters with an actual browser implementation are registered here.
ProviderAdapters createProviderAdapters() => ProviderAdapters(
  plugins: [
    RealtimeProviderPlugin(
      id: 'livekit',
      metadata: const RealtimeProviderMetadata(displayName: 'LiveKit'),
      mediaFactory: LiveKitSessionFactory(),
      renderer: LiveKitTrackRenderer(),
    ),
    RealtimeProviderPlugin(
      id: 'agora',
      metadata: const RealtimeProviderMetadata(displayName: 'Agora'),
      mediaFactory: ProviderWebSessionFactory('agora'),
      renderer: ProviderWebTrackRenderer(),
    ),
    RealtimeProviderPlugin(
      id: 'chime',
      metadata: const RealtimeProviderMetadata(displayName: 'Amazon Chime'),
      mediaFactory: ProviderWebSessionFactory('chime'),
      renderer: ProviderWebTrackRenderer(),
    ),
    RealtimeProviderPlugin(
      id: 'trtc',
      metadata: const RealtimeProviderMetadata(displayName: 'Tencent TRTC'),
      mediaFactory: ProviderWebSessionFactory('trtc'),
      renderer: ProviderWebTrackRenderer(),
    ),
    RealtimeProviderPlugin(
      id: 'artc',
      metadata: const RealtimeProviderMetadata(displayName: 'Alibaba ARTC'),
      mediaFactory: ProviderWebSessionFactory('artc'),
      renderer: ProviderWebTrackRenderer(),
    ),
    RealtimeProviderPlugin(
      id: 'ivs',
      metadata: const RealtimeProviderMetadata(displayName: 'Amazon IVS'),
      mediaFactory: ProviderWebSessionFactory('ivs'),
      renderer: ProviderWebTrackRenderer(),
    ),
    const RealtimeProviderPlugin(
      id: 'agora-chat',
      metadata: RealtimeProviderMetadata(displayName: 'Agora Chat'),
      chatFactory: AgoraChatSessionFactory(),
    ),
    const RealtimeProviderPlugin(
      id: 'ivs-chat',
      metadata: RealtimeProviderMetadata(displayName: 'Amazon IVS Chat'),
      chatFactory: IvsChatSessionFactory(),
    ),
    const RealtimeProviderPlugin(
      id: 'tencent-chat',
      metadata: RealtimeProviderMetadata(displayName: 'Tencent Chat'),
      chatFactory: TencentChatSessionFactory(),
    ),
  ],
);
