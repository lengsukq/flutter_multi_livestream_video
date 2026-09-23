import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_aws_chime/flutter_aws_chime.dart';

const _channel = MethodChannel('com.oneplusdream.aws.chime.methodChannel');

Map<String, Object?> _success([Object? data]) => {
  'success': true,
  'code': null,
  'message': null,
  'data': data,
  'details': null,
};

Map<String, Object?> _joinPayload({String roomCode = '482913'}) => {
  'contractVersion': 1,
  'roomCode': roomCode,
  'meeting': {
    'MeetingId': 'meeting-1',
    'ExternalMeetingId': 'external-1',
    'MediaRegion': 'ap-southeast-1',
    'MediaPlacement': {
      'AudioHostUrl': 'https://audio.example.com',
      'AudioFallbackUrl': 'https://fallback.example.com',
      'SignalingUrl': 'wss://signal.example.com',
      'TurnControlUrl': 'https://turn.example.com',
    },
  },
  'attendee': {
    'AttendeeId': 'attendee-1',
    'ExternalUserId': 'leo',
    'JoinToken': 'short-lived-token',
  },
};

class _CapturedRequest {
  const _CapturedRequest({
    required this.method,
    required this.uri,
    required this.headers,
    required this.body,
  });

  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final String? body;
}

class _FakeTransport implements ChimeBackendTransport {
  _FakeTransport(this.handler);

  final FutureOr<ChimeBackendTransportResponse> Function(_CapturedRequest)
  handler;
  final List<_CapturedRequest> requests = [];
  bool closed = false;

