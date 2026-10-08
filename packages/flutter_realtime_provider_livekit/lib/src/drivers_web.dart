import 'package:flutter_realtime_sdk_base/flutter_realtime_sdk_base.dart';
import 'package:flutter_realtime_media_livekit/flutter_realtime_media_livekit.dart';

const _web = {RealtimeRuntimePlatform.web};
List<RealtimeProviderDriver> createDrivers(int maxMessages) => [
  RealtimeProviderDriver(
    platforms: _web,
    plugin: RealtimeProviderPlugin(
      id: 'livekit',
      metadata: const RealtimeProviderMetadata(displayName: 'LiveKit'),
      mediaFactory: const LiveKitSessionFactory(),
      renderer: LiveKitTrackRenderer(),
    ),
  ),
];
