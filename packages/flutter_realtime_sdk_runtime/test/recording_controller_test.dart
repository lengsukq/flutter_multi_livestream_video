import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';

class _FakeMediaSession extends Fake implements MediaSession {
  @override
  String get providerId => 'agora';

  @override
  MediaRole get role => MediaRole.host;

  @override
  Stream<MediaSessionState> get states => const Stream.empty();

  @override
  Stream<MediaEvent> get events => const Stream.empty();
}

class _FakeCloudSession implements MediaCloudRecordingSession {
  int starts = 0;
  int stops = 0;
  bool disposed = false;
  Completer<void>? startGate;
  Completer<void>? stopGate;

  @override
  Future<RecordingResult> startCloudRecording(RecordingOptions options) async {
    starts++;
    await startGate?.future;
    return const RecordingResult(
      mode: RecordingMode.cloud,
      recordingId: 'cloud-task-1',
      metadata: {'state': 'recording'},
    );
  }

  @override
  Future<RecordingResult> stopCloudRecording() async {
    stops++;
    await stopGate?.future;
    return const RecordingResult(
      mode: RecordingMode.cloud,
      recordingId: 'cloud-task-1',
      metadata: {'state': 'processing', 'canDownload': false},
    );
  }

  @override
  Future<RecordingResult> queryCloudRecording() async => const RecordingResult(
    mode: RecordingMode.cloud,
    recordingId: 'cloud-task-1',
    metadata: {'state': 'completed', 'canDownload': true},
  );

  @override
  Future<Uri> cloudRecordingDownloadUrl() async =>
      Uri.parse('https://backend.example.test/recording/export/ticket');

  @override
  void dispose() => disposed = true;
}

void main() {
  late MediaRoomSession room;
  setUp(() {
    room = MediaRoomSession.direct(
      roomCode: 'unit_test_room',
      participantId: 'user_1',
      session: _FakeMediaSession(),
    );
  });

  test('cloud recording requires a configured backend', () async {
    final controller = RoomRecordingController(
      media: room,
      providerId: 'agora',
    );
    await expectLater(
      controller.startRecording(),
      throwsA(
        isA<RealtimeException>().having(
          (error) => error.code,
          'code',
          RealtimeErrorCode.unsupportedFeature,
        ),
      ),
    );
    expect(controller.status, RecordingStatus.idle);
    await controller.dispose();
  });

  test('cloud start, stop, query and signed download URL', () async {
    final cloud = _FakeCloudSession();
    final controller = RoomRecordingController(
      media: room,
      providerId: 'agora',
      cloudRecordingSession: cloud,
    );
    final start = await controller.startRecording();
    expect(start.recordingId, 'cloud-task-1');
    expect(controller.status, RecordingStatus.recording);
    expect(controller.currentOptions?.mode, RecordingMode.cloud);
    final stopped = await controller.stopRecording();
    expect(stopped?.metadata['state'], 'processing');
    expect(controller.status, RecordingStatus.idle);
    expect(
      (await controller.queryCloudRecording()).metadata['canDownload'],
      true,
    );
    expect(
      (await controller.cloudRecordingDownloadUrl()).host,
      'backend.example.test',
    );
    expect(cloud.starts, 1);
    expect(cloud.stops, 1);
    await controller.dispose();
    expect(cloud.disposed, true);
  });

  test('cloud descriptor preserves provider params', () async {
    final controller = RoomRecordingController(
      media: room,
      providerId: 'agora',
    );
    final blueprint = controller.describeCloudRecording(
      RecordingOptions.cloud(
        layout: RecordingLayout.speaker,
        rawProviderParams: {'customToken': 'xyz987'},
      ),
    );
    expect(blueprint.providerId, 'agora');
    expect(blueprint.payload['cname'], 'unit_test_room');
    expect(blueprint.payload['uid'], 'user_1');
    expect(blueprint.payload['customToken'], 'xyz987');
    await controller.dispose();
  });

  test('duplicate cloud starts are rejected', () async {
    final cloud = _FakeCloudSession();
    final controller = RoomRecordingController(
      media: room,
      providerId: 'trtc',
      cloudRecordingSession: cloud,
    );
    await controller.startRecording();
    await expectLater(
      controller.startRecording(),
      throwsA(
        isA<RealtimeException>().having(
          (error) => error.code,
          'code',
          RealtimeErrorCode.invalidState,
        ),
      ),
    );
    await controller.dispose();
    expect(cloud.stops, 1);
  });

  test('disposal after pending cloud start stops backend task', () async {
    final cloud = _FakeCloudSession()..startGate = Completer<void>();
    final controller = RoomRecordingController(
      media: room,
      providerId: 'agora',
      cloudRecordingSession: cloud,
    );
    final starting = controller.startRecording();
    final disposing = controller.dispose();
    cloud.startGate!.complete();
    await expectLater(starting, throwsA(isA<RealtimeException>()));
    await disposing;
    expect(cloud.stops, 1);
    expect(cloud.disposed, true);
  });

  test('disposal waits for a pending cloud stop', () async {
    final cloud = _FakeCloudSession()..stopGate = Completer<void>();
    final controller = RoomRecordingController(
      media: room,
      providerId: 'livekit',
      cloudRecordingSession: cloud,
    );
    await controller.startRecording();
    final stopping = controller.stopRecording();
    final disposing = controller.dispose();
    cloud.stopGate!.complete();
    final stopped = await stopping;
    await disposing;
    expect(stopped?.recordingId, 'cloud-task-1');
    expect(cloud.stops, 1);
    expect(cloud.disposed, true);
  });
}
