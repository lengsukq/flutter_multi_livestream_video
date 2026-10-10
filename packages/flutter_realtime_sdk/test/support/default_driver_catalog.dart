// Provider inventory is test-only. The production SDK has no provider deps.
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_realtime_provider_livekit/flutter_realtime_provider_livekit.dart';
import 'package:flutter_realtime_provider_agora/flutter_realtime_provider_agora.dart';
import 'package:flutter_realtime_provider_trtc/flutter_realtime_provider_trtc.dart';
import 'package:flutter_realtime_provider_artc/flutter_realtime_provider_artc.dart';
import 'package:flutter_realtime_provider_aws/flutter_realtime_provider_aws.dart';
import 'package:flutter_realtime_provider_agora_chat/flutter_realtime_provider_agora_chat.dart';
import 'package:flutter_realtime_provider_ivs_chat/flutter_realtime_provider_ivs_chat.dart';
import 'package:flutter_realtime_provider_tencent_chat/flutter_realtime_provider_tencent_chat.dart';

List<RealtimeProviderDriver> createDefaultRealtimeDrivers() => [
  ...createLivekitProvider().drivers,
  ...createAgoraProvider().drivers,
  ...createTrtcProvider().drivers,
  ...createArtcProvider().drivers,
  ...createAwsProvider().drivers,
  ...createAgoraChatProvider().drivers,
  ...createIvsChatProvider().drivers,
  ...createTencentChatProvider().drivers,
];
