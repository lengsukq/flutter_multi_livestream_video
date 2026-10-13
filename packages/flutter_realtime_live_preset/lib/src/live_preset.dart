import 'http_live_interaction_repository.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_live_core/flutter_realtime_live_core.dart';
import 'package:flutter_realtime_interaction_core/flutter_realtime_interaction_core.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart'
    show
        RealtimeFeatureContext,
        RealtimeFeaturePlugin,
        RealtimeRoom,
        RealtimeFeatureKey,
        ChatInteractionRevisionTransport,
        MediaInteractionRevisionTransport;

typedef LiveRepositoryFactory =
    LiveInteractionRepository Function(RealtimeFeatureContext context);

/// Optional, headless likes/gifts backed by the existing trusted repository.
/// Gift events are demonstration features, NOT payment or currency settlement.
class LivePreset
    extends RealtimeFeaturePlugin<LiveInteractionSession> {
  const LivePreset({
    this.repositoryFactory,
    this.pollInterval = const Duration(seconds: 2),
    this.enableForDirectRooms = false,
  });

  static const featureId = 'live';
  static const featureKey = RealtimeFeatureKey<LiveInteractionSession>(featureId);
  @override
  RealtimeFeatureKey<LiveInteractionSession> get key => featureKey;
  @override
  String get id => featureId;

  final LiveRepositoryFactory? repositoryFactory;
  final Duration pollInterval;

  /// Explicit opt-in for direct rooms with a host-managed authoritative store.
  final bool enableForDirectRooms;

  @override
  LiveInteractionSession? attach(RealtimeFeatureContext context) {
    final media = context.media;
    if (media.backendMetadata['liveInteractions'] != true &&
        !(enableForDirectRooms && repositoryFactory != null)) {
      return null;
    }
    final credential = media.participantCredential;
    final url = context.backendUrl;
    final create = repositoryFactory;
    if (create == null && (url == null || credential == null)) return null;

    final chat = context.chat;
    final ChatSystemMessaging? system = chat is ChatSystemMessaging
        ? chat as ChatSystemMessaging
        : null;
    final InteractionRevisionTransport signal =
        system != null && (chat?.capabilities.canSendMessage ?? false)
        ? ChatInteractionRevisionTransport(
            system,
            roomCode: media.roomCode,
            eventType: 'live.interaction.changed',
          )
        : MediaInteractionRevisionTransport(
            media.session,
            roomCode: media.roomCode,
            eventType: 'live.interaction.changed',
            topic: 'live.interaction.v1',
          );

    return LiveInteractionSession(
      create?.call(context) ??
          HttpLiveInteractionRepository(
            backendUrl: url!,
            roomCode: media.roomCode,
            participantId: media.participantId,
            participantCredential: credential!,
            tokenProvider: context.tokenProvider,
            requestTimeout:
                context.requestTimeout ?? const Duration(seconds: 10),
          ),
      pollInterval: pollInterval,
      revisionTransport: _LiveRevisionHints(signal),
    );
  }

  @override
  Future<void> start(LiveInteractionSession feature) =>
      feature.start();

  @override
  Future<void> detach(LiveInteractionSession feature) =>
      feature.dispose();
}

/// Legacy revision hint adapters have no authority and can be safely wrapped.
class _LiveRevisionHints implements LiveRevisionTransport {
  const _LiveRevisionHints(this.delegate);
  final InteractionRevisionTransport delegate;
  @override
  Stream<int> get revisions => delegate.revisions;
  @override
  Future<void> publish(int revision) => delegate.publish(revision);
  @override
  Future<void> dispose() => delegate.dispose();
}

/// The optional Live package supplies this typed convenience access, not the
/// base RealtimeRoom. Apps that omit this package have no gifting surface.
extension RealtimeRoomLiveExtension on RealtimeRoom {
  LiveInteractionSession? get liveInteractions =>
      features.get(LivePreset.featureKey);
}
