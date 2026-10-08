import 'video_effects_assets_stub.dart'
    if (dart.library.js_interop) 'video_effects_assets_web.dart'
    as platform;

/// Ensures the bundled effects runtime is ready. Native targets are a no-op.
/// Ordinary media connections do not call this entry point.
Future<void> ensureVideoEffectsWebAssets() =>
    platform.ensureVideoEffectsWebAssets();
