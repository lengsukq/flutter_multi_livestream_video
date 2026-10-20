import 'package:flutter_realtime_shared_content_preset/flutter_realtime_shared_content_preset.dart';
import 'package:flutter_realtime_classroom_preset/flutter_realtime_classroom_preset.dart'
    show
        ClassroomPreset,
        RealtimeRoomClassroomExtension,
        ClassroomRepository,
        ClassroomState,
        ClassroomRole,
        ClassroomStats,
        ClassroomCommand;
import 'package:flutter_realtime_live_preset/flutter_realtime_live_preset.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_video_effects/flutter_realtime_video_effects.dart';
import 'package:flutter_test/flutter_test.dart';

class _Media extends Fake implements MediaSession {
  @override
  String get providerId => 'fake';
  @override
  MediaSessionState get state => MediaSessionState.connected;
  @override
  MediaCapabilities get capabilities => const MediaCapabilities.none();
  @override
  MediaSnapshot get snapshot => MediaSnapshot();
  @override
  Stream<MediaEvent> get events => const Stream.empty();
  @override
  Stream<MediaSessionState> get states => const Stream.empty();
  @override
  Stream<MediaSnapshot> get snapshots => const Stream.empty();
  @override
  Future<void> dispose() async {}
}

class _Presence extends Fake implements MediaRoomPresence {
  @override
  Future<void> heartbeat(String roomCode, {String? participantId}) async {}
  @override
  Future<void> leave(String roomCode, {String? participantId}) async {}
}

class _Management extends Fake implements MediaRoomManagement {}

class _Renderer extends MediaTrackRenderer {
  const _Renderer();
  @override
  Widget buildView(BuildContext context, MediaVideoTrack track) =>
      const SizedBox.shrink();
}

class _Bridge extends VideoEffectsBridge {
  @override
  Stream<VideoEffectsFailure> get failures => const Stream.empty();
}

class _ClassroomRepository implements ClassroomRepository {
  int reads = 0;
  bool closed = false;
  @override
  Future<ClassroomState> snapshot() async {
    reads++;
    return ClassroomState(
      roomCode: 'lesson-1',
      role: ClassroomRole.teacher,
      revision: reads,
      students: [],
      questions: [],
      stats: const ClassroomStats(),
    );
  }

  @override
  Future<ClassroomState> action(ClassroomCommand command) => snapshot();
  @override
  void close() => closed = true;
}

class _LiveRepository implements LiveInteractionRepository {
  int reads = 0;
  bool closed = false;
  @override
  Future<LiveInteractionState> snapshot() async {
    reads++;
    return LiveInteractionState(
      roomCode: 'lesson-1',
      revision: reads,
      selfUserId: 'participant-1',
      recipientId: 'teacher-1',
      canSendGift: true,
    );
  }

  @override
  Future<LiveInteractionState> sendLike({required String eventId}) =>
      snapshot();
  @override
  Future<LiveInteractionState> sendGift(
    String giftId,
    int quantity, {
    required String eventId,
  }) => snapshot();
  @override
  void close() => closed = true;
}

RealtimeRoom _room({
  Map<String, dynamic> metadata = const {},
  Iterable<RealtimeFeaturePlugin<Object>> plugins = const [],
}) => RealtimeRoom(
  media: MediaRoomSession.attach(
    roomCode: 'lesson-1',
    participantId: 'participant-1',
    participantCredential: 'test-token',
    backendMetadata: metadata,
    session: _Media(),
    presence: _Presence(),
    management: _Management(),
    heartbeatInterval: Duration.zero,
  ),
  renderer: const _Renderer(),
  videoEffects: DefaultRealtimeVideoEffects(bridge: _Bridge()),
  featurePlugins: plugins,
  disposeClients: () {},
);

