// Demo composition root: the core SDK imports none of these providers.
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_realtime_provider_livekit/flutter_realtime_provider_livekit.dart';
import 'package:flutter_realtime_provider_agora/flutter_realtime_provider_agora.dart';
import 'package:flutter_realtime_provider_trtc/flutter_realtime_provider_trtc.dart';
import 'package:flutter_realtime_provider_artc/flutter_realtime_provider_artc.dart';
import 'package:flutter_realtime_provider_aws/flutter_realtime_provider_aws.dart';
import 'package:flutter_realtime_provider_agora_chat/flutter_realtime_provider_agora_chat.dart';
import 'package:flutter_realtime_provider_ivs_chat/flutter_realtime_provider_ivs_chat.dart';
import 'package:flutter_realtime_provider_tencent_chat/flutter_realtime_provider_tencent_chat.dart';

List<RealtimeProviderBundle> createDemoProviders() => [
  createLivekitProvider(),
  createAgoraProvider(),
  createTrtcProvider(),
  createArtcProvider(),
  createAwsProvider(),
  createAgoraChatProvider(),
  createIvsChatProvider(),
  createTencentChatProvider(),
];
