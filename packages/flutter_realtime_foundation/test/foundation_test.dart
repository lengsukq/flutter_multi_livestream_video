import 'dart:async';
import 'package:flutter_realtime_foundation/flutter_realtime_foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test(
    'rollback preserves the primary error and reports cleanup failures',
    () async {
      final cleanup = Cleanup();
      await cleanup.run('room', () => throw StateError('release failed'));
      const primary = RealtimeException(
        code: RealtimeErrorCode.invalidCredential,
        message: 'Join credentials were rejected.',
        providerId: 'livekit',
      );
      expect(
        () => cleanup.finish(domain: 'media', cause: primary),
        throwsA(
          isA<RealtimeException>()
              .having(
                (e) => e.code,
                'original code',
                RealtimeErrorCode.invalidCredential,
              )
              .having((e) => e.providerId, 'provider', 'livekit')
              .having(
                (e) =>
                    ((e.details as Map)['cleanupFailures']
                            as List<CleanupFailure>)
                        .single
                        .stage,
                'failed cleanup stage',
                'room',
              ),
        ),
      );
    },
  );

  test(
    'cleanup attempts every resource and preserves all stage failures',
    () async {
      final cleanup = Cleanup(timeout: const Duration(milliseconds: 20));
      final stages = <String>[];
      await cleanup.run('capture', () {
        stages.add('capture');
        throw StateError('failed');
      });
      await cleanup.run('pending', () => Completer<void>().future);
      await cleanup.run('media', () => stages.add('media'));
      expect(stages, ['capture', 'media']);
      expect(
        () => cleanup.finish(),
        throwsA(
          isA<RealtimeException>()
              .having((e) => e.code, 'code', RealtimeErrorCode.cleanupFailed)
              .having(
                (e) => (e.details as List<CleanupFailure>).map((f) => f.stage),
                'stages',
                ['capture', 'pending'],
              ),
        ),
      );
    },
  );

  for (final entry in {
    401: RealtimeErrorCode.unauthorized,
    503: RealtimeErrorCode.serverError,
  }.entries) {
    test(
      'HTML ${entry.key} retains HTTP classification without exposing body',
      () async {
        final executor = RealtimeHttpExecutor(
          client: MockClient(
            (_) async => http.Response('<secret-token>', entry.key),
          ),
        );
        await expectLater(
          executor.request(
            method: 'GET',
            uri: Uri.parse('https://example.invalid/test'),
            timeout: const Duration(seconds: 1),
            domain: 'chat',
          ),
          throwsA(
            isA<RealtimeException>()
                .having((e) => e.code, 'code', entry.value)
                .having((e) => e.statusCode, 'status', entry.key)
                .having(
                  (e) => e.toString(),
                  'safe message',
                  isNot(contains('secret-token')),
                ),
          ),
        );
        executor.close();
      },
    );
  }

  test(
    'late credential completion after timeout cannot send a write',
    () async {
      final ready = Completer<Map<String, String>>();
      var sends = 0;
      final executor = RealtimeHttpExecutor(
        client: MockClient((_) async {
          sends++;
          return http.Response('{}', 200);
        }),
      );
      await expectLater(
        executor.request(
          method: 'POST',
          uri: Uri.parse('https://example.invalid/rooms'),
          timeout: const Duration(milliseconds: 10),
          domain: 'media',
          headers: () => ready.future,
        ),
        throwsA(
          isA<RealtimeException>().having(
            (e) => e.code,
            'code',
            RealtimeErrorCode.timeout,
          ),
        ),
      );
      ready.complete({});
      await Future<void>.delayed(Duration.zero);
      expect(sends, 0);
      executor.close();
    },
  );

  test('body deadline signals abort without closing injected client', () async {
    final client = _StreamingClient();
    final executor = RealtimeHttpExecutor(client: client);
    await expectLater(
      executor.request(
        method: 'GET',
        uri: Uri.parse('https://example.invalid/slow'),
        timeout: const Duration(milliseconds: 10),
        domain: 'chat',
      ),
      throwsA(
        isA<RealtimeException>().having(
          (e) => e.code,
          'code',
          RealtimeErrorCode.timeout,
        ),
      ),
    );
    await client.aborted.future;
    executor.close();
    expect(client.closed, false);
    await client.stream.close();
  });

  test('malformed successful JSON is invalidResponse', () async {
    final executor = RealtimeHttpExecutor(
      client: MockClient((_) async => http.Response('[broken', 200)),
    );
    await expectLater(
      executor.request(
        method: 'GET',
        uri: Uri.parse('https://example.invalid/json'),
        timeout: const Duration(seconds: 1),
        domain: 'classroom',
      ),
      throwsA(
        isA<RealtimeException>().having(
          (e) => e.code,
          'code',
          RealtimeErrorCode.invalidResponse,
        ),
      ),
    );
    executor.close();
  });

  test('protocol validation identifies the invalid field', () {
    expect(
      () => JsonReader({'id': 1}).required<String>('id'),
      throwsA(
        isA<RealtimeException>().having((e) => e.details, 'field', {
          'field': r'$.id',
        }),
      ),
    );
  });
}

class _StreamingClient extends http.BaseClient {
  final stream = StreamController<List<int>>();
  final aborted = Completer<void>();
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    observeDetached(
      (request as http.Abortable).abortTrigger!.then((_) => aborted.complete()),
    );
    return http.StreamedResponse(stream.stream, 200);
  }

  @override
  void close() {
    closed = true;
  }
}
