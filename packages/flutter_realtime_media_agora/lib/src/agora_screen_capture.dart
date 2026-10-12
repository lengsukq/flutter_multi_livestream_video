import 'package:agora_rtc_engine/agora_rtc_engine.dart' as agora;
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

/// Platform-specific screen capture is intentionally confined to the Agora
/// adapter. Flutter apps and the Demo only call the MediaSession abstraction.
class AgoraScreenCapture {
  const AgoraScreenCapture();

  Future<void> start(agora.RtcEngine engine, TargetPlatform platform) async {
    switch (platform) {
      case TargetPlatform.android:
        await engine.startScreenCapture(
          const agora.ScreenCaptureParameters2(
            captureVideo: true,
            captureAudio: false,
          ),
        );
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        final sources = await engine.getScreenCaptureSources(
          thumbSize: const agora.SIZE(width: 160, height: 90),
          iconSize: const agora.SIZE(width: 32, height: 32),
          includeScreen: true,
        );
        final displays = sources.where(
          (source) =>
              source.type ==
                  agora.ScreenCaptureSourceType.screencapturesourcetypeScreen &&
              source.sourceId != null,
        );
        if (displays.isEmpty) {
          throw const RealtimeException(
            code: RealtimeErrorCode.unsupportedFeature,
            providerId: 'agora',
            message:
                'Agora found no shareable display. '
                'Grant screen-recording permission and try again.',
          );
        }
        final primary = displays.where(
          (display) => display.primaryMonitor == true,
        );
        await engine.startScreenCaptureByDisplayId(
          displayId:
              (primary.isNotEmpty ? primary.first : displays.first).sourceId!,
          regionRect: const agora.Rectangle(),
          captureParams: const agora.ScreenCaptureParameters(
            frameRate: 10,
            captureMouseCursor: true,
          ),
        );
      case TargetPlatform.iOS:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw const RealtimeException(
          code: RealtimeErrorCode.unsupportedFeature,
          providerId: 'agora',
          message:
              'This platform needs an Agora screen-capture integration '
              'that is not yet supplied by the Flutter adapter.',
        );
    }
  }

  Future<void> stop(agora.RtcEngine engine) => engine.stopScreenCapture();
}
