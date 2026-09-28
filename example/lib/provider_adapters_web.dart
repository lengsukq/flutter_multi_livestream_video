import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_media_livekit/flutter_realtime_media_livekit.dart';
import 'package:flutter_realtime_media_web/flutter_realtime_media_web.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_chat_ivs/flutter_realtime_chat_ivs.dart';

import 'provider_adapters_model.dart';

/// Only adapters with an actual browser implementation are registered here.
ProviderAdapters createProviderAdapters() => ProviderAdapters(
  registry: MediaRegistry([
    const LiveKitSessionFactory(),
    const ProviderWebSessionFactory('agora'),
    const ProviderWebSessionFactory('chime'),
    const ProviderWebSessionFactory('trtc'),
    const ProviderWebSessionFactory('artc'),
    const ProviderWebSessionFactory('ivs'),
  ]),
  renderers: const {
    'livekit': LiveKitTrackRenderer(),
    'agora': ProviderWebTrackRenderer(),
    'chime': ProviderWebTrackRenderer(),
    'trtc': ProviderWebTrackRenderer(),
    'artc': ProviderWebTrackRenderer(),
    'ivs': ProviderWebTrackRenderer(),
  },
  chatRegistry: ChatRegistry([const IvsChatSessionFactory()]),
);
