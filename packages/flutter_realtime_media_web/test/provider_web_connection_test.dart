@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_media_web/flutter_realtime_media_web.dart';
import 'package:flutter_realtime_media_web/src/provider_web_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

@JS('globalThis')
external JSObject get _global;

@JS('Error')
extension type _BrowserError._(JSObject _) implements JSObject {
  external _BrowserError(JSString message);
}
@JS('Promise.reject')
external JSPromise<JSAny?> _reject(JSAny error);

void main() {
  tearDown(() => _global.delete('MediaProviderBridge'.toJS));

  for (final version in <int?>[null, 99]) {
    test('incompatible bridge $version fails before joining', () async {
      final bridge = JSObject();
      if (version != null) {
        bridge.setProperty('bridgeVersion'.toJS, version.toJS);
      }
      var joined = false;
      bridge.setProperty(
        'join'.toJS,
        ((JSString provider, JSString session) {
          joined = true;
          return Future<JSAny?>.value(null).toJS;
        }).toJS,
      );
      _global.setProperty('MediaProviderBridge'.toJS, bridge);
      await expectLater(
        ProviderWebBridge.join('agora', 'one'),
        throwsA(
          isA<RealtimeException>()
              .having((e) => e.message, 'message', 'webBridge.versionMismatch')
              .having((e) => e.suggestedAction, 'action', 'reload-web-runtime'),
        ),
      );
      expect(joined, isFalse);
    });
  }

  test('a non-resolving vendor join becomes a recoverable timeout', () async {
    final bridge = JSObject()..setProperty('bridgeVersion'.toJS, 1.toJS);
    final gate = Completer<JSAny?>();
    bridge.setProperty(
      'join'.toJS,
      ((JSString provider, JSString session) => gate.future.toJS).toJS,
    );
    _global.setProperty('MediaProviderBridge'.toJS, bridge);
    await expectLater(
      ProviderWebBridge.join(
        'agora',
        'one',
        timeout: const Duration(milliseconds: 20),
      ),
      throwsA(
        isA<RealtimeException>()
            .having((e) => e.code, 'code', RealtimeErrorCode.timeout)
            .having((e) => e.operation, 'operation', 'join')
            .having((e) => e.recoverable, 'recoverable', isTrue)
            .having((e) => e.cause, 'cause', isA<TimeoutException>()),
      ),
    );
    gate.complete(null);
  });

  test(
    'network join failures reach the caller and snapshot, release the session and permit retry',
    () async {
      final bridge = JSObject()..setProperty('bridgeVersion'.toJS, 1.toJS);
      var fail = true, eventOnly = false, releases = 0;
      bridge.setProperty(
        'create'.toJS,
        ((JSString provider, JSString session, JSString payload) =>
                Future<JSAny?>.value(null).toJS)
            .toJS,
      );
      bridge.setProperty(
        'join'.toJS,
        ((JSString provider, JSString session) {
          if (eventOnly) {
            _global.callMethod<JSAny?>(
              '__flutterMediaProviderOnEvent'.toJS,
              session,
              jsonEncode({
                'type': 'error',
                'message': 'NETWORK_ERROR event-private-payload',
              }).toJS,
            );
            return Future<JSAny?>.value(null).toJS;
          }
          return fail
              ? _reject(
                  _BrowserError(
                    'AgoraRTCError NETWORK_ERROR private-payload'.toJS,
                  ),
                )
              : Future<JSAny?>.value(null).toJS;
        }).toJS,
      );
      bridge.setProperty(
        'dispose'.toJS,
        ((JSString provider, JSString session) {
          releases++;
          return Future<JSAny?>.value(null).toJS;
        }).toJS,
      );
      bridge.setProperty(
        'leave'.toJS,
        ((JSString provider, JSString session) => Future<JSAny?>.value(
          null,
        ).toJS).toJS,
      );
      _global.setProperty('MediaProviderBridge'.toJS, bridge);
      final factory = ProviderWebSessionFactory('agora');
      final info = factory.parseJoinInfo({
        'provider': 'agora',
        'roomCode': 'one',
        'participantId': '42',
        'role': 'participant',
        'agora': {
          'appId': 'test',
          'channelName': 'one',
          'token': 'test',
          'uid': 42,
        },
      });
      final session = factory.createSession(info);
      addTearDown(session.dispose);
      await expectLater(
        session.join(info),
        throwsA(
          isA<RealtimeException>()
              .having((e) => e.code, 'code', RealtimeErrorCode.network)
              .having(
                (e) => e.message,
                'message',
                isNot(contains('private-payload')),
              )
              .having((e) => e.cause, 'cause', isNotNull),
        ),
      );
      expect(session.state, MediaSessionState.failed);
      expect(session.snapshot.lastError?.suggestedAction, 'retry');
      expect(releases, 1);
      fail = false;
      eventOnly = true;
      await expectLater(
        session.join(info),
        throwsA(
          isA<RealtimeException>().having(
            (e) => e.code,
            'code',
            RealtimeErrorCode.network,
          ),
        ),
      );
      expect(session.snapshot.lastError?.operation, 'event');
      expect(releases, 2);
      eventOnly = false;
      await session.join(info);
      expect(session.state, MediaSessionState.connected);
      expect(session.snapshot.lastError, isNull);
    },
  );
}
