import 'package:flutter_realtime_sdk_base/flutter_realtime_sdk_base.dart';
import 'package:flutter_realtime_media_chime/flutter_realtime_media_chime.dart';
import 'package:flutter_realtime_media_ivs/flutter_realtime_media_ivs.dart';

const _mobileAndMac = {
  RealtimeRuntimePlatform.android,
  RealtimeRuntimePlatform.ios,
  RealtimeRuntimePlatform.macos,
};
List<RealtimeProviderDriver> createDrivers(int maxMessages) => [
  RealtimeProviderDriver(
    platforms: _mobileAndMac,
    publicProviderId: 'aws',
    mediaRoomModes: const {MediaRoomMode.meeting},
    plugin: RealtimeProviderPlugin(
      id: 'chime',
      metadata: const RealtimeProviderMetadata(displayName: 'AWS'),
      mediaFactory: ChimeSessionFactory(),
      renderer: const ChimeTrackRenderer(),
    ),
  ),
  RealtimeProviderDriver(
    platforms: _mobileAndMac,
    publicProviderId: 'aws',
    mediaRoomModes: const {MediaRoomMode.broadcast},
    plugin: const RealtimeProviderPlugin(
      id: 'ivs',
      metadata: RealtimeProviderMetadata(displayName: 'AWS'),
      mediaFactory: IvsSessionFactory(),
      renderer: IvsTrackRenderer(),
    ),
  ),
];
