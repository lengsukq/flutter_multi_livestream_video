import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_chat_tencent/flutter_realtime_chat_tencent.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeEngine implements TencentChatEngine {
  TencentChatEngineEvents events = const TencentChatEngineEvents();
  TencentChatTokenProvider? tokenProvider;
  final List<String> calls = [];

  @override
  Future<void> connect(
    TencentChatJoinInfo info,
    TencentChatEngineEvents events, {
    TencentChatTokenProvider? tokenProvider,
  }) async {
    this.events = events;
    this.tokenProvider = tokenProvider;
    calls.add('connect:${info.userSig}');
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

Map<String, dynamic> _joinJson({String sig = 'sig-1'}) => {
  'contractVersion': 1,
  'chatProvider': 'tencent-chat',
  'roomCode': '123456',
  'participantId': 'participant-1',
  'userId': 'logical-user-1',
  'displayName': 'Tencent User',
  'role': 'host',
  'chat': {
    'sdkAppId': 1400000001,
    'groupId': 'rm_123456',
    'providerUserId': 'u_123',
    'userSig': sig,
    'capabilities': ['SEND_MESSAGE'],
    'userSigExpirationTimeMs': DateTime.now()
        .add(const Duration(hours: 1))
        .millisecondsSinceEpoch,
  },
};

void main() {
  test('Tencent adapter exposes send but not unsafe moderation', () async {
    final engine = _FakeEngine();
    final factory = TencentChatSessionFactory(
      engineFactory: () async => engine,
    );
    final joinInfo = factory.parseJoinInfo(_joinJson());
    final session = factory.createSession(joinInfo);
    await session.connect(joinInfo);

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
          ChatErrorCode.unsupportedFeature,
        ),
      ),
    );
    await session.dispose();
  });

  test('Tencent message events keep logical user identity', () async {
    final engine = _FakeEngine();
    final factory = TencentChatSessionFactory(
      engineFactory: () async => engine,
    );
    final joinInfo = factory.parseJoinInfo(_joinJson());
    final session = factory.createSession(joinInfo);
    await session.connect(joinInfo);

    engine.events.onMessage?.call({
      'id': 'm1',
      'userId': 'logical-user-2',
      'displayName': 'Other User',
      'message': 'hello',
      'timestampMs': 1000,
      'attributes': {'providerUserId': 'u_other'},
    });
    expect(session.messages.single.userId, 'logical-user-2');
    expect(session.messages.single.displayName, 'Other User');
    await session.dispose();
  });

  test('Tencent UserSig refresh cannot change provider identity', () async {
    final engine = _FakeEngine();
    final factory = TencentChatSessionFactory(
      engineFactory: () async => engine,
    );
    final initial = factory.parseJoinInfo(_joinJson());
    final session = factory.createSession(initial);
    await session.connect(
      initial,
      credentialProvider: () async =>
          TencentChatJoinInfo.fromJson(_joinJson(sig: 'sig-2')),
    );
    final refreshed = await engine.tokenProvider!.call();
    expect(refreshed.userSig, 'sig-2');
    expect(refreshed.providerUserId, initial.providerUserId);
    await session.dispose();
  });
}