  @override
  Future<ChimeBackendTransportResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    String? body,
  }) async {
    final request = _CapturedRequest(
      method: method,
      uri: uri,
      headers: Map.unmodifiable(headers),
      body: body,
    );
    requests.add(request);
    return handler(request);
  }

  @override
  void close() => closed = true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // ignore: deprecated_member_use
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          return switch (call.method) {
            'listAudioDevices' => _success(<String>[]),
            'initialAudioSelection' => _success(null),
            _ => _success('ok'),
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    // ignore: deprecated_member_use
    debugDefaultTargetPlatformOverride = null;
  });

  test('backend client sends contract, auth, and custom headers', () async {
    late _CapturedRequest captured;
    final transport = _FakeTransport((request) {
      captured = request;
      return ChimeBackendTransportResponse(
        statusCode: 200,
        body: jsonEncode(_joinPayload()),
      );
    });
    final client = ChimeBackendClient(
      ChimeClientConfig.fromUrl(
        'https://api.example.com/chime/',
        tokenProvider: () async => 'app-token',
        headersProvider: () => {'X-Tenant': 'tenant-1'},
      ),
      transport: transport,
    );

    final response = await client.joinRoom(
      roomCode: '482913',
      nickname: 'Leo',
    );

    expect(captured.method, 'POST');
    expect(captured.uri.toString(), 'https://api.example.com/chime/rooms/482913/join');
    expect(captured.headers[chimeBackendContractHeader], '1');
    expect(captured.headers['Authorization'], 'Bearer app-token');
    expect(captured.headers['X-Tenant'], 'tenant-1');
    expect(jsonDecode(captured.body!), {'userId': 'Leo'});
    expect(response.roomCode, '482913');
    expect(response.joinInfo.attendee.attendeeId, 'attendee-1');
  });

  test('createRoom sends the optional room code and parses join info', () async {
    late _CapturedRequest captured;
    final transport = _FakeTransport((request) {
      captured = request;
      return ChimeBackendTransportResponse(
        statusCode: 200,
        body: jsonEncode(_joinPayload(roomCode: 'ABCD12')),
      );
    });
    final client = ChimeBackendClient(
      ChimeClientConfig.fromUrl('https://api.example.com'),
      transport: transport,
    );

    final response = await client.createRoom(
      roomCode: 'ABCD12',
      nickname: 'Leo',
    );

    expect(captured.uri.path, '/rooms');
    expect(jsonDecode(captured.body!), {
      'nickname': 'Leo',
      'roomCode': 'ABCD12',
    });
    expect(response.roomCode, 'ABCD12');
  });

  test('backend errors map to stable typed codes', () async {
    final transport = _FakeTransport(
      (_) => ChimeBackendTransportResponse(
        statusCode: 404,
        body: jsonEncode({
          'contractVersion': 1,
          'error': {
            'code': 'room-not-found',
            'message': 'Missing room.',
          },
        }),
      ),
    );
    final client = ChimeBackendClient(
      ChimeClientConfig.fromUrl('https://api.example.com'),
      transport: transport,
    );

    await expectLater(
      client.joinRoom(roomCode: 'missing', nickname: 'Leo'),
      throwsA(
        isA<ChimeBackendException>()
            .having(
              (error) => error.code,
              'code',
              ChimeBackendErrorCode.roomNotFound,
            )
            .having((error) => error.statusCode, 'status', 404),
      ),
    );
  });

  test('declared incompatible backend contract versions are rejected', () async {
    final payload = _joinPayload()..['contractVersion'] = 2;
    final transport = _FakeTransport(
      (_) => ChimeBackendTransportResponse(
        statusCode: 200,
        body: jsonEncode(payload),
      ),
    );
    final client = ChimeBackendClient(
      ChimeClientConfig.fromUrl('https://api.example.com'),
      transport: transport,
    );

    await expectLater(
      client.joinRoom(roomCode: '482913', nickname: 'Leo'),
      throwsA(
        isA<ChimeBackendException>().having(
          (error) => error.code,
          'code',
          ChimeBackendErrorCode.invalidResponse,
        ),
      ),
    );
  });

  test('high-level client rejects unsupported platforms before HTTP', () async {
    final transport = _FakeTransport(
      (_) => throw StateError('HTTP should not be called'),
    );
    final client = ChimeClient(
      backendUrl: 'https://api.example.com',
      transport: transport,
    );
    // ignore: deprecated_member_use
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

    await expectLater(
      client.joinRoom(roomCode: '482913', nickname: 'Leo'),
      throwsA(
        isA<ChimeException>().having(
          (error) => error.code,
          'code',
          ChimeErrorCode.unsupportedPlatform,
        ),
      ),
    );
    expect(transport.requests, isEmpty);
  });

  test('invalid join response is reported before native media setup', () async {
    final transport = _FakeTransport(
      (_) => const ChimeBackendTransportResponse(
        statusCode: 200,
        body: '{"roomCode":"482913"}',
      ),
    );
    final client = ChimeBackendClient(
      ChimeClientConfig.fromUrl('https://api.example.com'),
      transport: transport,
    );

    await expectLater(
      client.joinRoom(roomCode: '482913', nickname: 'Leo'),
      throwsA(
        isA<ChimeBackendException>().having(
          (error) => error.code,
          'code',
          ChimeBackendErrorCode.invalidResponse,
        ),
      ),
    );
  });

  test('ChimeClient joins media and owns room presence lifecycle', () async {
    final transport = _FakeTransport((request) {
      if (request.uri.path.endsWith('/join')) {
        return ChimeBackendTransportResponse(
          statusCode: 200,
          body: jsonEncode(_joinPayload()),
        );
      }
      return const ChimeBackendTransportResponse(
        statusCode: 200,
        body: '{"contractVersion":1,"ok":true}',
      );
    });
    final client = ChimeClient(
      backendUrl: 'https://api.example.com',
      heartbeatInterval: const Duration(hours: 1),
      transport: transport,
    );

    final room = await client.joinRoom(roomCode: '482913', nickname: 'Leo');
    expect(room.roomCode, '482913');
    expect(room.attendeeId, 'attendee-1');
    expect(room.session.state, MeetingState.connecting);

    await Future<void>.delayed(Duration.zero);
    expect(
      transport.requests.any((request) => request.uri.path.endsWith('/heartbeat')),
      isTrue,
    );

    await room.dispose();
    expect(room.session.state, MeetingState.disposed);
    expect(
      transport.requests.any((request) => request.uri.path.endsWith('/leave')),
      isTrue,
    );

    client.dispose();
    expect(transport.closed, isFalse, reason: 'Injected transports are caller-owned.');
  });

  test('room dispose waits for an in-flight best-effort leave request', () async {
    final leaveStarted = Completer<void>();
    final allowLeaveToFinish = Completer<void>();
    final transport = _FakeTransport((request) async {
      if (request.uri.path.endsWith('/join')) {
        return ChimeBackendTransportResponse(
          statusCode: 200,
          body: jsonEncode(_joinPayload()),
        );
      }
      if (request.uri.path.endsWith('/leave')) {
        if (!leaveStarted.isCompleted) leaveStarted.complete();
        await allowLeaveToFinish.future;
      }
      return const ChimeBackendTransportResponse(
        statusCode: 200,
        body: '{"contractVersion":1,"ok":true}',
      );
    });
    final client = ChimeClient(
      backendUrl: 'https://api.example.com',
      heartbeatInterval: const Duration(hours: 1),
      transport: transport,
    );
    final room = await client.joinRoom(roomCode: '482913', nickname: 'Leo');

    await room.session.leave();
    await leaveStarted.future;

    var disposed = false;
    final disposeFuture = room.dispose().then((_) => disposed = true);
    await Future<void>.delayed(Duration.zero);
    expect(disposed, isFalse);

    allowLeaveToFinish.complete();
    await disposeFuture;
    expect(disposed, isTrue);

    client.dispose();
  });
}
