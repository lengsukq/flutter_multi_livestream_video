import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_media_session.dart';

void main() {
  group('MediaRegistry', () {
    test('resolves registered providers case-insensitively', () {
      final registry = MediaRegistry([FakeMediaSessionFactory()]);
      expect(registry.providerIds, ['fake']);
      expect(registry.lookup('FAKE'), isNotNull);
      expect(registry.require(' fake ').providerId, 'fake');
    });

    test('missing provider throws providerNotRegistered', () {
      final registry = MediaRegistry();
      expect(
        () => registry.require('livekit'),
        throwsA(
          isA<MediaError>().having(
            (error) => error.code,
            'code',
            MediaErrorCode.providerNotRegistered,
          ),
        ),
      );
    });

    test('rejects an empty provider id', () {
      final registry = MediaRegistry();
      expect(
        () => registry.register(FakeMediaSessionFactory(providerId: '  ')),
        throwsArgumentError,
      );
    });

    test('re-registering the same id replaces the adapter', () {
      final registry = MediaRegistry();
      final first = FakeMediaSessionFactory();
      final second = FakeMediaSessionFactory();
      registry.register(first);
      registry.register(second);
      expect(registry.require('fake'), same(second));
      expect(registry.providerIds.length, 1);
    });

    test('unregister removes the adapter', () {
      final registry = MediaRegistry([FakeMediaSessionFactory()]);
      expect(registry.unregister('fake'), isTrue);
      expect(registry.unregister('fake'), isFalse);
      expect(registry.lookup('fake'), isNull);
    });

    test('global registry is shared and independent of instances', () {
      final instance = MediaRegistry();
      expect(instance.lookup('fake'), isNull);
      expect(MediaRegistry.global, same(MediaRegistry.global));
    });
  });

  group('MediaSessionFactory parsing', () {
    test('reports missing fields as invalidJoinInfo', () {
      final factory = FakeMediaSessionFactory();
      expect(
        () => factory.parseJoinInfo({'roomCode': '482913'}),
        throwsA(
          isA<MediaError>()
              .having(
                (error) => error.code,
                'code',
                MediaErrorCode.invalidJoinInfo,
              )
              .having((error) => error.providerId, 'providerId', 'fake'),
        ),
      );
    });

    test('reads role, participant, and provider payload', () {
      final factory = FakeMediaSessionFactory();
      final info = factory.parseJoinInfo({
        'roomCode': '482913',
        'participantId': 'viewer-1',
        'role': 'viewer',
        'payload': {'url': 'ws://127.0.0.1:7880', 'token': 'jwt'},
      });

      expect(info.roomCode, '482913');
      expect(info.participantId, 'viewer-1');
      expect(info.role, MediaRole.viewer);
      expect(info.requirePayloadString('url'), 'ws://127.0.0.1:7880');
      expect(info.optionalPayloadString('missing'), isNull);
    });
  });
}
