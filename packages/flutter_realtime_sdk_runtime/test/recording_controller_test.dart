import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';

class _FakeMediaSession implements MediaSession, MediaLocalRecordingSession {
  String? activePath;
  bool supportsRecording = true;

  @override
  Future<RecordingResult> startLocalRecording(RecordingOptions options) async {
    activePath = options.localFilePath;
    if (activePath == null) throw StateError('A test destination is required.');
    final file = File(activePath!);
    await file.writeAsBytes([
      0,
      0,
      0,
      12,
      102,
      116,
      121,
      112,
      105,
      115,
      111,
      109,
    ]);
    return RecordingResult(
      mode: RecordingMode.local,
      localFilePath: activePath,
    );
  }

  @override
  Future<RecordingResult> stopLocalRecording() async {
    final file = File(activePath!);
    return RecordingResult(
      mode: RecordingMode.local,
      localFilePath: activePath,
      fileSizeBytes: await file.length(),
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void downloadLocalRecording(RecordingResult result) {
    throw UnsupportedError(
      'Native test recorder does not implement downloads.',
    );
  }

  @override
  String get providerId => 'agora';

  @override
  MediaRole get role => MediaRole.host;

  @override
  MediaCapabilities get capabilities =>
      MediaCapabilities.meeting().copyWith(canRecordLocal: supportsRecording);

  @override
  MediaSessionState get state => MediaSessionState.connected;

  @override
  MediaSnapshot get snapshot =>
      MediaSnapshot(state: MediaSessionState.connected, participants: []);

  @override
  Stream<MediaSessionState> get states => const Stream.empty();

  @override
  Stream<MediaSnapshot> get snapshots => const Stream.empty();

  @override
  Stream<MediaEvent> get events => const Stream.empty();

  @override
  Future<void> join(MediaJoinInfo joinInfo) async {}

  @override
  Future<void> leave() async {}

  @override
  Future<void> dispose() async {}
}

class _InterruptibleMediaSession extends _FakeMediaSession
    implements MediaRecordingInterruptionSource {
  final StreamController<String> _interruptions =
      StreamController<String>.broadcast();

  @override
  Stream<String> get recordingInterruptions => _interruptions.stream;

  void interrupt(String reason) => _interruptions.add(reason);

  @override
  Future<void> dispose() => _interruptions.close();
}

class _DelayedStartSession extends _FakeMediaSession {
  final Completer<void> releaseStart = Completer<void>();
  bool stopped = false;

  @override
  Future<RecordingResult> startLocalRecording(RecordingOptions options) async {
    await releaseStart.future;
    return super.startLocalRecording(options);
  }

  @override
  Future<RecordingResult> stopLocalRecording() async {
    stopped = true;
    return super.stopLocalRecording();
  }
}

class _DelayedStopSession extends _FakeMediaSession {
  final Completer<void> releaseStop = Completer<void>();

  @override
  Future<RecordingResult> stopLocalRecording() async {
    await releaseStop.future;
    return super.stopLocalRecording();
  }
}

class _FakeCloudSession implements MediaCloudRecordingSession {
  int starts = 0;
  int stops = 0;
  bool disposed = false;

  @override
  Future<RecordingResult> startCloudRecording(RecordingOptions options) async {
    starts++;
    return const RecordingResult(
      mode: RecordingMode.cloud,
      recordingId: 'trtc-task-1',
      metadata: {'state': 'recording', 'provider': 'trtc'},
    );
  }

  @override
  Future<RecordingResult> stopCloudRecording() async {
    stops++;
    return const RecordingResult(
      mode: RecordingMode.cloud,
      recordingId: 'trtc-task-1',
      metadata: {'state': 'processing', 'canDownload': false},
    );
  }

  @override
  Future<RecordingResult> queryCloudRecording() async => const RecordingResult(
    mode: RecordingMode.cloud,
    recordingId: 'trtc-task-1',
    metadata: {'state': 'completed', 'canDownload': true},
  );

  @override
  Future<Uri> cloudRecordingDownloadUrl() async =>
      Uri.parse('https://backend.example.test/recording/export/ticket');

  @override
  void dispose() => disposed = true;
}

void main() {
  late MediaRoomSession roomSession;
  late RoomRecordingController controller;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('rec_test_');
    final session = _FakeMediaSession();
    roomSession = MediaRoomSession.direct(
      roomCode: 'unit_test_room',
      participantId: 'user_1',
      session: session,
    );
    controller = RoomRecordingController(
      media: roomSession,
      providerId: 'agora',
    );
  });

