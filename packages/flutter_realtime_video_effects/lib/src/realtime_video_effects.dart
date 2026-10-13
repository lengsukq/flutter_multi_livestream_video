import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'video_effects_bridge.dart';
import 'room_video_effects_controller.dart';
import 'video_effects_local_preview.dart';

class DefaultRealtimeVideoEffects implements RealtimeVideoEffects {
  DefaultRealtimeVideoEffects({VideoEffectsBridge? bridge}) : bridge = bridge ?? VideoEffectsBridge();
  final VideoEffectsBridge bridge;
  @override Future<bool> isSupported() => bridge.isSupported();
  @override Future<MediaLocalPreviewSession> createPreview({required String providerId, required MediaRole role}) => VideoEffectsLocalPreviewSession.create(providerId: providerId, role: role, bridge: bridge);
  @override RealtimeVideoEffectsController createController({required MediaRoomSession media, required MediaBackgroundCapabilities capabilities, required void Function(RealtimeException error) reportError}) => RoomVideoEffectsController(media: media, providerId: media.providerId, effectsCapabilities: capabilities, bridge: bridge, onFailure: reportError);
}
