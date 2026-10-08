import 'package:flutter_realtime_sdk_base/flutter_realtime_sdk_base.dart';
import 'package:flutter_realtime_media_trtc/flutter_realtime_media_trtc.dart';

const _mobileAndMac = {
  RealtimeRuntimePlatform.android,
  RealtimeRuntimePlatform.ios,
  RealtimeRuntimePlatform.macos,
};
const _mobileAndDesktop = {..._mobileAndMac, RealtimeRuntimePlatform.windows};
List<RealtimeProviderDriver> createDrivers(int maxMessages) => [
  RealtimeProviderDriver(
    platforms: _mobileAndDesktop,
    plugin: const RealtimeProviderPlugin(
      id: 'trtc',
      metadata: RealtimeProviderMetadata(displayName: 'Tencent TRTC'),
      mediaFactory: TrtcSessionFactory(),
      renderer: TrtcTrackRenderer(),
    ),
  ),
];
