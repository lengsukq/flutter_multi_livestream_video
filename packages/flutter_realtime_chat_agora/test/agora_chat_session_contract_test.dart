import 'package:flutter_realtime_chat_agora/flutter_realtime_chat_agora.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeEngine implements AgoraChatEngine {
  AgoraChatEngineEvents events = const AgoraChatEngineEvents();
  AgoraChatTokenProvider? tokenProvider;
  final List<String> calls = [];

  @override
  Future<void> connect(
    AgoraChatJoinInfo info,
    AgoraChatEngineEvents events, {
    AgoraChatTokenProvider? tokenProvider,
  }) async {
    this.events = events;
    this.tokenProvider = tokenProvider;
    calls.add('connect:${info.token}');
    events.onConnected?.call();
  }

  @override
  Future<void> sendMessage(String message) async => calls.add('send:$message');
  @override
  Future<void> deleteMessage(String messageId) async => calls.add('delete');
  @override
  Future<void> disconnectUser(String userId) async => calls.add('kick');
  @override
  Future<void> disconnect() async => calls.add('disconnect');
  @override
  Future<void> dispose() async => calls.add('dispose');
}

Map<String, dynamic> _joinJson({String token = 'token-1'}) => {
  'contractVersion': 1,
  'chatProvider': 'agora-chat',
  'roomCode': '123456',
  'participantId': 'participant-1',
  'userId': 'logical-user-1',
  'displayName': 'Agora User',
  'role': 'host',
  'chat': {
    'appKey': 'org#app',
    'chatRoomId': 'room-123',
    'providerUserId': 'u_123',
    'token': token,
    'capabilities': ['SEND_MESSAGE'],
    'tokenExpirationTimeMs': DateTime.now()
        .add(const Duration(hours: 1))
        .millisecondsSinceEpoch,
  },
};

void main() {
  test('Agora adapter exposes send but not unsafe moderation', () async {
    final engine = _FakeEngine();
    final factory = AgoraChatSessionFactory(engineFactory: () async => engine);
    final joinInfo = factory.parseJoinInfo(_joinJson());
    final session = factory.createSession(joinInfo);
    await session.connect(joinInfo);

    expect(session.capabilities.canSendMessage, isTrue);
    expect(session.capabilities.canDeleteMessage, isFalse);
    expect(session.capabilities.canDisconnectUser, isFalse);
    await session.sendMessage('hello');
    expect(engine.calls, contains('send:hello'));
    await expectLater(
      session.disconnectUser('user-2'),
      throwsA(
        isA<ChatError>().having(
          (error) => error.code,
          'code',
          ChatErrorCode.unsupportedFeature,
        ),
      ),
    );
    await session.dispose();
  });

  test('Agora events map to provider-neutral messages', () async {
    final engine = _FakeEngine();
    final factory = AgoraChatSessionFactory(engineFactory: () async => engine);
    final joinInfo = factory.parseJoinInfo(_joinJson());
    final session = factory.createSession(joinInfo);
    await session.connect(joinInfo);
    engine.events.onMessage?.call({
      'id': 'm1',
      'userId': 'logical-user-2',
      'displayName': 'Other Agora User',
      'message': 'hello',
      'timestampMs': 1000,
      'attributes': {'providerUserId': 'u_other'},
    });
    expect(session.messages.single.userId, 'logical-user-2');
    expect(session.messages.single.providerId, 'agora-chat');
    engine.events.onMessageDeleted?.call('m1');
    expect(session.messages, isEmpty);
    await session.dispose();
  });

  test('Agora token refresh preserves provider identity', () async {
    final engine = _FakeEngine();
    final factory = AgoraChatSessionFactory(engineFactory: () async => engine);
    final initial = factory.parseJoinInfo(_joinJson());
    final session = factory.createSession(initial);
    await session.connect(
      initial,
      credentialProvider: () async =>
          AgoraChatJoinInfo.fromJson(_joinJson(token: 'token-2')),
    );
    final refreshed = await engine.tokenProvider!.call();
    expect(refreshed.token, 'token-2');
    expect(refreshed.chatRoomId, initial.chatRoomId);
    await session.dispose();
  });
}