void main() {
  test(
    'standard meetings skip teaching while shared content works independently',
    () async {
      final teaching = _ClassroomRepository();
      final memory = MemoryWhiteboardRepository();
      final shared = _IndependentSharedRepository(await memory.snapshot());
      await memory.close();
      final room = _room(
        metadata: {'roomMode': 'meeting', 'meetingMode': 'standard'},
        plugins: [
          ClassroomPreset(repositoryFactory: (_) => teaching),
          SharedContentPreset(repositoryFactory: (_) => shared),
        ],
      );
      await room.initialize();
      expect(room.classroom, isNull);
      expect(teaching.reads, 0);
      await room.sharedContent!.start();
      await room.sharedContent!.selectMode(SharedContentMode.whiteboard);
      expect(room.sharedContent!.content!.mode, SharedContentMode.whiteboard);
      expect(room.sharedContent!.screenAnnotations.canEdit, isTrue);
      await room.dispose();
      expect(shared.closed, isTrue);
    },
  );

  test(
    'core meeting without presets never creates classroom or live sessions',
    () async {
      final room = _room(
        metadata: {'roomMode': 'meeting', 'liveInteractions': true},
      );
      await room.initialize();
      expect(room.classroom, isNull);
      expect(room.liveInteractions, isNull);
      expect(room.features.activeIds, isEmpty);
      await room.dispose();
    },
  );

  test(
    'Classroom preset keeps existing headless session and presentation',
    () async {
      final repository = _ClassroomRepository();
      final room = _room(
        metadata: {'roomMode': 'meeting'},
        plugins: [
          ClassroomPreset(
            repositoryFactory: (_) => repository,
            pollInterval: const Duration(days: 1),
          ),
        ],
      );
      // Opt-in presets attach without waiting for the first remote snapshot.
      expect(room.classroom, isNotNull);
      await room.readyFeatures();
      expect(
        room.classroom,
        same(room.features.get(ClassroomPreset.featureKey)),
      );
      await room.initialize();
      expect(repository.reads, 1);
      expect(
        room.sharedContent,
        isNull,
        reason: 'Classroom does not imply shared content or system annotation',
      );
      expect(room.liveInteractions, isNull);
      await room.dispose();
      expect(repository.closed, isTrue);
    },
  );

  test('Live preset keeps gift/like repository and opt-in ownership', () async {
    final repository = _LiveRepository();
    final room = _room(
      metadata: {'liveInteractions': true},
      plugins: [
        LivePreset(
          repositoryFactory: (_) => repository,
          pollInterval: const Duration(days: 1),
        ),
      ],
    );
    await room.initialize();
    expect(
      room.liveInteractions,
      same(room.features.get(LivePreset.featureKey)),
    );
    expect(repository.reads, 1);
    await room.liveInteractions!.sendLike();
    expect(repository.reads, 2);
    await room.dispose();
    expect(repository.closed, isTrue);
  });

  test(
    'direct rooms can opt in to custom authoritative repositories',
    () async {
      final classroomRepository = _ClassroomRepository();
      final liveRepository = _LiveRepository();
      final room = _room(
        plugins: [
          ClassroomPreset(
            enableForDirectRooms: true,
            repositoryFactory: (_) => classroomRepository,
            pollInterval: const Duration(days: 1),
          ),
          LivePreset(
            enableForDirectRooms: true,
            repositoryFactory: (_) => liveRepository,
            pollInterval: const Duration(days: 1),
          ),
        ],
      );
      await room.initialize();
      expect(room.classroom, isNotNull);
      expect(room.liveInteractions, isNotNull);
      expect(classroomRepository.reads, 1);
      expect(liveRepository.reads, 1);
      await room.dispose();
      expect(classroomRepository.closed, isTrue);
      expect(liveRepository.closed, isTrue);
    },
  );

  test(
    'presets skip ineligible rooms without allocating repositories',
    () async {
      final room = _room(
        plugins: [
          ClassroomPreset(
            repositoryFactory: (_) => throw StateError('must not allocate'),
          ),
          LivePreset(
            repositoryFactory: (_) => throw StateError('must not allocate'),
          ),
        ],
      );
      await room.initialize();
      expect(room.features.activeIds, isEmpty);
      await room.dispose();
    },
  );
}

class _IndependentSharedRepository extends SharedContentRepository {
  _IndependentSharedRepository(this.whiteboard);
  final WhiteboardState whiteboard;
  SharedContentMode mode = SharedContentMode.members;
  int revision = 0;
  bool closed = false;
  @override
  Future<SharedContentState> snapshot() async => SharedContentState(
    mode: mode,
    whiteboard: whiteboard,
    screen: AnnotationCanvas(),
    canManage: true,
    revision: revision,
  );
  @override
  Future<SharedContentState> action(SharedContentCommand command) async {
    if (command.action == SharedContentAction.mode) {
      mode = SharedContentMode.values.byName(
        command.payload['mode']! as String,
      );
    }
    revision++;
    return snapshot();
  }

  @override
  void close() {
    closed = true;
  }
}
