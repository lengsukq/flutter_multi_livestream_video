import 'dart:async';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_chat_ivs/flutter_realtime_chat_ivs.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeIvsChatEngine implements IvsChatEngine {
  Future<void>? pendingConnect;
  IvsChatEngineEvents events = const IvsChatEngineEvents();
  IvsChatTokenProvider? tokenProvider;
  final List<String> calls = [];

  @override
  Future<void> connect(
    IvsChatJoinInfo info,
    IvsChatEngineEvents events, {
    IvsChatTokenProvider? tokenProvider,
  }) async {
    this.events = events;
    this.tokenProvider = tokenProvider;
    calls.add('connect:${info.token}');
    if (pendingConnect != null) await pendingConnect;
    events.onConnected?.call();
  }

  @override
  Future<void> sendMessage(String message) async {
    calls.add('send:$message');
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    calls.add('delete:$messageId');
  }

  @override
  Future<void> disconnectUser(String userId) async {
    calls.add('disconnectUser:$userId');
  }

  @override
  Future<void> disconnect() async {
    calls.add('disconnect');
  }

  @override
  Future<void> dispose() async {
    calls.add('dispose');
  }
}

Map<String, dynamic> _joinJson({
  ChatRole role = ChatRole.viewer,
  String token = 'chat-token-1',
}) => {
  'contractVersion': 1,
  'chatProvider': 'ivs-chat',
  'roomCode': '123456',
  'participantId': 'media-participant-1',
  'userId': 'user-1',
  'displayName': 'User One',
  'role': role.wireName,
  'chat': {
    'roomArn': 'arn:aws:ivschat:us-west-2:123456789012:room/abc123',
    'token': token,
    'capabilities': role == ChatRole.host
        ? ['SEND_MESSAGE', 'DELETE_MESSAGE', 'DISCONNECT_USER']
        : ['SEND_MESSAGE'],
    'tokenExpirationTimeMs': DateTime.now()
        .add(const Duration(minutes: 1))
        .millisecondsSinceEpoch,
    'sessionExpirationTimeMs': DateTime.now()
        .add(const Duration(hours: 1))
        .millisecondsSinceEpoch,
    'region': 'us-west-2',
  },
};

const hint =
    '{"v":1,"type":"classroom.state.changed","roomCode":"123456","revision":3,"eventId":"hint-3","timestampMs":1000}';

