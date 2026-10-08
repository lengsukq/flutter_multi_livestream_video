import 'package:flutter_realtime_sdk_base/flutter_realtime_sdk_base.dart';
import 'package:flutter_realtime_media_web/flutter_realtime_media_web.dart';

const _web = {RealtimeRuntimePlatform.web};
List<RealtimeProviderDriver> createDrivers(int maxMessages) => [
  RealtimeProviderDriver(
    platforms: _web,
    publicProviderId: 'aws',
    mediaRoomModes: const {MediaRoomMode.meeting},
    plugin: RealtimeProviderPlugin(
      id: 'chime',
      metadata: const RealtimeProviderMetadata(displayName: 'AWS'),
      mediaFactory: ProviderWebSessionFactory('chime'),
      renderer: ProviderWebTrackRenderer(),
    ),
  ),
  RealtimeProviderDriver(
    platforms: _web,
    publicProviderId: 'aws',
    mediaRoomModes: const {MediaRoomMode.broadcast},
    plugin: RealtimeProviderPlugin(
      id: 'ivs',
      metadata: const RealtimeProviderMetadata(displayName: 'AWS'),
      mediaFactory: ProviderWebSessionFactory('ivs'),
      renderer: ProviderWebTrackRenderer(),
    ),
  ),
];
