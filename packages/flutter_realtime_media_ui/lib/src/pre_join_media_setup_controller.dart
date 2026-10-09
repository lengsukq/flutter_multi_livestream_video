import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

/// Local capture device discovery and background selection for Pre-Join.
///
/// The page supplies the preview but does not own asynchronous device results.
/// Discarding a stale device query cannot replace a new preview's device list.
class PreJoinMediaSetupController {
  int _deviceGeneration = 0;
  bool _disposed = false;
  List<MediaDevice> devices = const [];
  Object? deviceError;
  MediaBackgroundEffect backgroundEffect = const MediaBackgroundEffect.none();
  bool updatingBackground = false;

  void resetDevices() {
    ++_deviceGeneration;
    devices = const [];
    deviceError = null;
  }

  void applyCapabilities(MediaBackgroundCapabilities capabilities) {
    if (!capabilities.supports(backgroundEffect)) {
      backgroundEffect = const MediaBackgroundEffect.none();
    }
  }

  Future<void> loadDevices(MediaLocalPreviewSession? preview) async {
    resetDevices();
    if (_disposed || preview == null) return;
    final generation = _deviceGeneration;
    try {
      final updated = await preview.listMediaDevices();
      if (!_disposed && generation == _deviceGeneration) {
        devices = List.unmodifiable(updated);
      }
    } catch (error) {
      if (!_disposed && generation == _deviceGeneration) {
        deviceError = error;
      }
    }
  }

  Future<bool> selectDevice(
    MediaLocalPreviewSession preview,
    MediaDevice device,
  ) async {
    if (_disposed) return false;
    try {
      await preview.selectMediaDevice(device);
      if (_disposed) return false;
      deviceError = null;
      return true;
    } catch (error) {
      if (!_disposed) deviceError = error;
      return false;
    }
  }

  Future<void> applyBackground(
    MediaLocalPreviewSession? preview,
    MediaBackgroundEffect effect,
  ) async {
    if (_disposed || updatingBackground) return;
    updatingBackground = true;
    try {
      if (preview is MediaBackgroundEffectsController) {
        await (preview as MediaBackgroundEffectsController).setBackgroundEffect(
          effect,
        );
      }
      if (!_disposed) backgroundEffect = effect;
    } finally {
      updatingBackground = false;
    }
  }

  void dispose() {
    _disposed = true;
    resetDevices();
  }
}
