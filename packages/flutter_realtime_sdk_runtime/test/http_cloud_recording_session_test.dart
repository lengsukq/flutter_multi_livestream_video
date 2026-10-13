import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';

class _MockBackendTransport implements MediaBackendTransport {
  final requests = <Map<String, dynamic>>[];
  final replies = <MediaBackendTransportResponse>[];
  bool closed = false;
  @override
  Future<MediaBackendTransportResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    String? body,
  }) async {
    requests.add({
      'method': method,
      'uri': uri,
      'headers': headers,
      'body': jsonDecode(body!),
    });
    return replies.removeAt(0);
  }

  @override
  void close() => closed = true;

  void respond(int status, Map<String, dynamic> data) => replies.add(
    MediaBackendTransportResponse(statusCode: status, body: jsonEncode(data)),
  );
}

void main() {
  late _MockBackendTransport backend;
  late HttpCloudRecordingSession session;
  setUp(() {
    backend = _MockBackendTransport();
    session = HttpCloudRecordingSession(
      backendUrl: 'https://demo.example.com',
      roomCode: 'A1234',
      participantId: 'p-host',
      participantCredential: 'host-token',
      roomOwnerCredential: 'owner-token',
      tokenProvider: () async => 'demo-bearer',
      transport: backend,
    );
  });
  tearDown(() => session.dispose());

  test('preserves a failed cloud task reason for presentation', () async {
    backend.respond(200, {
      'provider': 'chime',
      'recordingId': 'task-failed',
      'state': 'failed',
      'error': 'Recording media pipeline was interrupted',
      'canDownload': false,
    });
    final result = await session.queryCloudRecording();
    expect(result.taskState, RecordingTaskState.failed);
    expect(
      result.metadata['error'],
      'Recording media pipeline was interrupted',
    );
    expect(result.metadata['canDownload'], false);
  });

  test(
    'HTTP status survives an HTML failure without exposing its body',
    () async {
      backend.replies.add(
        const MediaBackendTransportResponse(
          statusCode: 503,
          body: '<html>private backend details</html>',
        ),
      );
      await expectLater(
        session.queryCloudRecording(),
        throwsA(
          isA<RealtimeException>()
              .having(
                (error) => error.code,
                'code',
                RealtimeErrorCode.serverError,
              )
              .having(
                (error) => error.message,
                'sanitized message',
                isNot(contains('private backend')),
              ),
        ),
      );
    },
  );

  test('authentication deadline prevents a late recording write', () async {
    final token = Completer<String?>();
    final recorder = HttpCloudRecordingSession(
      backendUrl: 'https://demo.example.com',
      roomCode: 'r',
      participantId: 'p',
      participantCredential: null,
      tokenProvider: () => token.future,
      transport: backend,
      requestTimeout: const Duration(milliseconds: 10),
    );
    await expectLater(
      recorder.startCloudRecording(RecordingOptions.cloud()),
      throwsA(
        isA<RealtimeException>().having(
          (error) => error.code,
          'code',
          RealtimeErrorCode.timeout,
        ),
      ),
    );
    token.complete('late-token');
    await Future<void>.delayed(Duration.zero);
    expect(backend.requests, isEmpty);
    recorder.dispose();
    expect(
      backend.closed,
      isFalse,
      reason: 'Injected transports belong to the host',
    );
  });

  test(
    'dispose while authenticating prevents a late recording write',
    () async {
      final token = Completer<String?>();
      final recorder = HttpCloudRecordingSession(
        backendUrl: 'https://demo.example.com',
        roomCode: 'r',
        participantId: 'p',
        participantCredential: null,
        tokenProvider: () => token.future,
        transport: backend,
      );
      final pending = recorder.startCloudRecording(RecordingOptions.cloud());
      recorder.dispose();
      token.complete('late-token');
      await expectLater(
        pending,
        throwsA(
          isA<RealtimeException>().having(
            (error) => error.code,
            'code',
            RealtimeErrorCode.cancelled,
          ),
        ),
      );
      expect(backend.requests, isEmpty);
    },
  );

  test(
    'exposes provider-neutral recorder readiness without leaking credentials',
    () async {
      backend.respond(200, {
        'provider': 'agora',
        'state': 'idle',
        'recordingAvailable': false,
        'recordingUnavailableReason': 'Linux Recording SDK is missing',
      });
      final result = await session.queryCloudRecording();
      expect(result.metadata['recordingAvailable'], false);
      expect(
        result.metadata['recordingUnavailableReason'],
        'Linux Recording SDK is missing',
      );
      expect(result.metadata.containsKey('AGORA_APP_CERTIFICATE'), false);
    },
  );

  test(
    'passes neutral layout and room management credentials to backend',
    () async {
      backend.respond(200, {
        'provider': 'livekit',
        'recordingId': 'EG_123',
        'state': 'starting',
        'canDownload': false,
      });
      final result = await session.startCloudRecording(
        RecordingOptions.cloud(
          layout: RecordingLayout.speaker,
          qualityPreset: RecordingQualityPreset.fullHd1080p30,
        ),
      );
      expect(result.mode, RecordingMode.cloud);
      expect(result.recordingId, 'EG_123');
      expect(result.taskState, RecordingTaskState.starting);
      final sent = backend.requests.single;
      expect(sent['method'], 'POST');
      expect((sent['uri'] as Uri).path, '/rooms/A1234/recording/start');
      expect((sent['headers'] as Map)['Authorization'], 'Bearer demo-bearer');
      final payload = sent['body'] as Map<String, dynamic>;
      expect(payload['layout'], 'speaker');
      expect(payload['rawProviderParams']['preset'], 'H264_1080P_30');
      expect(payload['requesterParticipantId'], 'p-host');
      expect(payload['participantCredential'], 'host-token');
      expect(payload['roomOwnerCredential'], 'owner-token');
      expect(payload['storage'], isNull);
    },
  );

  test(
    'stopping only starts processing and complete status permits download',
    () async {
      backend.respond(200, {
        'provider': 'livekit',
        'recordingId': 'EG_123',
        'state': 'processing',
        'canDownload': false,
      });
      backend.respond(200, {
        'provider': 'livekit',
        'recordingId': 'EG_123',
        'state': 'completed',
        'canDownload': true,
        'fileName': 'room.mp4',
        'fileSizeBytes': 2024,
      });
      backend.respond(200, {
        'provider': 'livekit',
        'recordingId': 'EG_123',
        'downloadUrl': '/rooms/A1234/recording/export/single-use-token',
      });
      final stopped = await session.stopCloudRecording();
      expect(stopped.taskState, RecordingTaskState.processing);
      expect(stopped.fileSizeBytes, 0);
      final ready = await session.queryCloudRecording();
      expect(ready.metadata['canDownload'], true);
      expect(ready.fileSizeBytes, 2024);
      expect(
        await session.cloudRecordingDownloadUrl(),
        Uri.parse(
          'https://demo.example.com/rooms/A1234/recording/export/single-use-token',
        ),
      );
    },
  );

  test(
    'rejects incomplete provider responses and insecure download URLs',
    () async {
      backend.respond(200, {'state': 'starting'});
      await expectLater(
        session.startCloudRecording(RecordingOptions.cloud()),
        throwsA(isA<RealtimeException>()),
      );
      backend.respond(409, {
        'error': {'message': 'Cloud recording is still processing'},
      });
      await expectLater(
        session.cloudRecordingDownloadUrl(),
        throwsA(isA<RealtimeException>()),
      );
      backend.respond(200, {'downloadUrl': 'http://non-tls.test/file'});
      await expectLater(
        session.cloudRecordingDownloadUrl(),
        throwsA(isA<RealtimeException>()),
      );
    },
  );

  test(
    'LAN Demo HTTP download works only for the configured backend origin',
    () async {
      final local = HttpCloudRecordingSession(
        backendUrl: 'http://192.168.1.20:3000',
        roomCode: 'A1234',
        participantId: 'p-host',
        participantCredential: 'host-token',
        transport: backend,
      );
      backend.respond(200, {
        'downloadUrl': '/rooms/A1234/recording/export/one-time-token',
      });
      expect(
        await local.cloudRecordingDownloadUrl(),
        Uri.parse(
          'http://192.168.1.20:3000/rooms/A1234/recording/export/one-time-token',
        ),
      );
      backend.respond(200, {'downloadUrl': 'http://other-host.local/steal'});
      await expectLater(
        local.cloudRecordingDownloadUrl(),
        throwsA(isA<RealtimeException>()),
      );
    },
  );
}
