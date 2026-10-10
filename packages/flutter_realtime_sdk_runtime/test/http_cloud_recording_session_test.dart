import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';

class _MockBackendTransport implements MediaBackendTransport {
  final requests = <Map<String, dynamic>>[];
  final replies = <MediaBackendTransportResponse>[];
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
  void close() {}

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
        RecordingOptions.cloud(layout: RecordingLayout.speaker),
      );
      expect(result.mode, RecordingMode.cloud);
      expect(result.recordingId, 'EG_123');
      expect(result.metadata['state'], 'starting');
      final sent = backend.requests.single;
      expect(sent['method'], 'POST');
      expect((sent['uri'] as Uri).path, '/rooms/A1234/recording/start');
      expect((sent['headers'] as Map)['Authorization'], 'Bearer demo-bearer');
      final payload = sent['body'] as Map<String, dynamic>;
      expect(payload['layout'], 'speaker');
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
      expect(stopped.metadata['state'], 'processing');
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
        throwsStateError,
      );
      backend.respond(409, {
        'error': {'message': 'Cloud recording is still processing'},
      });
      await expectLater(
        session.cloudRecordingDownloadUrl(),
        throwsA(isA<RealtimeException>()),
      );
      backend.respond(200, {'downloadUrl': 'http://non-tls.test/file'});
      await expectLater(session.cloudRecordingDownloadUrl(), throwsStateError);
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
      await expectLater(local.cloudRecordingDownloadUrl(), throwsStateError);
    },
  );
}
