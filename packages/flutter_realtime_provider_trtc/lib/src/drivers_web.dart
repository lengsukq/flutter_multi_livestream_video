import 'package:flutter/foundation.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_media_web/flutter_realtime_media_web.dart';

const _web = {RealtimeRuntimePlatform.web};
List<RealtimeProviderDriver> createDrivers(int maxMessages) => [
  RealtimeProviderDriver(
    platforms: _web,
    plugin: RealtimeProviderPlugin(
      id: 'trtc',
      metadata: const RealtimeProviderMetadata(displayName: 'Tencent TRTC'),
      effectsProbe: (role) => _probeEffects('trtc', role),
      mediaFactory: ProviderWebSessionFactory('trtc'),
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