void main() {
  test('IVS Chat late connect is cancelled by disconnect', () async {
    final pending = Completer<void>();
    final engine = _FakeIvsChatEngine()..pendingConnect = pending.future;
    final factory = IvsChatSessionFactory(engineFactory: () async => engine);
    final info = factory.parseJoinInfo(_joinJson());
    final session = factory.createSession(info);
    final connecting = session.connect(info);
    final cancelled = expectLater(
      connecting,
      throwsA(
        isA<RealtimeException>().having(
          (error) => error.code,
          'code',
          RealtimeErrorCode.cancelled,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await session.disconnect();
    pending.complete();
    await cancelled;
    expect(session.state, ChatConnectionState.disconnected);
    engine.events.onConnected?.call();
    expect(session.state, ChatConnectionState.disconnected);
    await session.dispose();
  });

  test('IVS system hints do not enter the ChatSession timeline', () async {
    final engine = _FakeIvsChatEngine();
    final factory = IvsChatSessionFactory(engineFactory: () async => engine);
    final info = factory.parseJoinInfo(_joinJson());
    final session = factory.createSession(info);
    await session.connect(info);
    final signals = <String>[];
    final system = session as ChatSystemMessaging;
    final sub = system.systemMessages.listen(signals.add);
    await system.sendSystemMessage(hint);
    final frame = ChatSystemMessageCodec.encode(hint);
    expect(engine.calls, contains('send:$frame'));
    engine.events.onMessage?.call({
      'id': 'system-1',
      'userId': 'other',
      'message': frame,
      'timestampMs': 1000,
    });
    await Future<void>.delayed(Duration.zero);
    expect(signals, [hint]);
    expect(session.messages, isEmpty);
    final literalTexts = [
      '${ChatSystemMessageCodec.prefix}$hint',
      '${ChatSystemMessageCodec.textPrefix}literal text',
    ];
    for (var index = 0; index < literalTexts.length; index++) {
      final literal = literalTexts[index];
      await session.sendMessage(literal);
      final wire = ChatSystemMessageCodec.encodeUserText(literal);
      expect(engine.calls, contains('send:$wire'));
      engine.events.onMessage?.call({
        'id': 'literal-$index',
        'userId': 'other',
        'message': wire,
        'timestampMs': 1001 + index,
      });
    }
    engine.events.onMessage?.call({
      'id': 'malformed',
      'userId': 'other',
      'message': '${ChatSystemMessageCodec.prefix}not-json',
      'timestampMs': 1003,
    });
    await Future<void>.delayed(Duration.zero);
    expect(signals, [hint]);
    expect(session.messages.map((m) => m.message), [
      ...literalTexts,
      '${ChatSystemMessageCodec.prefix}not-json',
    ]);

    await sub.cancel();
    await session.dispose();
  });

  test('viewer can chat but cannot use moderation capabilities', () async {
    final engine = _FakeIvsChatEngine();
    final factory = IvsChatSessionFactory(engineFactory: () async => engine);
    final joinInfo = factory.parseJoinInfo(_joinJson());
    final session = factory.createSession(joinInfo);

    await session.connect(joinInfo);
    expect(session.state, ChatConnectionState.connected);
    expect(session.capabilities.canSendMessage, isTrue);
    expect(session.capabilities.canDeleteMessage, isFalse);
    expect(session.capabilities.canDisconnectUser, isFalse);

    await session.sendMessage('hello');
    expect(engine.calls, contains('send:hello'));
    await expectLater(
      session.deleteMessage('message-1'),
      throwsA(
        isA<RealtimeException>().having(
          (error) => error.code,
          'code',
          RealtimeErrorCode.forbidden,
        ),
      ),
    );
    await session.dispose();
  });

  test('host moderation maps to the native engine', () async {
    final engine = _FakeIvsChatEngine();
    final factory = IvsChatSessionFactory(engineFactory: () async => engine);
    final joinInfo = factory.parseJoinInfo(_joinJson(role: ChatRole.host));
    final session = factory.createSession(joinInfo);

    await session.connect(joinInfo);
    await session.deleteMessage('message-1');
    await session.disconnectUser('viewer-user');

    expect(engine.calls, contains('delete:message-1'));
    expect(engine.calls, contains('disconnectUser:viewer-user'));
    await session.dispose();
  });

  test('messages are tracked and delete events remove them', () async {
    final engine = _FakeIvsChatEngine();
    final factory = IvsChatSessionFactory(engineFactory: () async => engine);
    final joinInfo = factory.parseJoinInfo(_joinJson());
    final session = factory.createSession(joinInfo);
    await session.connect(joinInfo);

    engine.events.onMessage?.call({
      'id': 'm2',
      'userId': 'user-2',
      'displayName': 'Second',
      'message': 'second',
      'timestampMs': 2000,
      'attributes': <String, String>{},
    });
    engine.events.onMessage?.call({
      'id': 'm1',
      'userId': 'user-1',
      'displayName': 'First',
      'message': 'first',
      'timestampMs': 1000,
      'attributes': <String, String>{},
    });

    expect(session.messages.map((message) => message.id), ['m1', 'm2']);
    engine.events.onMessageDeleted?.call('m1');
    expect(session.messages.map((message) => message.id), ['m2']);
    await session.dispose();
  });

  test(
    'native reconnect token requests fetch fresh backend credentials',
    () async {
      final engine = _FakeIvsChatEngine();
      final factory = IvsChatSessionFactory(engineFactory: () async => engine);
      final initial = factory.parseJoinInfo(_joinJson());
      final session = factory.createSession(initial);
      var refreshCount = 0;

      await session.connect(
        initial,
        credentialProvider: () async {
          refreshCount++;
          return IvsChatJoinInfo.fromJson(_joinJson(token: 'chat-token-2'));
        },
      );

      final refreshed = await engine.tokenProvider!.call();
      expect(refreshCount, 1);
      expect(refreshed.token, 'chat-token-2');
      expect(refreshed.participantId, initial.participantId);
      expect(refreshed.role, initial.role);
      await session.dispose();
    },
  );

  test('non-host moderation capabilities are rejected in join credentials', () {
    final json = _joinJson();
    (json['chat'] as Map<String, dynamic>)['capabilities'] = [
      'SEND_MESSAGE',
      'DELETE_MESSAGE',
    ];
    expect(
      () => IvsChatJoinInfo.fromJson(json),
      throwsA(
        isA<RealtimeException>().having(
          (error) => error.code,
          'code',
          RealtimeErrorCode.invalidArgument,
        ),
      ),
    );
  });
}
