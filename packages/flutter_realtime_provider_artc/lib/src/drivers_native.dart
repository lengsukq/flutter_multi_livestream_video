import 'package:flutter_realtime_sdk_base/flutter_realtime_sdk_base.dart';
import 'package:flutter_realtime_media_artc/flutter_realtime_media_artc.dart';

const _mobileAndMac = {
  RealtimeRuntimePlatform.android,
  RealtimeRuntimePlatform.ios,
  RealtimeRuntimePlatform.macos,
};
List<RealtimeProviderDriver> createDrivers(int maxMessages) => [
  RealtimeProviderDriver(
    platforms: _mobileAndMac,
    plugin: const RealtimeProviderPlugin(
      id: 'artc',
      metadata: RealtimeProviderMetadata(displayName: 'Alibaba ARTC'),
      mediaFactory: ArtcSessionFactory(),
      renderer: ArtcTrackRenderer(),
    ),
  ),
];
