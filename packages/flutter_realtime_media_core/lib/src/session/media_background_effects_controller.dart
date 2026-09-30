import '../model/media_background_effect.dart';
import '../model/media_role.dart';

/// Optional session/preview surface for local camera background processing.
abstract interface class MediaBackgroundEffectsController {
  MediaBackgroundCapabilities get backgroundCapabilities;

  MediaBackgroundEffect get backgroundEffect;

  Future<void> setBackgroundEffect(MediaBackgroundEffect effect);
}

/// Optional factory-level declaration available before room credentials exist.
abstract interface class MediaBackgroundCapabilitiesProvider {
  MediaBackgroundCapabilities backgroundCapabilitiesFor(MediaRole role);
}
