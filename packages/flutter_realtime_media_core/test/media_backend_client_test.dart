import 'dart:async';
import 'dart:convert';

import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_transport.dart';

void main() {
  late FakeTransport transport;

  MediaBackendClient clientFor(
    FutureOr<MediaBackendTransportResponse> Function(CapturedRequest) handler, {
    MediaTokenProvider? tokenProvider,
    MediaHeadersProvider? headersProvider,
    Duration requestTimeout = const Duration(seconds: 5),
  }) {
    transport = FakeTransport(handler);
    return MediaBackendClient(
      MediaBackendConfig.fromUrl(
        'https://api.example.com/',
        tokenProvider: tokenProvider,
        headersProvider: headersProvider,
        requestTimeout: requestTimeout,
      ),
      transport: transport,
    );
  }

  group('createRoom', () {
    test(
      'sends role, room code, and contract headers without provider',
      () async {
        final client = clientFor(
          (_) => jsonResponse(liveKitJoinPayload()),
          tokenProvider: () => 'app-token',
          headersProvider: () => {'X-App': 'demo'},
        );

        final response = await client.createRoom(
          role: MediaRole.host,
          roomCode: '482913',
          nickname: 'Host A',
          deviceId: 'device-demo-1',
        );

        final request = transport.requests.single;
        expect(request.method, 'POST');
        expect(request.uri.toString(), 'https://api.example.com/rooms');
        expect(request.json, {
          'nickname': 'Host A',
          'role': 'host',
          'roomCode': '482913',
          'deviceId': 'device-demo-1',
        });
        expect(request.headers['Authorization'], 'Bearer app-token');
        expect(request.headers['X-App'], 'demo');
        expect(request.headers[mediaBackendContractHeader], '1');

        expect(response.providerId, 'livekit');
        expect(response.roomCode, '482913');
        expect(response.role, MediaRole.host);
        expect(response.json['livekit'], isA<Map<String, dynamic>>());
      },
    );

    test('omits roomCode when the backend should generate one', () async {
      final client = clientFor(
        (_) => jsonResponse(liveKitJoinPayload(roomCode: '111222')),
      );
      await client.createRoom(role: MediaRole.participant, nickname: 'Leo');
      expect(transport.requests.single.json!.containsKey('roomCode'), isFalse);
    });

    test('rejects empty required arguments locally', () async {
      final client = clientFor((_) => jsonResponse(liveKitJoinPayload()));
      await expectLater(
        client.createRoom(role: MediaRole.participant, nickname: '   '),
        throwsA(
          isA<MediaBackendError>().having(
            (error) => error.code,
            'code',
            MediaBackendErrorCode.invalidArgument,
          ),
        ),
      );
      expect(transport.requests, isEmpty);
    });
  });

  group('joinRoom', () {
    test(
      'posts to the encoded room path and keeps the requested role',
      () async {
        final client = clientFor(
          (_) => jsonResponse(
            liveKitJoinPayload(participantId: 'viewer-1', role: 'viewer'),
          ),
        );

        final response = await client.joinRoom(
          role: MediaRole.viewer,
          roomCode: '482913',
          nickname: 'Viewer 1',
          deviceId: 'device-demo-2',
        );

        final request = transport.requests.single;
        expect(request.uri.path, '/rooms/482913/join');
        expect(request.json, {
          'userId': 'Viewer 1',
          'role': 'viewer',
          'deviceId': 'device-demo-2',
        });
        expect(response.role, MediaRole.viewer);
      },
    );

    test('falls back to the requested room code when omitted', () async {
      final client = clientFor(
        (_) => jsonResponse({
          'provider': 'livekit',
          'participantId': 'p1',
          'livekit': {'url': 'ws://host:7880', 'token': 'jwt'},
        }),
      );

      final response = await client.joinRoom(
        role: MediaRole.participant,
        roomCode: '482913',
        nickname: 'Leo',
      );

      expect(response.roomCode, '482913');
      expect(response.role, MediaRole.participant);
    });
  });

  group('provider resolution', () {
    test(
      'defaults to chime for legacy responses without a provider field',
      () async {
        final client = clientFor((_) => jsonResponse(chimeJoinPayload()));
        final response = await client.createRoom(
          role: MediaRole.participant,
          nickname: 'Leo',
        );

        expect(response.providerId, defaultMediaProviderId);
        expect(response.providerId, 'chime');
        expect(response.json['meeting'], isA<Map<String, dynamic>>());
        expect(response.json['attendee'], isA<Map<String, dynamic>>());
      },
    );

    test('normalizes provider casing', () async {
      final client = clientFor(
        (_) => jsonResponse(liveKitJoinPayload()..['provider'] = ' LiveKit '),
      );
      final response = await client.createRoom(
        role: MediaRole.host,
        nickname: 'Host',
      );
      expect(response.providerId, 'livekit');
    });

    test('rejects a create response without roomCode', () async {
      final client = clientFor(
        (_) => jsonResponse({'provider': 'livekit', 'participantId': 'p1'}),
      );
      await expectLater(
        client.createRoom(role: MediaRole.participant, nickname: 'Leo'),
        throwsA(
          isA<MediaBackendError>().having(
            (error) => error.code,
            'code',
            MediaBackendErrorCode.invalidResponse,
          ),
        ),
      );
    });
  });

  group('presence endpoints', () {
    test('refresh credentials posts the stable participant and role', () async {
      final client = clientFor(
        (_) => jsonResponse(
          liveKitJoinPayload(participantId: 'participant-1', role: 'host'),
        ),
      );

      final response = await client.refreshCredentials(
        roomCode: '482913',
        participantId: 'participant-1',
        role: MediaRole.host,
      );

      expect(
        transport.requests.single.uri.path,
        '/rooms/482913/credentials/refresh',
      );
      expect(transport.requests.single.json, {
        'participantId': 'participant-1',
        'role': 'host',
      });
      expect(response.providerId, 'livekit');
      expect(response.roomCode, '482913');
      expect(response.role, MediaRole.host);
    });

    test('heartbeat, leave, and closeRoom hit the contract paths', () async {
      final client = clientFor((_) => jsonResponse({'ok': true}));

      await client.heartbeat('482913');
      await client.leave('482913', participantId: 'attendee-1');
      await client.closeRoom('482913');

      expect(transport.requests[0].uri.path, '/rooms/482913/heartbeat');
      expect(transport.requests[0].json, isEmpty);
      expect(transport.requests[1].uri.path, '/rooms/482913/leave');
      expect(transport.requests[1].json, {'participantId': 'attendee-1'});
      expect(transport.requests[2].method, 'DELETE');
      expect(transport.requests[2].uri.path, '/rooms/482913');
    });
  });

  group('error mapping', () {
    Future<MediaBackendError> captureError(
      Object? body, {
      int statusCode = 400,
    }) async {
      final client = clientFor(
        (_) => MediaBackendTransportResponse(
          statusCode: statusCode,
          body: body == null ? '' : (body is String ? body : jsonEncode(body)),
        ),
      );
      try {
        await client.heartbeat('482913');
        fail('expected a MediaBackendError');
      } on MediaBackendError catch (error) {
        return error;
      }
    }

    test('maps documented contract codes', () async {
      Future<void> expectCode(
        String contractCode,
        int status,
        MediaBackendErrorCode expected,
      ) async {
        final error = await captureError({
          'contractVersion': 1,
          'error': {'code': contractCode, 'message': 'nope'},
        }, statusCode: status);
        expect(error.code, expected, reason: contractCode);
        expect(error.statusCode, status);
        expect(error.message, 'nope');
      }

      await expectCode('unauthorized', 401, MediaBackendErrorCode.unauthorized);
      await expectCode('forbidden', 403, MediaBackendErrorCode.forbidden);
      await expectCode(
        'room-not-found',
        404,
        MediaBackendErrorCode.roomNotFound,
      );
      await expectCode('room-exists', 409, MediaBackendErrorCode.roomConflict);
      await expectCode(
        'bad-room-code',
        400,
        MediaBackendErrorCode.invalidRoomCode,
      );
      await expectCode(
        'unsupported-provider',
        400,
        MediaBackendErrorCode.unsupportedProvider,
      );
      await expectCode(
        'provider-not-configured',
        503,
        MediaBackendErrorCode.providerNotConfigured,
      );
    });

    test('falls back to status-code classification', () async {
      final unauthorized = await captureError({}, statusCode: 401);
      expect(unauthorized.code, MediaBackendErrorCode.unauthorized);
      final server = await captureError({}, statusCode: 500);
      expect(server.code, MediaBackendErrorCode.serverError);
    });

    test('maps transport failures to network', () async {
      final client = clientFor((_) {
        throw const MediaBackendTransportException('socket closed');
      });
      await expectLater(
        client.heartbeat('482913'),
        throwsA(
          isA<MediaBackendError>().having(
            (error) => error.code,
            'code',
            MediaBackendErrorCode.network,
          ),
        ),
      );
    });

    test('maps timeouts to timeout', () async {
      final client = clientFor((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return jsonResponse({'ok': true});
      }, requestTimeout: const Duration(milliseconds: 5));
      await expectLater(
        client.heartbeat('482913'),
        throwsA(
          isA<MediaBackendError>().having(
            (error) => error.code,
            'code',
            MediaBackendErrorCode.timeout,
          ),
        ),
      );
    });

    test('rejects an unsupported contract version', () async {
      final client = clientFor(
        (_) => jsonResponse({'contractVersion': 99, 'ok': true}),
      );
      await expectLater(
        client.heartbeat('482913'),
        throwsA(
          isA<MediaBackendError>()
              .having(
                (error) => error.code,
                'code',
                MediaBackendErrorCode.invalidResponse,
              )
              .having((error) => error.message, 'message', contains('99')),
        ),
      );
    });

    test('rejects invalid JSON and non-object JSON', () async {
      final invalid = clientFor(
        (_) => const MediaBackendTransportResponse(
          statusCode: 200,
          body: '{not json',
        ),
      );
      await expectLater(
        invalid.heartbeat('482913'),
        throwsA(
          isA<MediaBackendError>().having(
            (error) => error.code,
            'code',
            MediaBackendErrorCode.invalidResponse,
          ),
        ),
      );

      final list = clientFor((_) => jsonResponse([1, 2, 3]));
      await expectLater(
        list.heartbeat('482913'),
        throwsA(
          isA<MediaBackendError>().having(
            (error) => error.code,
            'code',
            MediaBackendErrorCode.invalidResponse,
          ),
        ),
      );
    });

    test('ignores the body when reporting a failed request', () async {
      final client = clientFor(
        (_) => const MediaBackendTransportResponse(
          statusCode: 500,
          body: '<html>gateway</html>',
        ),
      );
      final error = await client
          .heartbeat('482913')
          .then<Object?>((_) => null, onError: (Object error) => error);
      expect(error, isA<MediaBackendError>());
      expect(
        (error! as MediaBackendError).code,
        MediaBackendErrorCode.serverError,
      );
    });
  });

  group('lifecycle', () {
    test('dispose closes only an owned transport', () async {
      final owned = FakeTransport((_) => jsonResponse({'ok': true}));
      final client = MediaBackendClient(
        MediaBackendConfig.fromUrl('http://127.0.0.1:3000'),
        transport: owned,
      );
      expect(client.ownsTransport, isFalse);
      client.dispose();
      expect(owned.closed, isFalse);

      await expectLater(
        client.heartbeat('482913'),
        throwsA(
          isA<MediaBackendError>().having(
            (error) => error.code,
            'code',
            MediaBackendErrorCode.invalidArgument,
          ),
        ),
      );
    });

    test('config validation rejects malformed backend URLs', () {
      expect(
        () => MediaBackendConfig.fromUrl('not-a-url'),
        throwsArgumentError,
      );
      expect(
        () => MediaBackendConfig.fromUrl('ftp://example.com'),
        throwsArgumentError,
      );
      expect(
        () => MediaBackendConfig.fromUrl('https://example.com?x=1'),
        throwsArgumentError,
      );
    });
  });
}
