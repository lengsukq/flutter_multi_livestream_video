import 'package:flutter/services.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_chat_ivs/flutter_realtime_chat_ivs.dart';
import 'package:flutter_realtime_chat_ivs/src/ivs_chat_engine_native.dart';
import 'package:flutter_test/flutter_test.dart';

const _methodsName = 'com.oneplusdream.flutter_realtime_chat_ivs/methods';
const _eventsName = 'com.oneplusdream.flutter_realtime_chat_ivs/events';

IvsChatJoinInfo _joinInfo({String token = 'initial-token'}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return IvsChatJoinInfo.fromJson({
    'contractVersion': 1,
    'chatProvider': 'ivs-chat',
    'roomCode': 'room-1',
    'participantId': 'participant-1',
    'userId': 'user-1',
    'displayName': 'User One',
    'role': 'viewer',
    'chat': {
      'roomArn': 'arn:aws:ivschat:us-west-2:123456789012:room/room-1',
      'token': token,
      'capabilities': ['SEND_MESSAGE'],
      'tokenExpirationTimeMs': now + 60000,
      'sessionExpirationTimeMs': now + 3600000,
      'region': 'us-west-2',
    },
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'forwards IVS Chat operations and native events over platform channels',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <MethodCall>[];
      late MockStreamHandlerEventSink eventSink;
      messenger.setMockMethodCallHandler(const MethodChannel(_methodsName), (
        call,
      ) async {
        calls.add(call);
        return null;
      });
      messenger.setMockStreamHandler(
        const EventChannel(_eventsName),
        MockStreamHandler.inline(onListen: (_, sink) => eventSink = sink),
      );

      final eventTypes = <String>[];
      final engine = await createNativeIvsChatEngine();
      await engine.connect(
        _joinInfo(),
        IvsChatEngineEvents(
          onConnecting: (_) => eventTypes.add('connecting'),
          onConnected: () => eventTypes.add('connected'),
          onDisconnected: (_) => eventTypes.add('disconnected'),
          onMessage: (_) => eventTypes.add('message'),
          onMessageDeleted: (_) => eventTypes.add('messageDeleted'),
          onUserDisconnected: (_) => eventTypes.add('userDisconnected'),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      eventSink
        ..success({'type': 'connecting', 'reconnecting': false})
        ..success({'type': 'connected'})
        ..success({
          'type': 'message',
          'id': 'message-1',
          'userId': 'user-2',
          'message': 'hello',
        })
        ..success({'type': 'messageDeleted', 'messageId': 'message-1'})
        ..success({'type': 'userDisconnected', 'userId': 'user-2'})
        ..success({'type': 'disconnected', 'reason': 'clientDisconnect'});
      await Future<void>.delayed(Duration.zero);

      await engine.sendMessage('hello');
      await engine.deleteMessage('message-1');
      await engine.disconnectUser('user-2');
      await engine.disconnect();
      await engine.dispose();

      expect(calls.map((call) => call.method), [
        'connect',
        'sendMessage',
        'deleteMessage',
        'disconnectUser',
        'disconnect',
        'dispose',
      ]);
      expect(calls.first.arguments, containsPair('region', 'us-west-2'));
      expect(calls.first.arguments, containsPair('token', 'initial-token'));
      expect(eventTypes, [
        'connecting',
        'connected',
        'message',
        'messageDeleted',
        'userDisconnected',
        'disconnected',
      ]);
    },
  );

  test(
    'passes refreshed credentials requested by the macOS bridge to Dart',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel(_methodsName),
        (_) async => null,
      );
      messenger.setMockStreamHandler(
        const EventChannel(_eventsName),
        MockStreamHandler.inline(onListen: (_, __) {}),
      );

      final engine = await createNativeIvsChatEngine();
      await engine.connect(
        _joinInfo(),
        const IvsChatEngineEvents(),
        tokenProvider: () async => _joinInfo(token: 'refreshed-token'),
      );

      const codec = StandardMethodCodec();
      final response = await messenger.handlePlatformMessage(
        _methodsName,
        codec.encodeMethodCall(const MethodCall('requestToken')),
        null,
      );
      final credentials =
          codec.decodeEnvelope(response!) as Map<Object?, Object?>;
      expect(credentials['token'], 'refreshed-token');
      expect(credentials['region'], 'us-west-2');
      expect(credentials['tokenExpirationTimeMs'], isA<int>());
      expect(credentials['sessionExpirationTimeMs'], isA<int>());

      await engine.dispose();
    },
  );

  test('maps a duplicate native room error to invalid state', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel(_methodsName),
      (call) async => call.method == 'connect'
          ? throw PlatformException(
              code: 'invalid_state',
              message: 'An Amazon IVS Chat room is already active.',
            )
          : null,
    );
    messenger.setMockStreamHandler(
      const EventChannel(_eventsName),
      MockStreamHandler.inline(onListen: (_, __) {}),
    );

    final engine = await createNativeIvsChatEngine();
    await expectLater(
      engine.connect(_joinInfo(), const IvsChatEngineEvents()),
      throwsA(
        isA<ChatError>().having(
          (error) => error.code,
          'code',
          ChatErrorCode.invalidState,
        ),
      ),
    );
    await engine.dispose();
  });
}
