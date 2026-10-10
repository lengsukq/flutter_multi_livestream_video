import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_video_effects/flutter_realtime_video_effects.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Runtime starts classroom once without any UI and owns its cleanup',
    () async {
      final repository = _CountingRepository();
      final room = RealtimeRoom(
        media: MediaRoomSession.direct(
          roomCode: 'r',
          participantId: 'p',
          session: _Media(),
        ),
        renderer: const _Renderer(),
        classroom: ClassroomSession(
          repository,
          pollInterval: const Duration(days: 1),
        ),
        videoEffectsBridge: _Bridge(),
        disposeClients: () {},
      );
      await room.initialize();
      expect(repository.reads, 1);
      await room.initialize();
      expect(repository.reads, 1, reason: 'UI remount must not restart a room');
      await room.dispose();
      expect(repository.closed, isTrue);
    },
  );
  test(
    'early classroom cleanup failure cannot skip media or client cleanup',
    () async {
      final media = _Media();
      var clients = 0;
      final room = RealtimeRoom(
        media: MediaRoomSession.direct(
          roomCode: 'r',
          participantId: 'p',
          session: media,
        ),
        renderer: const _Renderer(),
        classroom: ClassroomSession(_Repository()),
        videoEffectsBridge: _Bridge(),
        disposeClients: () {
          clients++;
        },
      );
      final first = room.dispose();
      final second = room.dispose();
      expect(identical(first, second), true);
      await expectLater(
        first,
        throwsA(
          isA<RealtimeException>()
              .having((e) => e.code, 'code', RealtimeErrorCode.cleanupFailed)
              .having(
                (e) => (e.details as List<CleanupFailure>).map((f) => f.stage),
                'stage',
                contains('classroom'),
              ),
        ),
      );
      expect(media.releases, 1);
      expect(clients, 1);
      expect(identical(room.dispose(), first), true);
    },
  );

  test('public states and registration copy caller collections', () {
    final students = <ClassroomStudent>[];
    final state = ClassroomState(
      roomCode: 'r',
      role: ClassroomRole.student,
      revision: 1,
      students: students,
      questions: [],
      stats: const ClassroomStats(),
    );
    students.add(
      const ClassroomStudent(
        userId: 'x',
        participantId: 'p',
        displayName: 'x',
        online: true,
        handRaised: false,
        canSpeak: false,
      ),
    );
    expect(state.students, isEmpty);
    expect(() => state.students.clear(), throwsUnsupportedError);
    final payload = <String, Object?>{'expectedRevision': 1};
    final command = WhiteboardCommand(
      WhiteboardAction.clear,
      payload,
      eventId: 'e',
    );
    payload['expectedRevision'] = 99;
    expect(command.payload['expectedRevision'], 1);
    expect(() => command.payload.clear(), throwsUnsupportedError);
  });
}

class _CountingRepository extends _Repository {
  int reads = 0;
  bool closed = false;
  @override
  Future<ClassroomState> snapshot() {
    reads++;
    return super.snapshot();
  }

  @override
  void close() {
    closed = true;
  }
}

class _Repository implements ClassroomRepository {
  @override
  Future<ClassroomState> snapshot() async => ClassroomState(
    roomCode: 'r',
    role: ClassroomRole.student,
    revision: 1,
    students: [],
    questions: [],
    stats: const ClassroomStats(),
  );
  @override
  Future<ClassroomState> action(ClassroomCommand command) => snapshot();
  @override
  void close() {
    throw StateError('simulated repository failure');
  }
}

class _Media extends Fake implements MediaSession {
  int releases = 0;
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
  Future<void> dispose() async {
    releases++;
  }
}

class _Bridge extends VideoEffectsBridge {
  @override
  Stream<VideoEffectsFailure> get failures => const Stream.empty();
}

class _Renderer extends MediaTrackRenderer {
  const _Renderer();
  @override
  Widget buildView(BuildContext context, MediaVideoTrack track) =>
      const SizedBox.shrink();
}
