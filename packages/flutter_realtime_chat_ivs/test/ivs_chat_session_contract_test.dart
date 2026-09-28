import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_chat_ivs/flutter_realtime_chat_ivs.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeIvsChatEngine implements IvsChatEngine {
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

void main() {
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
        isA<ChatError>().having(
          (error) => error.code,
          'code',
          ChatErrorCode.forbidden,
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
        isA<ChatError>().having(
          (error) => error.code,
          'code',
          ChatErrorCode.invalidJoinInfo,
        ),
      ),
    );
  });
}
