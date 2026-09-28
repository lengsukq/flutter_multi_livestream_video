import 'package:flutter/widgets.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_chat_rtc/flutter_realtime_chat_rtc.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../flutter_realtime_media_core/test/support/fake_media_session.dart';
import '../../flutter_realtime_media_core/test/support/fake_transport.dart';

void main() {
  group('RealtimeMediaAdapters', () {
    test('keeps session factory and renderer under one provider id', () {
      final factory = FakeMediaSessionFactory();
      const renderer = _FakeRenderer();
      final adapters = RealtimeMediaAdapters([
        RealtimeMediaAdapter(sessionFactory: factory, renderer: renderer),
      ]);

      expect(adapters.require('FAKE').renderer, same(renderer));
      expect(adapters.registry.require('fake'), same(factory));
      expect(() => adapters.require('missing'), throwsStateError);
    });

    test('rejects duplicate provider registrations', () {
      expect(
        () => RealtimeMediaAdapters([
          RealtimeMediaAdapter(
            sessionFactory: FakeMediaSessionFactory(),
            renderer: const _FakeRenderer(),
          ),
          RealtimeMediaAdapter(
            sessionFactory: FakeMediaSessionFactory(),
            renderer: const _FakeRenderer(),
          ),
        ]),
        throwsArgumentError,
      );
    });
  });

  group('RealtimeProviderPlugin', () {
    test('builds media registry from a self-describing plugin', () {
      final factory = FakeMediaSessionFactory();
      final registry = RealtimePluginRegistry([
        RealtimeProviderPlugin(
          id: 'fake',
          metadata: const RealtimeProviderMetadata(displayName: 'Fake'),
          mediaFactory: factory,
          renderer: const _FakeRenderer(),
        ),
      ]);

      expect(registry.require('FAKE').metadata.displayName, 'Fake');
      expect(registry.media.registry.require('fake'), same(factory));
    });

    test('rejects duplicate plugin ids', () {
      expect(
        () => RealtimePluginRegistry([
          RealtimeProviderPlugin(
            id: 'fake',
            metadata: const RealtimeProviderMetadata(displayName: 'Fake 1'),
            mediaFactory: FakeMediaSessionFactory(),
            renderer: const _FakeRenderer(),
          ),
          RealtimeProviderPlugin(
            id: 'FAKE',
            metadata: const RealtimeProviderMetadata(displayName: 'Fake 2'),
            mediaFactory: FakeMediaSessionFactory(),
            renderer: const _FakeRenderer(),
          ),
        ]),
        throwsArgumentError,
      );
    });
  });

  group('Realtime error mapping', () {
    test('preserves provider diagnostics and recovery hint', () {
      const source = ChatError(
        code: ChatErrorCode.timeout,
        message: 'chat timed out',
        providerId: 'ivs',
        details: {'request': 'token'},
      );

      final error = mapRealtimeException(source);

      expect(error.code, RealtimeErrorCode.timeout);
      expect(error.providerId, 'ivs');
      expect(error.recoverable, isTrue);
      expect(error.suggestedAction, 'retry');
      expect(error.cause, same(source));
      expect(error.details, {'request': 'token'});
    });
  });

  group('RealtimeClient', () {
    test('joins media-only room and resolves its renderer', () async {
      final factory = FakeMediaSessionFactory();
      const renderer = _FakeRenderer();
      final transport = FakeTransport(
        (_) => jsonResponse(liveKitJoinPayload(provider: 'fake')),
      );
      final mediaClient = MediaClient(
        backendUrl: 'https://example.test',
        registry: MediaRegistry([factory]),
        transport: transport,
        heartbeatInterval: Duration.zero,
      );
      final client = RealtimeClient(
        backendUrl: 'https://example.test',
        mediaAdapters: RealtimeMediaAdapters([
          RealtimeMediaAdapter(sessionFactory: factory, renderer: renderer),
        ]),
        mediaClientFactory: () => mediaClient,
      );

      final room = await client.createRoomAndJoinIdentity(
        identity: const MediaIdentity(userId: 'p1', displayName: 'P1'),
      );

      expect(room.providerId, 'fake');
      expect(room.renderer, same(renderer));
      expect(room.chat, isA<RtcDataChatSession>());
      expect(room.state.isConnected, isTrue);
      expect(room.capabilities.canChat, isTrue);
      expect(factory.createdSessions.single.joinCount, 1);

      final eventFuture = room.events.firstWhere(
        (event) => event is RealtimeMediaEvent,
      );
      factory.createdSessions.single.emitRemoteParticipant(
        id: 'remote',
        name: 'Remote',
      );
      expect(await eventFuture, isA<RealtimeMediaEvent>());
      expect(room.participants.map((value) => value.id), contains('remote'));

      await room.dispose();
      await room.dispose();
      expect(factory.createdSessions.single.disposeCount, 1);
    });

    test(
      'rejects backend-required capabilities the resolved room lacks',
      () async {
        final factory = FakeMediaSessionFactory();
        final payload = liveKitJoinPayload(provider: 'fake')
          ..['requiredCapabilities'] = ['remove-participants'];
        final mediaClient = MediaClient(
          backendUrl: 'https://example.test',
          registry: MediaRegistry([factory]),
          transport: FakeTransport((_) => jsonResponse(payload)),
          heartbeatInterval: Duration.zero,
        );
        final client = RealtimeClient(
          backendUrl: 'https://example.test',
          mediaAdapters: RealtimeMediaAdapters([
            RealtimeMediaAdapter(
              sessionFactory: factory,
              renderer: const _FakeRenderer(),
            ),
          ]),
          mediaClientFactory: () => mediaClient,
        );

        await expectLater(
          client.createRoomAndJoinIdentity(
            identity: const MediaIdentity(userId: 'p1', displayName: 'P1'),
          ),
          throwsA(
            isA<MediaError>().having(
              (error) => error.code,
              'code',
              MediaErrorCode.unsupportedFeature,
            ),
          ),
        );
        expect(factory.createdSessions.single.disposeCount, 1);
      },
    );

    test(
      'cleans up joined media when renderer registration is missing',
      () async {
        final joinedFactory = FakeMediaSessionFactory();
        final registeredFactory = FakeMediaSessionFactory(providerId: 'other');
        final transport = FakeTransport(
          (_) => jsonResponse(liveKitJoinPayload(provider: 'fake')),
        );
        final mediaClient = MediaClient(
          backendUrl: 'https://example.test',
          registry: MediaRegistry([joinedFactory]),
          transport: transport,
          heartbeatInterval: Duration.zero,
        );
        final client = RealtimeClient(
          backendUrl: 'https://example.test',
          mediaAdapters: RealtimeMediaAdapters([
            RealtimeMediaAdapter(
              sessionFactory: registeredFactory,
              renderer: const _FakeRenderer(),
            ),
          ]),
          mediaClientFactory: () => mediaClient,
        );

        await expectLater(
          client.createRoomAndJoinIdentity(
            identity: const MediaIdentity(userId: 'p1', displayName: 'P1'),
          ),
          throwsStateError,
        );

        expect(joinedFactory.createdSessions.single.disposeCount, 1);
      },
    );

    test('cleans up media when provider join fails', () async {
      final error = MediaError(
        code: MediaErrorCode.nativeError,
        message: 'join failed',
        providerId: 'fake',
      );
      final factory = FakeMediaSessionFactory(joinError: error);
      final transport = FakeTransport(
        (_) => jsonResponse(liveKitJoinPayload(provider: 'fake')),
      );
      final mediaClient = MediaClient(
        backendUrl: 'https://example.test',
        registry: MediaRegistry([factory]),
        transport: transport,
        heartbeatInterval: Duration.zero,
      );
      final client = RealtimeClient(
        backendUrl: 'https://example.test',
        mediaAdapters: RealtimeMediaAdapters([
          RealtimeMediaAdapter(
            sessionFactory: factory,
            renderer: const _FakeRenderer(),
          ),
        ]),
        mediaClientFactory: () => mediaClient,
      );

      await expectLater(
        client.createRoomAndJoinIdentity(
          identity: const MediaIdentity(userId: 'p1', displayName: 'P1'),
        ),
        throwsA(same(error)),
      );
      expect(factory.createdSessions.single.disposeCount, 1);
    });

    test('does not downgrade configured Product Chat failure to RTC', () async {
      final factory = FakeMediaSessionFactory();
      final payload = liveKitJoinPayload(provider: 'fake')
        ..['chatProvider'] = 'ivs';
      final mediaClient = MediaClient(
        backendUrl: 'https://example.test',
        registry: MediaRegistry([factory]),
        transport: FakeTransport((_) => jsonResponse(payload)),
        heartbeatInterval: Duration.zero,
      );
      final client = RealtimeClient(
        backendUrl: 'https://example.test',
        mediaAdapters: RealtimeMediaAdapters([
          RealtimeMediaAdapter(
            sessionFactory: factory,
            renderer: const _FakeRenderer(),
          ),
        ]),
        mediaClientFactory: () => mediaClient,
        chatClientFactory: () => ChatClient.withConfig(
          ChatBackendConfig.fromUrl('https://example.test'),
          backend: _FailingChatBackend(),
        ),
      );

      await expectLater(
        client.createRoomAndJoinIdentity(
          identity: const MediaIdentity(userId: 'p1', displayName: 'P1'),
        ),
        throwsA(
          isA<ChatError>().having(
            (error) => error.code,
            'code',
            ChatErrorCode.network,
          ),
        ),
      );
      expect(factory.createdSessions.single.disposeCount, 1);
    });
  });

  group('RealtimeSdk facade', () {
    test('runs provider-neutral Pre-Join through the facade', () async {
      final factory = FakeMediaSessionFactory();
      final transport = FakeTransport(
        (_) => jsonResponse({'contractVersion': 1, 'ok': true}),
      );
      final mediaClient = MediaClient(
        backendUrl: 'https://example.test',
        registry: MediaRegistry([factory]),
        transport: transport,
        heartbeatInterval: Duration.zero,
      );
      final advanced = RealtimeClient(
        backendUrl: 'https://example.test',
        mediaAdapters: RealtimeMediaAdapters([
          RealtimeMediaAdapter(
            sessionFactory: factory,
            renderer: const _FakeRenderer(),
          ),
        ]),
        mediaClientFactory: () => mediaClient,
      );
      final sdk = RealtimeSdk(
        backendUrl: 'https://example.test',
        plugins: [
          RealtimeProviderPlugin(
            id: 'fake',
            metadata: const RealtimeProviderMetadata(displayName: 'Fake'),
            mediaFactory: factory,
            renderer: const _FakeRenderer(),
          ),
        ],
        clientFactory: () => advanced,
      );

      final result = await sdk.preJoin(providerId: 'fake');

      expect(result.checks, isNotEmpty);
    });

    test('maps low-level join errors to RealtimeException', () async {
      final source = MediaError(
        code: MediaErrorCode.nativeError,
        message: 'provider failed',
        providerId: 'fake',
      );
      final factory = FakeMediaSessionFactory(joinError: source);
      final transport = FakeTransport(
        (_) => jsonResponse(liveKitJoinPayload(provider: 'fake')),
      );
      final mediaClient = MediaClient(
        backendUrl: 'https://example.test',
        registry: MediaRegistry([factory]),
        transport: transport,
        heartbeatInterval: Duration.zero,
      );
      final advanced = RealtimeClient(
        backendUrl: 'https://example.test',
        mediaAdapters: RealtimeMediaAdapters([
          RealtimeMediaAdapter(
            sessionFactory: factory,
            renderer: const _FakeRenderer(),
          ),
        ]),
        mediaClientFactory: () => mediaClient,
      );
      final sdk = RealtimeSdk(
        backendUrl: 'https://example.test',
        plugins: [
          RealtimeProviderPlugin(
            id: 'fake',
            metadata: const RealtimeProviderMetadata(displayName: 'Fake'),
            mediaFactory: factory,
            renderer: const _FakeRenderer(),
          ),
        ],
        clientFactory: () => advanced,
      );

      await expectLater(
        sdk.createRoom(
          user: const MediaIdentity(userId: 'p1', displayName: 'P1'),
        ),
        throwsA(
          isA<RealtimeException>()
              .having(
                (error) => error.code,
                'code',
                RealtimeErrorCode.providerError,
              )
              .having((error) => error.providerId, 'providerId', 'fake')
              .having((error) => error.cause, 'cause', same(source)),
        ),
      );
    });

    test('maps incompatible backend contract to invalidResponse', () async {
      final factory = FakeMediaSessionFactory();
      final payload = liveKitJoinPayload(provider: 'fake')
        ..['contractVersion'] = 2;
      final mediaClient = MediaClient(
        backendUrl: 'https://example.test',
        registry: MediaRegistry([factory]),
        transport: FakeTransport((_) => jsonResponse(payload)),
        heartbeatInterval: Duration.zero,
      );
      final advanced = RealtimeClient(
        backendUrl: 'https://example.test',
        mediaAdapters: RealtimeMediaAdapters([
          RealtimeMediaAdapter(
            sessionFactory: factory,
            renderer: const _FakeRenderer(),
          ),
        ]),
        mediaClientFactory: () => mediaClient,
      );
      final sdk = RealtimeSdk(
        backendUrl: 'https://example.test',
        plugins: [
          RealtimeProviderPlugin(
            id: 'fake',
            metadata: const RealtimeProviderMetadata(displayName: 'Fake'),
            mediaFactory: factory,
            renderer: const _FakeRenderer(),
          ),
        ],
        clientFactory: () => advanced,
      );

      await expectLater(
        sdk.createRoom(
          user: const MediaIdentity(userId: 'p1', displayName: 'P1'),
        ),
        throwsA(
          isA<RealtimeException>().having(
            (error) => error.code,
            'code',
            RealtimeErrorCode.invalidResponse,
          ),
        ),
      );
    });
  });

  test(
    'RealtimeRoomView owns the resolved room as its single room input',
    () async {
      final factory = FakeMediaSessionFactory();
      final mediaClient = MediaClient(
        backendUrl: 'https://example.test',
        registry: MediaRegistry([factory]),
        transport: FakeTransport(
          (_) => jsonResponse(liveKitJoinPayload(provider: 'fake')),
        ),
        heartbeatInterval: Duration.zero,
      );
      final client = RealtimeClient(
        backendUrl: 'https://example.test',
        mediaAdapters: RealtimeMediaAdapters([
          RealtimeMediaAdapter(
            sessionFactory: factory,
            renderer: const _FakeRenderer(),
          ),
        ]),
        mediaClientFactory: () => mediaClient,
      );
      final room = await client.createRoomAndJoinIdentity(
        identity: const MediaIdentity(userId: 'p1', displayName: 'P1'),
      );

      final view = RealtimeRoomView(room: room);
      expect(view.room, same(room));
      await room.dispose();
    },
  );
}

class _FailingChatBackend extends ChatBackendClient {
  _FailingChatBackend()
    : super(ChatBackendConfig.fromUrl('https://example.test'));

  @override
  Future<ChatBackendJoinResponse> issueToken({
    required String roomCode,
    required String participantId,
    String? participantCredential,
  }) => throw const ChatError(
    code: ChatErrorCode.network,
    message: 'chat backend unavailable',
    providerId: 'ivs',
  );
}

class _FakeRenderer extends MediaTrackRenderer {
  const _FakeRenderer();

  @override
  Widget buildView(BuildContext context, MediaVideoTrack track) =>
      const SizedBox.shrink();
}
