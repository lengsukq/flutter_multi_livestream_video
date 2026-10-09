import 'dart:async';

import 'package:agora_chat_sdk/agora_chat_sdk.dart';
// The vendor platform interface is used only to simulate native SDK state.
// ignore: depend_on_referenced_packages
import 'package:agora_chat_sdk_interface/agora_chat_sdk_interface.dart'
    as platform;
import 'package:flutter_realtime_chat_agora/flutter_realtime_chat_agora.dart';
import 'package:flutter_realtime_chat_agora/src/agora_chat_engine_native.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';

class _NativeClient extends platform.Client {
  final calls = <String>[];
  String? user;
  bool failJoin = false;
  bool failLeave = false;
  bool failLogout = false;
  Completer<void>? pendingLogin;

  @override
  platform.ChatRoomManager get chatRoomManager => _NativeRooms(this);

  @override
  Future<dynamic> callNativeMethod(String method, [dynamic params]) async {
    calls.add(method);
    switch (method) {
      case 'getCurrentUser':
        return {method: user};
      case 'isLoggedInBefore':
        return {method: user != null};
      case 'login':
        if (pendingLogin != null) await pendingLogin!.future;
        if (user != null) {
          throw ChatError(200, 'The user is already logged in');
        }
        user = params['userId'] as String;
      case 'logout':
        if (failLogout) throw ChatError(2, 'Logout failed');
        user = null;
    }
    return <String, dynamic>{};
  }
}

class _NativeRooms extends platform.ChatRoomManager {
  _NativeRooms(this.client);
  final _NativeClient client;

  @override
  Future<dynamic> callNativeMethod(String method, [dynamic params]) async {
    client.calls.add(method);
    if (method == 'joinChatRoom' && client.failJoin) {
      throw ChatError(403, 'Room join forbidden');
    }
    if (method == 'leaveChatRoom' && client.failLeave) {
      throw ChatError(2, 'Room leave failed');
    }
    return <String, dynamic>{};
  }
}

const _info = AgoraChatJoinInfo(
  roomCode: '123456',
  participantId: 'participant-1',
  userId: 'logical-user-1',
  displayName: 'User',
  role: ChatRole.participant,
  json: {},
  appKey: 'org#app',
  chatRoomId: 'room-1',
  providerUserId: 'provider-user-1',
  token: 'test-token',
  capabilities: ['SEND_MESSAGE'],
  tokenExpirationTimeMs: 9999999999999,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _NativeClient client;
  late platform.Client originalClient;
  late AgoraSdkChatEngine engine;

  setUp(() {
    originalClient = platform.Client.instance;
    client = _NativeClient();
    platform.Client.instance = client;
    engine = AgoraSdkChatEngine();
  });

  tearDown(() async {
    client.failLogout = false;
    await engine.dispose();
    platform.Client.instance = originalClient;
  });

  for (final staleUser in ['provider-user-1', 'previous-user']) {
    test('clears stale login for $staleUser before reauthentication', () async {
      client.user = staleUser;
      await engine.connect(_info, const AgoraChatEngineEvents());
      expect(
        client.calls.indexOf('logout'),
        lessThan(client.calls.indexOf('login')),
      );
      expect(client.user, _info.providerUserId);
      expect(client.calls.last, 'joinChatRoom');
    });
  }

  test('failed room join logs out and can be retried immediately', () async {
    client.failJoin = true;
    client.failLeave = true;
    await expectLater(
      engine.connect(_info, const AgoraChatEngineEvents()),
      throwsA(isA<ChatError>().having((error) => error.code, 'code', 403)),
    );
    expect(client.user, isNull);
    expect(
      client.calls,
      containsAllInOrder(['login', 'joinChatRoom', 'leaveChatRoom', 'logout']),
    );
    client.failJoin = false;
    client.failLeave = false;
    await engine.connect(_info, const AgoraChatEngineEvents());
    expect(client.user, _info.providerUserId);
  });

  test('normal disconnect permits rejoining without duplicate login', () async {
    await engine.connect(_info, const AgoraChatEngineEvents());
    await engine.disconnect();
    expect(client.user, isNull);
    await engine.connect(_info, const AgoraChatEngineEvents());
    expect(client.user, _info.providerUserId);
    expect(client.calls.where((method) => method == 'login'), hasLength(2));
  });

  test('another session cannot log out the active singleton owner', () async {
    await engine.connect(_info, const AgoraChatEngineEvents());
    final second = AgoraSdkChatEngine();
    final before = List<String>.of(client.calls);
    await expectLater(
      second.connect(_info, const AgoraChatEngineEvents()),
      throwsStateError,
    );
    await second.dispose();
    expect(client.calls, before);
    expect(client.user, _info.providerUserId);
  });

  test('disposing during login cleans up the late login result', () async {
    final pending = Completer<void>();
    client.pendingLogin = pending;
    var connected = false;
    final connecting = engine.connect(
      _info,
      AgoraChatEngineEvents(onConnected: () => connected = true),
    );
    final failure = expectLater(connecting, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    expect(client.calls, contains('login'));
    await engine.dispose();
    pending.complete();
    await failure;
    expect(connected, isFalse);
    expect(client.user, isNull);
    expect(client.calls, isNot(contains('joinChatRoom')));
  });

  test(
    'failed logout is surfaced and a new engine recovers stale state',
    () async {
      await engine.connect(_info, const AgoraChatEngineEvents());
      client.failLogout = true;
      await expectLater(engine.dispose(), throwsA(isA<ChatError>()));
      expect(client.user, _info.providerUserId);
      client.failLogout = false;
      engine = AgoraSdkChatEngine();
      await engine.connect(_info, const AgoraChatEngineEvents());
      expect(client.user, _info.providerUserId);
    },
  );
}
