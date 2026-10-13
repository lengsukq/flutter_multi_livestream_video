import 'package:flutter/foundation.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
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
      effectsProbe: (role) => _probeEffects('chime', role),
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
      effectsProbe: (role) => _probeEffects('ivs', role),
      mediaFactory: ProviderWebSessionFactory('ivs'),
      renderer: ProviderWebTrackRenderer(),
    ),
  ),
];

Future<MediaBackgroundCapabilities> _probeEffects(
  String engine,
  MediaRole role,
) async {
  if (role == MediaRole.viewer ||
      (!kIsWeb &&
          defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.macOS)) {
    return const MediaBackgroundCapabilities.none();
  }
  return const MediaBackgroundCapabilities(
    canBlur: true,
    canReplaceImage: true,
  );
}
