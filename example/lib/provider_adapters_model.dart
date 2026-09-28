import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';

class ProviderAdapters {
  const ProviderAdapters({
    required this.registry,
    required this.renderers,
    required this.chatRegistry,
  });

  final MediaRegistry registry;
  final Map<String, MediaTrackRenderer> renderers;
  final ChatRegistry chatRegistry;
}
