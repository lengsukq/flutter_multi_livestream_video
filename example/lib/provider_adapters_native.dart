import 'dart:io';

import 'package:flutter_realtime_media_agora/flutter_realtime_media_agora.dart';
import 'package:flutter_realtime_media_artc/flutter_realtime_media_artc.dart';
import 'package:flutter_realtime_media_chime/flutter_realtime_media_chime.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_media_ivs/flutter_realtime_media_ivs.dart';
import 'package:flutter_realtime_media_livekit/flutter_realtime_media_livekit.dart';
import 'package:flutter_realtime_media_trtc/flutter_realtime_media_trtc.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_chat_ivs/flutter_realtime_chat_ivs.dart';
import 'package:flutter_realtime_chat_tencent/flutter_realtime_chat_tencent.dart';
import 'package:flutter_realtime_chat_agora/flutter_realtime_chat_agora.dart';

import 'provider_adapters_model.dart';

ProviderAdapters createProviderAdapters() => ProviderAdapters(
  registry: MediaRegistry([
    const ArtcSessionFactory(),
    const AgoraSessionFactory(),
    const LiveKitSessionFactory(),
    ChimeSessionFactory(),
    const TrtcSessionFactory(),
    const IvsSessionFactory(),
  ]),
  renderers: const {
    'artc': ArtcTrackRenderer(),
    'agora': AgoraTrackRenderer(),
    'livekit': LiveKitTrackRenderer(),
    'chime': ChimeTrackRenderer(),
    'trtc': TrtcTrackRenderer(),
    'ivs': IvsTrackRenderer(),
  },
  chatRegistry: ChatRegistry([
    const IvsChatSessionFactory(),
    const TencentChatSessionFactory(),
    if (Platform.isAndroid || Platform.isIOS) const AgoraChatSessionFactory(),
  ]),
);
