import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

/// Applies device/effect settings before publication, respecting room changes.
class InitialMediaSettingsController {
  Future<void> apply({
    required MediaSession session,
    required MediaBackgroundEffectsController effects,
    Future<void> Function(bool enabled)? setCameraEnabled,
    required MediaLocalPreviewSettings settings,
    required bool Function() isCurrent,
    required bool Function() canEnableMicrophone,
    required void Function(RealtimeException) onError,
  }) async {
    if (session is MediaDeviceController) {
      final devices = session as MediaDeviceController;
      for (final device in [
        settings.microphone,
        settings.camera,
        settings.audioOutput,
      ]) {
        if (!isCurrent()) return;
        if (device == null) continue;
        try {
          await devices.selectMediaDevice(device);
        } catch (error, stack) {
          if (isCurrent()) {
            onError(
              normalizeRealtimeException(
                error,
                domain: 'media',
                operation: 'selectDevice',
                stackTrace: stack,
              ),
            );
          }
        }
      }
    }
    if (!isCurrent()) return;
    var allowVideo = true;
    try {
      await effects.setBackgroundEffect(settings.backgroundEffect);
    } catch (error, stack) {
      allowVideo = !settings.backgroundEffect.enabled;
      if (isCurrent()) {
        onError(
          normalizeRealtimeException(
            error,
            domain: 'videoEffects',
            operation: 'setBackgroundEffect',
            stackTrace: stack,
          ),
        );
      }
    }
    if (!isCurrent() || session is! InteractiveMediaSession) return;
    try {
      await session.setMuted(
        !settings.microphoneEnabled || !canEnableMicrophone(),
      );
      if (!isCurrent()) return;
      await (setCameraEnabled ?? session.setVideoEnabled)(
        settings.cameraEnabled && allowVideo,
      );
    } catch (error, stack) {
      if (isCurrent()) {
        onError(
          normalizeRealtimeException(
            error,
            domain: 'media',
            operation: 'initialSettings',
            stackTrace: stack,
          ),
        );
      }
    }
  }
}
