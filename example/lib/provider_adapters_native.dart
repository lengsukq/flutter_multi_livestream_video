import 'dart:io';

import 'package:flutter_realtime_media_agora/flutter_realtime_media_agora.dart';
import 'package:flutter_realtime_media_artc/flutter_realtime_media_artc.dart';
import 'package:flutter_realtime_media_chime/flutter_realtime_media_chime.dart';
import 'package:flutter_realtime_media_ivs/flutter_realtime_media_ivs.dart';
import 'package:flutter_realtime_media_livekit/flutter_realtime_media_livekit.dart';
import 'package:flutter_realtime_media_trtc/flutter_realtime_media_trtc.dart';
import 'package:flutter_realtime_chat_ivs/flutter_realtime_chat_ivs.dart';
import 'package:flutter_realtime_chat_tencent/flutter_realtime_chat_tencent.dart';
import 'package:flutter_realtime_chat_agora/flutter_realtime_chat_agora.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';

import 'provider_adapters_model.dart';

ProviderAdapters createProviderAdapters() => ProviderAdapters(
  plugins: [
    const RealtimeProviderPlugin(
      id: 'artc',
      metadata: RealtimeProviderMetadata(displayName: 'Alibaba ARTC'),
      mediaFactory: ArtcSessionFactory(),
      renderer: ArtcTrackRenderer(),
    ),
    RealtimeProviderPlugin(
      id: 'agora',
      metadata: const RealtimeProviderMetadata(displayName: 'Agora'),
      mediaFactory: const AgoraSessionFactory(),
      renderer: AgoraTrackRenderer(),
    ),
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)
      const RealtimeProviderPlugin(
        id: 'agora-chat',
        metadata: RealtimeProviderMetadata(displayName: 'Agora Chat'),
        chatFactory: AgoraChatSessionFactory(),
      ),
    const RealtimeProviderPlugin(
      id: 'livekit',
      metadata: RealtimeProviderMetadata(displayName: 'LiveKit'),
      mediaFactory: LiveKitSessionFactory(),
      renderer: LiveKitTrackRenderer(),
    ),
    RealtimeProviderPlugin(
      id: 'chime',
      metadata: const RealtimeProviderMetadata(displayName: 'Amazon Chime'),
      mediaFactory: ChimeSessionFactory(),
      renderer: const ChimeTrackRenderer(),
    ),
    const RealtimeProviderPlugin(
      id: 'trtc',
      metadata: RealtimeProviderMetadata(displayName: 'Tencent TRTC'),
      mediaFactory: TrtcSessionFactory(),
      renderer: TrtcTrackRenderer(),
    ),
    const RealtimeProviderPlugin(
      id: 'ivs',
      metadata: RealtimeProviderMetadata(displayName: 'Amazon IVS'),
      mediaFactory: IvsSessionFactory(),
      renderer: IvsTrackRenderer(),
    ),
    if (Platform.isAndroid || Platform.isIOS)
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
