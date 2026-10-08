import 'package:flutter_realtime_sdk_base/flutter_realtime_sdk_base.dart';
import 'package:flutter_realtime_media_web/flutter_realtime_media_web.dart';

const _web = {RealtimeRuntimePlatform.web};
List<RealtimeProviderDriver> createDrivers(int maxMessages) => [
  RealtimeProviderDriver(
    platforms: _web,
    plugin: RealtimeProviderPlugin(
      id: 'artc',
      metadata: const RealtimeProviderMetadata(displayName: 'Alibaba ARTC'),
      mediaFactory: ProviderWebSessionFactory('artc'),
      renderer: ProviderWebTrackRenderer(),
    ),
  ),
];
