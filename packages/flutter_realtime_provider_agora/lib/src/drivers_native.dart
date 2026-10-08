import 'package:flutter_realtime_sdk_base/flutter_realtime_sdk_base.dart';
import 'package:flutter_realtime_media_agora/flutter_realtime_media_agora.dart';

const _mobileAndMac = {
  RealtimeRuntimePlatform.android,
  RealtimeRuntimePlatform.ios,
  RealtimeRuntimePlatform.macos,
};
const _mobileAndDesktop = {..._mobileAndMac, RealtimeRuntimePlatform.windows};
List<RealtimeProviderDriver> createDrivers(int maxMessages) => [
  RealtimeProviderDriver(
    platforms: _mobileAndDesktop,
    plugin: RealtimeProviderPlugin(
      id: 'agora',
      metadata: const RealtimeProviderMetadata(displayName: 'Agora'),
      mediaFactory: const AgoraSessionFactory(),
      renderer: AgoraTrackRenderer(),
    ),
  ),
];
