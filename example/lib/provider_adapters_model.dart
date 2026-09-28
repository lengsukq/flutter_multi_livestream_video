import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

class ProviderAdapters {
  const ProviderAdapters({required this.registry, required this.renderers});

  final MediaRegistry registry;
  final Map<String, MediaTrackRenderer> renderers;
}
