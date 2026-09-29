import 'dart:async';
import 'dart:convert';

import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeJoinInfo extends ChatJoinInfo {
  const _FakeJoinInfo({
    required super.roomCode,
    required super.participantId,
    required super.userId,
    required super.displayName,
    required super.role,
    required super.json,
  }) : super(providerId: 'fake');
}

class _FakeSession extends ChatSession {
  _FakeSession(this.role);

  @override
  final ChatRole role;
  final _states = StreamController<ChatConnectionState>.broadcast();
  final _snapshots = StreamController<List<ChatMessage>>.broadcast();
  final _events = StreamController<ChatEvent>.broadcast();
  ChatConnectionState _state = ChatConnectionState.disconnected;
  final List<ChatMessage> _messages = [];

  @override
  String get providerId => 'fake';
  @override
  ChatCapabilities get capabilities => ChatCapabilities(
    canSendMessage: true,
    canDeleteMessage: role == ChatRole.host,
    canDisconnectUser: role == ChatRole.host,
  );
  @override
  ChatConnectionState get state => _state;
  @override
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  @override
  Stream<ChatConnectionState> get states => _states.stream;
  @override
  Stream<List<ChatMessage>> get messageSnapshots => _snapshots.stream;
  @override
  Stream<ChatEvent> get events => _events.stream;

  @override
  Future<void> connect(
    ChatJoinInfo joinInfo, {
    ChatCredentialProvider? credentialProvider,
  }) async {
    if (joinInfo is! _FakeJoinInfo) {
      throw const ChatError(
        code: ChatErrorCode.invalidJoinInfo,
        message: 'Fake session requires parsed credentials.',
        providerId: 'fake',
      );
    }
    if (credentialProvider != null) {
      final refreshed = await credentialProvider();
      if (refreshed is! _FakeJoinInfo) {
        throw const ChatError(
          code: ChatErrorCode.invalidJoinInfo,
          message: 'Fake session requires parsed refreshed credentials.',
          providerId: 'fake',
        );
      }
    }
    _state = ChatConnectionState.connected;
    _states.add(_state);
  }

  @override
  Future<void> sendMessage(String message) async {
    _messages.add(
      ChatMessage(
        id: 'm-${_messages.length}',
        userId: 'local',
        message: message,
        timestamp: DateTime.now(),
      ),
    );
    _snapshots.add(messages);
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    if (!capabilities.canDeleteMessage) {
      throw const ChatError(
        code: ChatErrorCode.unsupportedFeature,
        message: 'Not supported.',
      );
    }
  }

  @override
  Future<void> disconnectUser(String userId) async {
    if (!capabilities.canDisconnectUser) {
      throw const ChatError(
        code: ChatErrorCode.unsupportedFeature,
        message: 'Not supported.',
      );
    }
  }

  @override
  Future<void> disconnect() async {
    _state = ChatConnectionState.disconnected;
    _states.add(_state);
  }

  @override
  Future<void> dispose() async {
    _state = ChatConnectionState.disposed;
    await _states.close();
    await _snapshots.close();
    await _events.close();
  }
}

class _FakeFactory extends ChatSessionFactory {
  @override
  String get providerId => 'fake';

  @override
  ChatJoinInfo parseJoinInfo(Map<String, dynamic> json) => _FakeJoinInfo(
    roomCode: json['roomCode'].toString(),
    participantId: json['participantId'].toString(),
    userId: json['userId'].toString(),
    displayName: json['displayName'].toString(),
    role: ChatRole.tryParse(json['role'])!,
    json: json,
  );

  @override
  ChatSession createSession(ChatJoinInfo joinInfo) {
    if (joinInfo is! _FakeJoinInfo) {
      throw const ChatError(
        code: ChatErrorCode.invalidJoinInfo,
        message: 'Fake factory requires parsed credentials.',
        providerId: 'fake',
      );
    }
    return _FakeSession(joinInfo.role);
  }
}

class _FakeStandaloneProvisioner implements StandaloneChatProvisioner {
  int createCalls = 0;
  int joinCalls = 0;
  int provisionCalls = 0;
  String? lastProvisionParticipantId;
  String? lastParticipantCredential;

  @override
  Future<ChatJoinInfo> create({
    required String userId,
    required String displayName,
    ChatRole role = ChatRole.host,
    String? roomCode,
  }) async {
    createCalls++;
    return _generic(
      roomCode: roomCode ?? 'created-room',
      participantId: 'created-participant',
      userId: userId,
      displayName: displayName,
      role: role,
    );
  }

  @override
  Future<ChatJoinInfo> join({
    required String roomCode,
    required String userId,
    required String displayName,
    ChatRole role = ChatRole.participant,
  }) async {
    joinCalls++;
    return _generic(
      roomCode: roomCode,
      participantId: 'joined-participant-$joinCalls',
      userId: userId,
      displayName: displayName,
      role: role,
    );
  }

  @override
  Future<ChatJoinInfo> provision({
    required String roomCode,
    required String participantId,
    String? participantCredential,
  }) async {
    provisionCalls++;
    lastProvisionParticipantId = participantId;
    lastParticipantCredential = participantCredential;
    final role = participantId.startsWith('created-')
        ? ChatRole.host
        : ChatRole.participant;
    return _generic(
      roomCode: roomCode,
      participantId: participantId,
      userId: role == ChatRole.host ? 'host-user' : 'join-user',
      displayName: role == ChatRole.host ? 'Host' : 'Join User',
      role: role,
    );
  }

  @override
  Future<List<ChatRoomSummary>> listRooms() async => const [];

