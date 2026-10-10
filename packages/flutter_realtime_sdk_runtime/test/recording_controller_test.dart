import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';

class _FakeMediaSession implements MediaSession {
  @override
  String get providerId => 'agora';

  @override
  MediaRole get role => MediaRole.host;

  @override
  MediaCapabilities get capabilities => const MediaCapabilities.meeting();

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
  });
}