  tearDown(() async {
    await controller.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('RoomRecordingController Tests', () {
    test('starts and stops local recording cleanly', () async {
      final targetFile = '${tempDir.path}/test_rec.mp4';
      expect(controller.status, RecordingStatus.idle);

      final startResult = await controller.startRecording(
        RecordingOptions.local(localFilePath: targetFile),
      );

      expect(startResult.mode, RecordingMode.local);
      expect(startResult.localFilePath, targetFile);
      expect(controller.status, RecordingStatus.recording);

      final file = File(targetFile);
      expect(await file.exists(), isTrue);

      final stopResult = await controller.stopRecording();
      expect(stopResult, isNotNull);
      expect(stopResult!.mode, RecordingMode.local);
      expect(stopResult.localFilePath, targetFile);
      expect(stopResult.fileSizeBytes, greaterThan(0));
      expect(controller.status, RecordingStatus.idle);
    });

    test(
      'provider-neutral controller executes injected TRTC cloud recording and keeps MP4 processing separate',
      () async {
        final cloud = _FakeCloudSession();
        final trtc = RoomRecordingController(
          media: roomSession,
          providerId: 'trtc',
          cloudRecordingSession: cloud,
        );
        final started = await trtc.startRecording(
          RecordingOptions.cloud(layout: RecordingLayout.grid),
        );
        expect(started.recordingId, 'trtc-task-1');
        expect(trtc.status, RecordingStatus.recording);
        final stopped = await trtc.stopRecording();
        expect(stopped?.metadata['state'], 'processing');
        expect(trtc.status, RecordingStatus.idle);
        final result = await trtc.queryCloudRecording();
        expect(result.metadata['canDownload'], isTrue);
        final url = await trtc.cloudRecordingDownloadUrl();
        expect(url.host, 'backend.example.test');
        expect(cloud.starts, 1);
        expect(cloud.stops, 1);
        await trtc.dispose();
        expect(cloud.disposed, isTrue);
      },
    );

    test(
      'generates cloud recording descriptor with parameter pass-through',
      () {
        final descriptor = controller.describeCloudRecording(
          RecordingOptions.cloud(
            layout: RecordingLayout.speaker,
            rawProviderParams: {'customToken': 'xyz987'},
          ),
        );

        expect(descriptor.providerId, 'agora');
        expect(descriptor.payload['cname'], 'unit_test_room');
        expect(descriptor.payload['uid'], 'user_1');
        expect(descriptor.payload['customToken'], 'xyz987');
      },
    );

    test('rejects duplicate startRecording calls', () async {
      final targetFile = '${tempDir.path}/dup_rec.mp4';
      await controller.startRecording(
        RecordingOptions.local(localFilePath: targetFile),
      );

      expect(
        () => controller.startRecording(RecordingOptions.local()),
        throwsA(
          isA<RealtimeException>().having(
            (e) => e.code,
            'code',
            RealtimeErrorCode.invalidState,
          ),
        ),
      );
    });

    test('rejects cloud blueprint as a recording execution', () async {
      await expectLater(
        controller.startRecording(RecordingOptions.cloud()),
        throwsA(
          isA<RealtimeException>().having(
            (error) => error.code,
            'code',
            RealtimeErrorCode.unsupportedFeature,
          ),
        ),
      );
      expect(controller.status, RecordingStatus.idle);
    });

    test(
      'rejects advertised false capability instead of writing fake mp4',
      () async {
        final unsupported = _FakeMediaSession()..supportsRecording = false;
        final other = RoomRecordingController(
          media: MediaRoomSession.direct(
            roomCode: 'unsupported_room',
            participantId: 'user2',
            session: unsupported,
          ),
          providerId: 'agora',
        );
        await expectLater(
          other.startRecording(RecordingOptions.local()),
          throwsA(
            isA<RealtimeException>().having(
              (error) => error.code,
              'code',
              RealtimeErrorCode.unsupportedFeature,
            ),
          ),
        );
        await other.dispose();
      },
    );
    test(
      'can use injected native recorder independently of provider capability',
      () async {
        final provider = _FakeMediaSession()..supportsRecording = false;
        final nativeDriver = _FakeMediaSession();
        final other = RoomRecordingController(
          media: MediaRoomSession.direct(
            roomCode: 'native_room',
            participantId: 'presenter',
            session: provider,
          ),
          providerId: 'chime',
          localRecordingDriver: nativeDriver,
        );
        final path = '${tempDir.path}/native.mp4';
        await other.startRecording(RecordingOptions.local(localFilePath: path));
        final result = await other.stopRecording();
        expect(result?.localFilePath, path);
        expect(result?.fileSizeBytes, greaterThan(0));
        expect(other.status, RecordingStatus.idle);
        await other.dispose();
      },
    );
    test('export requires an optional native exporter', () async {
      final targetFile = '${tempDir.path}/export.mp4';
      await controller.startRecording(
        RecordingOptions.local(localFilePath: targetFile),
      );
      final completed = await controller.stopRecording();
      await expectLater(
        controller.exportRecording(completed!),
        throwsA(
          isA<RealtimeException>().having(
            (e) => e.code,
            'code',
            RealtimeErrorCode.unsupportedFeature,
          ),
        ),
      );
    });
    test(
      'OS capture interruption changes SDK state to failed and clears REC',
      () async {
        final platform = _InterruptibleMediaSession();
        RealtimeException? reportedError;
        final active = RoomRecordingController(
          media: MediaRoomSession.direct(
            roomCode: 'interrupted',
            participantId: 'user',
            session: _FakeMediaSession()..supportsRecording = false,
          ),
          providerId: 'agora',
          localRecordingDriver: platform,
          onFailure: (e) => reportedError = e,
        );
        final path = '${tempDir.path}/interrupted.mp4';
        await active.startRecording(
          RecordingOptions.local(localFilePath: path),
        );
        expect(active.status, RecordingStatus.recording);
        platform.interrupt('Permission revoked');
        await Future<void>.delayed(Duration.zero);
        expect(active.status, RecordingStatus.failed);
        expect(active.currentOptions, null);
        expect(active.currentLocalFilePath, null);
        expect(reportedError?.message, contains('Permission revoked'));
        await active.dispose();
        await platform.dispose();
      },
    );
    test(
      'dispose while permissions pending finalizes a late native start',
      () async {
        final adapter = _DelayedStartSession();
        final native = RoomRecordingController(
          media: MediaRoomSession.direct(
            roomCode: 'pending_permission',
            participantId: 'host',
            session: _FakeMediaSession()..supportsRecording = false,
          ),
          providerId: 'agora',
          localRecordingDriver: adapter,
        );
        final starting = native.startRecording(
          RecordingOptions.local(localFilePath: '${tempDir.path}/pending.mp4'),
        );
        final disposal = native.dispose();
        adapter.releaseStart.complete();
        await expectLater(starting, throwsA(isA<RealtimeException>()));
        await disposal;
        expect(adapter.stopped, true);
        expect(native.status, RecordingStatus.failed);
      },
    );
    test('dispose waits for a pending stop/finalization', () async {
      final adapter = _DelayedStopSession();
      final native = RoomRecordingController(
        media: MediaRoomSession.direct(
          roomCode: 'finalizing',
          participantId: 'host',
          session: adapter,
        ),
        providerId: 'agora',
      );
      await native.startRecording(
        RecordingOptions.local(localFilePath: '${tempDir.path}/finalizing.mp4'),
      );
      final stopping = native.stopRecording();
      final disposal = native.dispose();
      adapter.releaseStop.complete();
      final finished = await stopping;
      await disposal;
      expect(finished?.fileSizeBytes, greaterThan(0));
      expect(native.status, RecordingStatus.idle);
    });
  });
}
