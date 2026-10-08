/// Coordinates the two bundled effects scripts without loading them on probe.
class VideoEffectsRuntimeLoader {
  VideoEffectsRuntimeLoader({required this.loadScript});
  final Future<void> Function(String file) loadScript;
  final Set<String> _loaded = {};
  Future<void>? _pending;

  Future<void> ensureLoaded() {
    final existing = _pending;
    if (existing != null) return existing;
    final future = _load();
    _pending = future;
    return future.catchError((Object error) {
      if (identical(_pending, future)) _pending = null;
      throw error;
    });
  }

  Future<void> _load() async {
    for (final file in ['vision.js', 'video-effects-bridge.js']) {
      if (_loaded.contains(file)) continue;
      await loadScript(file);
      _loaded.add(file);
    }
  }
}
