import 'dart:async';

import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_media_session.dart';
import 'support/fake_transport.dart';

void main() {
  late FakeTransport transport;
  late MediaRegistry registry;
  late FakeMediaSessionFactory factory;

  MediaClient clientFor(
    FutureOr<MediaBackendTransportResponse> Function(CapturedRequest) handler, {
    MediaRegistry? withRegistry,
    Duration heartbeatInterval = const Duration(seconds: 30),
  }) {
    transport = FakeTransport(handler);
    return MediaClient.withConfig(
      MediaBackendConfig.fromUrl(
        'http://127.0.0.1:3000',
        heartbeatInterval: heartbeatInterval,
      ),
      registry: withRegistry ?? registry,
      transport: transport,
    );
  }

  setUp(() {
    factory = FakeMediaSessionFactory();
    registry = MediaRegistry([factory]);
  });

  group('createRoomAndJoin', () {
    test('preserves requested role when backend omits role', () async {
      final transport = FakeTransport(
        (_) => jsonResponse({
          'contractVersion': 1,
          'provider': 'fake',
          'roomCode': '482913',
          'participantId': 'viewer-a',
        }),
      );
      final factory = FakeMediaSessionFactory();
      final client = MediaClient(
        backendUrl: 'https://example.test',
        registry: MediaRegistry([factory]),
        transport: transport,
        heartbeatInterval: Duration.zero,
      );

      final room = await client.createRoomAndJoin(
        nickname: 'Viewer A',
        role: MediaRole.viewer,
      );

      expect(room.role, MediaRole.viewer);
      expect(factory.parsedPayloads.single['role'], 'viewer');
      await room.dispose();
      client.dispose();
    });

    test('registers, joins, and attaches backend presence', () async {
      final client = clientFor(
        (_) => jsonResponse(
          liveKitJoinPayload(
            provider: 'fake',
            participantId: 'host-a',
            role: 'host',
          ),
        ),
        heartbeatInterval: Duration.zero,
      );

      final room = await client.createRoomAndJoin(
        role: MediaRole.host,
        roomCode: '482913',
        nickname: 'Host A',
      );

      expect(room.providerId, 'fake');
      expect(room.roomCode, '482913');
      expect(room.participantId, 'host-a');
      expect(room.session.state, MediaSessionState.connected);
      expect(factory.parsedPayloads.single['provider'], 'fake');
      expect(factory.parsedPayloads.single['role'], 'host');

      await room.dispose();
      expect(room.session.state, MediaSessionState.disposed);
      expect(
        transport.requestsTo('/rooms/482913/leave'),
        isNotEmpty,
        reason: 'dispose must send a best-effort leave',
      );
      client.dispose();
    });

    test('sends heartbeat while the room session is alive', () async {
      final client = clientFor(
        (_) => jsonResponse(
          liveKitJoinPayload(
            provider: 'fake',
            participantId: 'host-a',
            role: 'participant',
          ),
        ),
        heartbeatInterval: const Duration(milliseconds: 20),
      );

      final room = await client.createRoomAndJoin(nickname: 'Leo');
      await Future<void>.delayed(const Duration(milliseconds: 70));

      expect(
        transport.requestsTo('/rooms/482913/heartbeat').length,
        greaterThanOrEqualTo(2),
      );

      await room.dispose();
      client.dispose();
    });

    test('backend heartbeat failures do not stop healthy media', () async {
      var failHeartbeat = false;
      final client = clientFor((request) {
        if (request.uri.path.endsWith('/heartbeat') && failHeartbeat) {
          return MediaBackendTransportResponse(
            statusCode: 500,
            body: '{"error":{"code":"server-error","message":"boom"}}',
          );
        }
        return jsonResponse(
          liveKitJoinPayload(
            provider: 'fake',
            participantId: 'p1',
            role: 'participant',
          ),
        );
      }, heartbeatInterval: const Duration(milliseconds: 20));

      final room = await client.createRoomAndJoin(nickname: 'Leo');
      final errors = <MediaBackendError>[];
      final subscription = room.backendErrors.listen(errors.add);

      failHeartbeat = true;
      await Future<void>.delayed(const Duration(milliseconds: 70));

      expect(errors, isNotEmpty);
      expect(errors.first.code, MediaBackendErrorCode.serverError);
      expect(room.session.state, MediaSessionState.connected);

      await subscription.cancel();
      await room.dispose();
      client.dispose();
    });

    test('missing provider adapter fails before any media work', () async {
      final client = clientFor(
        (_) => jsonResponse(liveKitJoinPayload(provider: 'fake')),
        withRegistry: MediaRegistry(),
      );

      await expectLater(
        client.createRoomAndJoin(nickname: 'Leo'),
        throwsA(
          isA<MediaError>().having(
            (error) => error.code,
            'code',
            MediaErrorCode.providerNotRegistered,
          ),
        ),
      );
      expect(factory.createdSessions, isEmpty);
      client.dispose();
    });

    test('unsupported platform fails with a typed error', () async {
      final unsupported = FakeMediaSessionFactory(isPlatformSupported: false);
      final client = clientFor(
        (_) => jsonResponse(liveKitJoinPayload(provider: 'fake')),
        withRegistry: MediaRegistry([unsupported]),
      );

      await expectLater(
        client.createRoomAndJoin(nickname: 'Leo'),
        throwsA(
          isA<MediaError>().having(
            (error) => error.code,
            'code',
            MediaErrorCode.unsupportedPlatform,
          ),
        ),
      );
      expect(unsupported.createdSessions, isEmpty);
      client.dispose();
    });

    test('role the adapter rejects fails with unsupportedFeature', () async {
      final hostOnly = FakeMediaSessionFactory(
        supportedRoles: const {MediaRole.host},
      );
      final client = clientFor(
        (_) =>
            jsonResponse(liveKitJoinPayload(provider: 'fake', role: 'viewer')),
        withRegistry: MediaRegistry([hostOnly]),
      );

      await expectLater(
        client.createRoomAndJoin(role: MediaRole.viewer, nickname: 'Viewer'),
        throwsA(
          isA<MediaError>().having(
            (error) => error.code,
            'code',
            MediaErrorCode.unsupportedFeature,
          ),
        ),
      );
      client.dispose();
    });

    test('malformed join payload is reported as invalidJoinInfo', () async {
      final client = clientFor(
        (_) => jsonResponse({'provider': 'fake', 'roomCode': '482913'}),
      );

      await expectLater(
        client.createRoomAndJoin(nickname: 'Leo'),
        throwsA(
          isA<MediaError>().having(
            (error) => error.code,
            'code',
            MediaErrorCode.invalidJoinInfo,
          ),
        ),
      );
      client.dispose();
    });

    test(
      'a failed join disposes the session and notifies the backend',
      () async {
        final joinError = MediaError(
          code: MediaErrorCode.permissionDenied,
          message: 'Camera denied.',
          providerId: 'fake',
        );
        final failing = FakeMediaSessionFactory(joinError: joinError);
        final client = clientFor(
          (_) => jsonResponse(
            liveKitJoinPayload(provider: 'fake', participantId: 'p1'),
          ),
          withRegistry: MediaRegistry([failing]),
        );

        await expectLater(
          client.createRoomAndJoin(nickname: 'Leo'),
          throwsA(same(joinError)),
        );

        expect(failing.createdSessions.single.disposeCount, greaterThan(0));
        expect(
          transport.requestsTo('/rooms/482913/leave'),
          isNotEmpty,
          reason: 'a failed join must still release the backend slot',
        );
        client.dispose();
      },
    );
  });

  group('joinRoom', () {
    test(
      'uses the room code from the response when the backend rewrites it',
      () async {
        final client = clientFor(
          (_) => jsonResponse(
            liveKitJoinPayload(
              provider: 'fake',
              roomCode: '999111',
              participantId: 'guest-1',
            ),
          ),
          heartbeatInterval: Duration.zero,
        );

        final room = await client.joinRoom(
          roomCode: '482913',
          nickname: 'Guest',
        );

        expect(room.roomCode, '999111');
        expect(transport.requests.single.uri.path, '/rooms/482913/join');
        await room.dispose();
        client.dispose();
      },
    );
  });
}
