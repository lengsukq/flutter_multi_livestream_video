import 'package:flutter/foundation.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_media_livekit/flutter_realtime_media_livekit.dart';

const _web = {RealtimeRuntimePlatform.web};
List<RealtimeProviderDriver> createDrivers(int maxMessages) => [
  RealtimeProviderDriver(
    platforms: _web,
    plugin: RealtimeProviderPlugin(
      id: 'livekit',
      metadata: const RealtimeProviderMetadata(displayName: 'LiveKit'),
      effectsProbe: (role) => _probeEffects('livekit', role),
      mediaFactory: const LiveKitSessionFactory(),
      renderer: LiveKitTrackRenderer(),
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
