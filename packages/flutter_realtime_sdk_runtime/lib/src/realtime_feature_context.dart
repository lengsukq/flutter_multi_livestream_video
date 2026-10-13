import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_interaction_core/flutter_realtime_interaction_core.dart';
import 'realtime_feature_registry.dart';
import 'realtime_feature_key.dart';

/// The optional feature boundary. Plugins can use media/chat and the neutral
/// Interaction API without depending on SDK UI or a particular product flow.
class RealtimeFeatureContext {
  const RealtimeFeatureContext({
    required this.media,
    required this.interactions,
    this.chat,
    this.backendUrl,
    this.tokenProvider,
    this.requestTimeout,
    this.reportError,
    this.features,
  });

  final RealtimeFeatureRegistry? features;
  T? feature<T extends Object>(RealtimeFeatureKey<T> key) => features?.get(key);

  final MediaRoomSession media;
  final ChatSession? chat;
  final InteractionSession Function() interactions;

  /// Optional backend authority used by opt-in feature repositories.
  final String? backendUrl;
  final Future<String?> Function()? tokenProvider;
  final Duration? requestTimeout;

  /// Reports optional feature failures into the room's diagnostic channel.
  final void Function(Object error, StackTrace stack)? reportError;

  String get roomCode => media.roomCode;
  String get participantId => media.participantId;
  String get providerId => media.providerId;
}
