import 'http_classroom_repository.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_classroom_core/flutter_realtime_classroom_core.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart'
    show
        RealtimeFeatureContext,
        RealtimeFeaturePlugin,
        RealtimeRoom,
        RealtimeFeatureKey,
        ChatInteractionRevisionTransport,
        MediaInteractionRevisionTransport;
import 'package:flutter_realtime_interaction_core/flutter_realtime_interaction_core.dart';

typedef ClassroomRepositoryFactory =
    ClassroomRepository Function(RealtimeFeatureContext context);

/// Optional, headless educational interactions with existing business logic.
///
/// No new business behavior is implemented by the Demo. The repository may be
/// supplied by the host, or the existing reference HTTP repository is used.
/// The media room must declare meeting mode in its backend metadata.
class ClassroomPreset extends RealtimeFeaturePlugin<ClassroomSession> {
  const ClassroomPreset({
    this.repositoryFactory,
    this.pollInterval = const Duration(seconds: 2),
    this.enableForDirectRooms = false,
  });

  static const featureId = 'classroom';
  static const featureKey = RealtimeFeatureKey<ClassroomSession>(featureId);
  @override
  RealtimeFeatureKey<ClassroomSession> get key => featureKey;
  @override
  String get id => featureId;

  final ClassroomRepositoryFactory? repositoryFactory;
  final Duration pollInterval;

  /// Explicit opt-in for direct rooms that supply their own authority.
  final bool enableForDirectRooms;

  @override
  ClassroomSession? attach(RealtimeFeatureContext context) {
    final media = context.media;
    if (media.backendMetadata['roomMode'] != 'meeting' &&
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
            eventType: 'classroom.state.changed',
          )
        : MediaInteractionRevisionTransport(
            media.session,
            roomCode: media.roomCode,
            eventType: 'classroom.state.changed',
            topic: 'classroom.v1',
          );

    final session = ClassroomSession(
      create?.call(context) ??
          HttpClassroomRepository(
            backendUrl: url!,
            roomCode: media.roomCode,
            participantId: media.participantId,
            participantCredential: credential!,
            roomOwnerCredential: media.roomOwnerCredential,
            tokenProvider: context.tokenProvider,
            requestTimeout:
                context.requestTimeout ?? const Duration(seconds: 10),
          ),
      pollInterval: pollInterval,
      mediaTracks: () => {
        for (final participant in media.session.snapshot.participants)
          participant.id: (
            microphoneOn: participant.isLocal
                ? !media.session.snapshot.localMuted
                : participant.isSpeaking
                ? true
                : participant.isMuted
                ? false
                : null,
            cameraOn: participant.isVideoEnabled
                ? true
                : participant.videoTrack == null
                ? null
                : false,
          ),
      },
      chatMessages: () => chat?.messages.length ?? 0,
      revisionTransport: _ClassroomRevisionHints(signal),
    );
    return session;
  }

  @override
  Future<void> start(ClassroomSession feature) => feature.start();

  @override
  Future<void> detach(ClassroomSession feature) => feature.dispose();
}

/// Typed access remains opt-in and is no longer compiled into RealtimeRoom.
extension RealtimeRoomClassroomExtension on RealtimeRoom {
  ClassroomSession? get classroomFeature =>
      features.get(ClassroomPreset.featureKey);
  ClassroomSession? get classroom => classroomFeature;
}

class _ClassroomRevisionHints implements ClassroomRevisionTransport {
  const _ClassroomRevisionHints(this.delegate);
  final InteractionRevisionTransport delegate;
  @override
  Stream<int> get revisions => delegate.revisions;
  @override
  Future<void> publish(int revision) => delegate.publish(revision);
  @override
  Future<void> dispose() => delegate.dispose();
}
