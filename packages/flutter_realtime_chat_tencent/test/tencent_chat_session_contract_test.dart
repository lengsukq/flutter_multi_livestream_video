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

Map<String, dynamic> _joinJson({
  String sig = 'sig-1',
  String role = 'host',
  String participantId = 'participant-1',
  String userId = 'logical-user-1',
  String displayName = 'Tencent User',
}) => {
  'contractVersion': 1,
  'chatProvider': 'tencent-chat',
  'roomCode': '123456',
  'participantId': participantId,
  'userId': userId,
  'displayName': displayName,
  'role': role,
  'participantCredential': 'proof-$participantId',
  'context': 'standalone',
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

class _FakeStandaloneProvisioner implements StandaloneChatProvisioner {
  @override
  Future<ChatJoinInfo> create({
    required String userId,
    required String displayName,
    ChatRole role = ChatRole.host,
    String? roomCode,
  }) async => _generic(
    role: role,
    participantId: 'participant-1',
    userId: userId,
    displayName: displayName,
  );

  @override
  Future<ChatJoinInfo> join({
    required String roomCode,
    required String userId,
    required String displayName,
    ChatRole role = ChatRole.participant,
  }) async => _generic(
    role: role,
    participantId: 'participant-2',
    userId: userId,
    displayName: displayName,
  );

  @override
  Future<ChatJoinInfo> provision({
    required String roomCode,
    required String participantId,
    String? participantCredential,
  }) async => _generic(
    role: ChatRole.host,
    participantId: participantId,
    userId: 'logical-user-1',
    displayName: 'Tencent User',
  );

  @override
  Future<List<ChatRoomSummary>> listRooms() async => const [];

  ChatJoinInfo _generic({
    required ChatRole role,
    required String participantId,
    required String userId,
    required String displayName,
  }) {
    final json = _joinJson(
      role: role.wireName,
      participantId: participantId,
      userId: userId,
      displayName: displayName,
    );
    return ChatJoinInfo(
      providerId: 'tencent-chat',
      roomCode: '123456',
      participantId: participantId,
      userId: userId,
      displayName: displayName,
      role: role,
      json: json,
      context: ChatRoomContext.standalone,
    );
  }
}

void main() {
  test(
    'standalone ChatClient parses Tencent credentials before session creation',
    () async {
      final engine = _FakeEngine();
      final factory = TencentChatSessionFactory(
        engineFactory: () async => engine,
      );
      final client = ChatClient.direct(
        registry: ChatRegistry([factory]),
        provisioner: _FakeStandaloneProvisioner(),
      );

      final room = await client.createStandaloneRoom(
        userId: 'logical-user-1',
        displayName: 'Tencent User',
        roomCode: '123456',
      );

      expect(room.session.providerId, 'tencent-chat');
      expect(engine.calls, contains('connect:sig-1'));

      await room.dispose();
      client.dispose();
    },
  );

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