  ChatJoinInfo _generic({
    required String roomCode,
    required String participantId,
    required String userId,
    required String displayName,
    required ChatRole role,
  }) {
    final json = <String, dynamic>{
      'chatProvider': 'fake',
      'roomCode': roomCode,
      'participantId': participantId,
      'userId': userId,
      'displayName': displayName,
      'role': role.wireName,
      'participantCredential': 'proof-$participantId',
      'context': 'standalone',
    };
    return ChatJoinInfo(
      providerId: 'fake',
      roomCode: roomCode,
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
  test('legacy chat moderation flags map to typed execution capabilities', () {
    const capabilities = ChatCapabilities(
      canDeleteMessage: true,
      canDisconnectUser: true,
    );
    expect(
      capabilities.managementCapabilities.deleteMessage.execution,
      ChatManagementExecution.client,
    );
    expect(capabilities.managementCapabilities.removeMember.supported, isTrue);
    expect(capabilities.managementCapabilities.banMember.supported, isFalse);
  });
  test('chat token request carries the participant credential proof', () async {
    late Map<String, dynamic> requestBody;
    final backend = ChatBackendClient(
      ChatBackendConfig.fromUrl('https://example.test'),
      httpClient: MockClient((request) async {
        requestBody = Map<String, dynamic>.from(
          jsonDecode(request.body) as Map,
        );
        return http.Response(
          jsonEncode({
            'contractVersion': 1,
            'chatProvider': 'fake',
            'roomCode': '123456',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await backend.issueToken(
      roomCode: '123456',
      participantId: 'viewer-1',
      participantCredential: 'proof-viewer-1',
      roomOwnerCredential: 'owner-proof',
    );

    expect(requestBody['participantId'], 'viewer-1');
    expect(requestBody['participantCredential'], 'proof-viewer-1');
    expect(requestBody['roomOwnerCredential'], 'owner-proof');
    backend.dispose();
  });

  test(
    'hybrid member removal sync marks provider action as already enforced',
    () async {
      late Uri requestUri;
      late Map<String, dynamic> requestBody;
      final backend = ChatBackendClient(
        ChatBackendConfig.fromUrl('https://example.test'),
        httpClient: MockClient((request) async {
          requestUri = request.url;
          requestBody = Map<String, dynamic>.from(
            jsonDecode(request.body) as Map,
          );
          return http.Response(
            jsonEncode({'contractVersion': 1, 'ok': true}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final joinInfo = ChatJoinInfo(
        providerId: 'fake',
        roomCode: '123456',
        participantId: 'host-1',
        userId: 'host-user',
        displayName: 'Host',
        role: ChatRole.host,
        context: ChatRoomContext.attached,
        json: const {
          'participantCredential': 'proof-host-1',
          'roomOwnerCredential': 'owner-proof',
          'management': {'removeMember': true},
        },
      );
      final moderation = backend.moderationFor(joinInfo);

      await (moderation as ChatModerationStateSync).syncRemovedMember('user-2');

      expect(requestUri.path, '/rooms/123456/chat/manage/remove');
      expect(requestBody['targetUserId'], 'user-2');
      expect(requestBody['providerEnforced'], isTrue);
      expect(requestBody['requesterParticipantId'], 'host-1');
      expect(requestBody['participantCredential'], 'proof-host-1');
      expect(requestBody['roomOwnerCredential'], 'owner-proof');
      backend.dispose();
    },
  );

  test(
    'chat registry is independent and role capabilities are explicit',
    () async {
      final registry = ChatRegistry([_FakeFactory()]);
      expect(registry.providerIds, ['fake']);

      final host = registry
          .require('fake')
          .createSession(
            const _FakeJoinInfo(
              roomCode: '123456',
              participantId: 'media-host-1',
              userId: 'host-1',
              displayName: 'Host',
              role: ChatRole.host,
              json: {},
            ),
          );
      expect(host.capabilities.canDeleteMessage, isTrue);

      final viewer = registry
          .require('fake')
          .createSession(
            const _FakeJoinInfo(
              roomCode: '123456',
              participantId: 'media-viewer-1',
              userId: 'viewer-1',
              displayName: 'Viewer',
              role: ChatRole.viewer,
              json: {},
            ),
          );
      expect(viewer.capabilities.canSendMessage, isTrue);
      expect(viewer.capabilities.canDeleteMessage, isFalse);

      await host.dispose();
      await viewer.dispose();
    },
  );

  test(
    'standalone create parses generic credentials and refreshes the same participant',
    () async {
      final provisioner = _FakeStandaloneProvisioner();
      final client = ChatClient.direct(
        registry: ChatRegistry([_FakeFactory()]),
        provisioner: provisioner,
      );

      final room = await client.createStandaloneRoom(
        userId: 'host-user',
        displayName: 'Host',
      );

      expect(room.session, isA<_FakeSession>());
      expect(provisioner.createCalls, 1);
      expect(provisioner.provisionCalls, 1);
      expect(provisioner.lastProvisionParticipantId, 'created-participant');
      expect(
        provisioner.lastParticipantCredential,
        'proof-created-participant',
      );

      await room.dispose();
      client.dispose();
    },
  );

  test(
    'standalone join refreshes credentials instead of joining a second time',
    () async {
      final provisioner = _FakeStandaloneProvisioner();
      final client = ChatClient.direct(
        registry: ChatRegistry([_FakeFactory()]),
        provisioner: provisioner,
      );

      final room = await client.joinStandaloneRoom(
        roomCode: '123456',
        userId: 'join-user',
        displayName: 'Join User',
      );

      expect(room.session, isA<_FakeSession>());
      expect(provisioner.joinCalls, 1);
      expect(provisioner.provisionCalls, 1);
      expect(provisioner.lastProvisionParticipantId, 'joined-participant-1');
      expect(
        provisioner.lastParticipantCredential,
        'proof-joined-participant-1',
      );

      await room.dispose();
      client.dispose();
    },
  );
}
