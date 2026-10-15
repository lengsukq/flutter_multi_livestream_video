import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

abstract interface class RealtimeVideoEffectsController
    implements MediaBackgroundEffectsController {
  Future<void> prepareVideoEffects(MediaLocalPreviewSettings settings);
  Future<void> release();
  void beginDisposal();
  Future<void> dispose();
}

/// Optional camera coordination for video-effects implementations.
///
/// Kept separate from [RealtimeVideoEffectsController] to preserve
/// compatibility with third-party effects controllers. When supported,
/// camera publication and background changes share one operation queue.
abstract interface class RealtimeCameraEffectsController {
  Future<void> setCameraEnabled(bool enabled);
}

abstract interface class RealtimeVideoEffects {
  Future<bool> isSupported();
  Future<MediaLocalPreviewSession> createPreview({
    required String providerId,
    required MediaRole role,
  });
  RealtimeVideoEffectsController createController({
    required MediaRoomSession media,
    required MediaBackgroundCapabilities capabilities,
    required void Function(RealtimeException error) reportError,
  });
}

typedef RealtimeVideoEffectsFactory = RealtimeVideoEffects Function();
