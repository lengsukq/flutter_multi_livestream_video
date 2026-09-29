import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_chat_core/src/web/web_chat_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WebChatRuntime', () {
    test(
      'forwards state, de-duplicates messages, and refreshes credentials',
      () async {
        final driver = _FakeWebChatDriver();
        final runtime = WebChatRuntime<String>(
          providerId: 'fake-chat',
          driverFactory: () => driver,
        );
        final states = <String>[];
        final messages = <Map<String, Object?>>[];
        var errorCode = 0;
        var errorMessage = '';
        var refreshed = false;

        await runtime.connect(
          'initial',
          WebChatDriverEvents(
            onConnecting: (reconnecting) =>
                states.add(reconnecting ? 'reconnecting' : 'connecting'),
            onConnected: () => states.add('connected'),
            onMessage: messages.add,
            onError: (code, message) {
              errorCode = code;
              errorMessage = message;
            },
          ),
          tokenProvider: () async {
            refreshed = true;
            return 'refreshed';
          },
        );

        expect(states, ['connecting', 'connected']);
        expect(driver.connectedCredential, 'initial');
        await driver.refreshToken();
        expect(refreshed, isTrue);
        expect(driver.refreshedCredential, 'refreshed');

        driver.emitMessage({'id': 'message-1', 'message': 'hello'});
        driver.emitMessage({'id': 'message-1', 'message': 'hello'});
        driver.emitMessage({'id': 'message-2', 'message': 'world'});
        expect(messages.map((message) => message['id']), [
          'message-1',
          'message-2',
        ]);
        driver.emitError(401, 'token expired');
        expect(errorCode, 401);
        expect(errorMessage, contains('token expired'));
        expect(
          mapWebChatError(
            'fake-chat',
            'Web chat failure.',
            StateError('token expired'),
          ).code,
          ChatErrorCode.unauthorized,
        );
        await runtime.disconnect();
        expect(driver.disconnectCalls, 1);
        expect(driver.disposeCalls, 1);
      },
    );

    test(
      'cleans a failed connection and allows a fresh driver to retry',
      () async {
        final first = _FakeWebChatDriver(failConnect: true);
        final second = _FakeWebChatDriver();
        var factoryCalls = 0;
        final runtime = WebChatRuntime<String>(
          providerId: 'fake-chat',
          driverFactory: () => factoryCalls++ == 0 ? first : second,
        );

        await expectLater(
          runtime.connect('bad', const WebChatDriverEvents()),
          throwsA(
            isA<ChatError>().having(
              (error) => error.providerId,
              'providerId',
              'fake-chat',
            ),
          ),
        );
        expect(first.disconnectCalls, 1);
        expect(first.disposeCalls, 1);

        await runtime.connect('good', const WebChatDriverEvents());
        expect(second.connectedCredential, 'good');
        await runtime.dispose();
        expect(second.disposeCalls, 1);
      },
    );

    test('rejects commands outside a connected session', () async {
      final runtime = WebChatRuntime<String>(
        providerId: 'fake-chat',
        driverFactory: _FakeWebChatDriver.new,
      );
      await expectLater(
        runtime.sendMessage('hello'),
        throwsA(isA<ChatError>()),
      );
      await runtime.dispose();
    });

    test('cleans up a disconnected driver before reconnecting', () async {
      final first = _FakeWebChatDriver();
      final second = _FakeWebChatDriver();
      var factoryCalls = 0;
      final runtime = WebChatRuntime<String>(
        providerId: 'fake-chat',
        driverFactory: () => factoryCalls++ == 0 ? first : second,
      );
      await runtime.connect('first', const WebChatDriverEvents());
      first.emitDisconnected('networkLost');

      await runtime.connect('second', const WebChatDriverEvents());
      expect(first.disconnectCalls, 1);
      expect(first.disposeCalls, 1);
      expect(second.connectedCredential, 'second');
      await runtime.dispose();
    });
  });
}

class _FakeWebChatDriver implements WebChatDriver<String> {
  _FakeWebChatDriver({this.failConnect = false});

  final bool failConnect;
  late WebChatDriverEvents _events;
  WebChatTokenProvider<String>? _tokenProvider;
  String? connectedCredential;
  String? refreshedCredential;
  int disconnectCalls = 0;
  int disposeCalls = 0;

  @override
  Future<void> connect(
    String credentials,
    WebChatDriverEvents events, {
    WebChatTokenProvider<String>? tokenProvider,
  }) async {
    _events = events;
    _tokenProvider = tokenProvider;
    _events.onConnecting?.call(false);
    if (failConnect) throw StateError('temporary connection failure');
    connectedCredential = credentials;
    _events.onConnected?.call();
  }

  Future<void> refreshToken() async {
    refreshedCredential = await _tokenProvider?.call();
  }

  void emitMessage(Map<String, Object?> message) =>
      _events.onMessage?.call(message);

  void emitError(int code, String message) =>
      _events.onError?.call(code, message);

  void emitDisconnected(String reason) => _events.onDisconnected?.call(reason);

  @override
  Future<void> sendMessage(String message) async {}

  @override
  Future<void> deleteMessage(String messageId) async {}

  @override
  Future<void> disconnectUser(String userId) async {}

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
    _events.onDisconnected?.call('clientDisconnect');
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    _tokenProvider = null;
  }
}
