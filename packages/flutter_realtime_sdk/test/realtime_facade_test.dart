import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_media_session.dart';

void main() {
  group('Realtime facade', () {
    test(
      'direct meeting resolves public AWS provider to meeting engine',
      () async {
        final meetingFactory = FakeMediaSessionFactory(
          providerId: 'meeting-sdk',
        );
        final liveFactory = FakeMediaSessionFactory(providerId: 'live-sdk');
        final realtime = Realtime.standard(
          platformResolver: () => RealtimeRuntimePlatform.android,
          drivers: _awsLikeDrivers(meetingFactory, liveFactory),
        );

        final connection = await realtime.open(
          RealtimeRequest.join(
            type: RealtimeExperience.meeting,
            user: const RealtimeUser(id: 'user-1', name: 'Leo'),
            roomCode: 'room-1',
            source: const RealtimeSource.credentials(
              media: RealtimeCredentials(
                providerId: 'aws',
                payload: <String, dynamic>{},
              ),
            ),
          ),
        );

        expect(connection.providerId, 'aws');
        expect(connection.mediaEngineProviderId, 'meeting-sdk');
        expect(meetingFactory.parsedPayloads.single['roomMode'], 'meeting');
        expect(meetingFactory.parsedPayloads.single['role'], 'participant');
        expect(meetingFactory.parsedPayloads.single['participantId'], 'user-1');
        expect(liveFactory.createdSessions, isEmpty);

        final session = meetingFactory.createdSessions.single;
        await connection.dispose();
        expect(session.disposeCount, 1);
      },
    );

    test('direct live resolves public AWS provider to live engine', () async {
      final meetingFactory = FakeMediaSessionFactory(providerId: 'meeting-sdk');
      final liveFactory = FakeMediaSessionFactory(providerId: 'live-sdk');
      final realtime = Realtime.standard(
        platformResolver: () => RealtimeRuntimePlatform.android,
        drivers: _awsLikeDrivers(meetingFactory, liveFactory),
      );

      final connection = await realtime.open(
        RealtimeRequest.join(
          type: RealtimeExperience.live,
          user: const RealtimeUser(id: 'viewer-1', name: 'Viewer'),
          roomCode: 'live-1',
          source: const RealtimeSource.credentials(
            media: RealtimeCredentials(
              providerId: 'aws',
              payload: <String, dynamic>{},
            ),
          ),
        ),
      );

      expect(connection.providerId, 'aws');
      expect(connection.mediaEngineProviderId, 'live-sdk');
      expect(liveFactory.parsedPayloads.single['roomMode'], 'broadcast');
      expect(liveFactory.parsedPayloads.single['role'], 'viewer');
      expect(meetingFactory.createdSessions, isEmpty);

      await connection.dispose();
    });

    test(
      'direct media can attach product chat through one open call',
      () async {
        final mediaFactory = FakeMediaSessionFactory(providerId: 'media');
        final chatFactory = _FakeChatFactory('product-chat');
        final realtime = Realtime.standard(
          platformResolver: () => RealtimeRuntimePlatform.android,
          drivers: [
            RealtimeProviderDriver(
              platforms: const {RealtimeRuntimePlatform.android},
              plugin: RealtimeProviderPlugin(
                id: 'media',
                metadata: const RealtimeProviderMetadata(displayName: 'Media'),
                mediaFactory: mediaFactory,
                renderer: const _FakeRenderer(),
              ),
            ),
            RealtimeProviderDriver(
              platforms: const {RealtimeRuntimePlatform.android},
              plugin: RealtimeProviderPlugin(
                id: 'product-chat',
                metadata: const RealtimeProviderMetadata(
                  displayName: 'Product Chat',
                ),
                chatFactory: chatFactory,
              ),
            ),
          ],
        );

        final connection = await realtime.open(
          RealtimeRequest.join(
            type: RealtimeExperience.meeting,
            user: const RealtimeUser(id: 'user-1', name: 'Leo'),
            roomCode: 'room-1',
            source: const RealtimeSource.credentials(
              media: RealtimeCredentials(
                providerId: 'media',
                payload: <String, dynamic>{},
              ),
              chat: RealtimeCredentials(
                providerId: 'product-chat',
                payload: <String, dynamic>{},
              ),
            ),
          ),
        );

        expect(connection.mediaRoom, isNotNull);
        expect(connection.chatRoom, isNull);
        expect(connection.chatSession?.providerId, 'product-chat');
        expect(connection.capabilities.chat, isNotNull);
        expect(chatFactory.parsedPayloads.single['roomCode'], 'room-1');
        expect(chatFactory.parsedPayloads.single['userId'], 'user-1');

        await connection.dispose();
      },
    );

    test('direct standalone chat uses the same open API', () async {
      final chatFactory = _FakeChatFactory('product-chat');
      final realtime = Realtime.standard(
        platformResolver: () => RealtimeRuntimePlatform.android,
        drivers: [
          RealtimeProviderDriver(
            platforms: const {RealtimeRuntimePlatform.android},
            plugin: RealtimeProviderPlugin(
              id: 'product-chat',
              metadata: const RealtimeProviderMetadata(
                displayName: 'Product Chat',
              ),
              chatFactory: chatFactory,
            ),
          ),
        ],
      );

      final connection = await realtime.open(
        RealtimeRequest.join(
          type: RealtimeExperience.chat,
          user: const RealtimeUser(id: 'user-1', name: 'Leo'),
          roomCode: 'chat-1',
          source: const RealtimeSource.credentials(
            chat: RealtimeCredentials(
              providerId: 'product-chat',
              payload: <String, dynamic>{},
            ),
          ),
        ),
      );

      expect(connection.mediaRoom, isNull);
      expect(connection.chatRoom, isNotNull);
      expect(connection.roomCode, 'chat-1');
      expect(connection.providerId, 'product-chat');
      expect(connection.state.isConnected, isTrue);

      await connection.dispose();
    });

    test('backend media create and join use facade defaults', () async {
      final mediaFactory = FakeMediaSessionFactory(providerId: 'fake');
      final adapters = RealtimeMediaAdapters([
        RealtimeMediaAdapter(
          sessionFactory: mediaFactory,
          renderer: const _FakeRenderer(),
        ),
      ]);
      final provisioner = _FakeMediaProvisioner('fake');
      final sdk = RealtimeSdk(
        backendUrl: 'https://example.test',
        plugins: [
          RealtimeProviderPlugin(
            id: 'fake',
            metadata: const RealtimeProviderMetadata(displayName: 'Fake'),
            mediaFactory: mediaFactory,
            renderer: const _FakeRenderer(),
          ),
        ],
        clientFactory: () => RealtimeClient(
          backendUrl: 'https://example.test',
          mediaAdapters: adapters,
          mediaClientFactory: () => MediaClient.direct(
            registry: adapters.registry,
            provisioner: provisioner,
          ),
        ),
      );
      final realtime = Realtime.fromSdk(sdk);

      final meetingCreated = await realtime.open(
        RealtimeRequest.create(
          type: RealtimeExperience.meeting,
          user: const RealtimeUser(id: 'member-1', name: 'Member'),
          roomCode: 'meeting-1',
        ),
      );
      expect(provisioner.lastCreateMode, MediaRoomMode.meeting);
      expect(provisioner.lastCreateRole, MediaRole.participant);
      await meetingCreated.dispose();

      final created = await realtime.open(
        RealtimeRequest.create(
          type: RealtimeExperience.live,
          user: const RealtimeUser(id: 'host-1', name: 'Host'),
          roomCode: 'live-1',
        ),
      );
      expect(provisioner.lastCreateMode, MediaRoomMode.broadcast);
      expect(provisioner.lastCreateRole, MediaRole.host);
      await created.dispose();

      final joined = await realtime.open(
        RealtimeRequest.join(
          type: RealtimeExperience.live,
          user: const RealtimeUser(id: 'viewer-1', name: 'Viewer'),
          roomCode: 'live-1',
          roomOwnerCredential: 'owner-token',
        ),
      );
      expect(provisioner.lastJoinRole, isNull);
      expect(provisioner.lastRoomOwnerCredential, 'owner-token');
      await joined.dispose();
    });

    test(
      'backend standalone chat creates through facade provisioner',
      () async {
        final chatFactory = _FakeChatFactory('product-chat');
        final provisioner = _FakeStandaloneChatProvisioner('product-chat');
        final sdk = RealtimeSdk(
          plugins: [
            RealtimeProviderPlugin(
              id: 'product-chat',
              metadata: const RealtimeProviderMetadata(
                displayName: 'Product Chat',
              ),
              chatFactory: chatFactory,
            ),
          ],
        );
        final realtime = Realtime.fromSdk(
          sdk,
          standaloneChatProvisionerFactory: () => provisioner,
        );

        final connection = await realtime.open(
          RealtimeRequest.create(
            type: RealtimeExperience.chat,
            user: const RealtimeUser(id: 'host-1', name: 'Host'),
            roomCode: 'chat-1',
          ),
        );

        expect(connection.roomCode, 'chat-1');
        expect(connection.providerId, 'product-chat');
        expect(provisioner.lastCreateRole, ChatRole.host);
        await connection.dispose();

        final joined = await realtime.open(
          RealtimeRequest.join(
            type: RealtimeExperience.chat,
            user: const RealtimeUser(id: 'user-2', name: 'User 2'),
            roomCode: 'chat-1',
          ),
        );
        expect(provisioner.lastJoinRole, ChatRole.participant);
        await joined.dispose();
      },
    );

    test('backend join without room code fails before provisioning', () async {
      final realtime = Realtime.standard(backendUrl: 'https://example.test');

      await expectLater(
        realtime.open(
          RealtimeRequest.join(
            type: RealtimeExperience.meeting,
            user: const RealtimeUser(id: 'user-1', name: 'Leo'),
          ),
        ),
        throwsA(
          isA<RealtimeException>().having(
            (error) => error.code,
            'code',
            RealtimeErrorCode.invalidArgument,
          ),
        ),
      );
    });

    test('direct credentials reject create action', () async {
      final realtime = Realtime.standard(
        platformResolver: () => RealtimeRuntimePlatform.android,
        drivers: const [],
      );

      await expectLater(
        realtime.open(
          RealtimeRequest.create(
            type: RealtimeExperience.meeting,
            user: const RealtimeUser(id: 'user-1', name: 'Leo'),
            source: const RealtimeSource.credentials(
              media: RealtimeCredentials(
                providerId: 'fake',
                payload: <String, dynamic>{},
              ),
            ),
          ),
        ),
        throwsA(
          isA<RealtimeException>().having(
            (error) => error.code,
            'code',
            RealtimeErrorCode.invalidArgument,
          ),
        ),
      );
    });

    test(
      'known provider on unsupported platform maps to typed error',
      () async {
        final mediaFactory = FakeMediaSessionFactory(providerId: 'mobile-only');
        final realtime = Realtime.standard(
          platformResolver: () => RealtimeRuntimePlatform.web,
          drivers: [
            RealtimeProviderDriver(
              platforms: const {RealtimeRuntimePlatform.android},
              plugin: RealtimeProviderPlugin(
                id: 'mobile-only',
                metadata: const RealtimeProviderMetadata(
                  displayName: 'Mobile only',
                ),
                mediaFactory: mediaFactory,
                renderer: const _FakeRenderer(),
              ),
            ),
          ],
        );

        await expectLater(
          realtime.open(
            RealtimeRequest.join(
              type: RealtimeExperience.meeting,
              user: const RealtimeUser(id: 'user-1', name: 'Leo'),
              roomCode: 'room-1',
              source: const RealtimeSource.credentials(
                media: RealtimeCredentials(
                  providerId: 'mobile-only',
                  payload: <String, dynamic>{},
                ),
              ),
            ),
          ),
          throwsA(
            isA<RealtimeException>().having(
              (error) => error.code,
              'code',
              RealtimeErrorCode.unsupportedPlatform,
            ),
          ),
        );
      },
    );
  });
}

List<RealtimeProviderDriver> _awsLikeDrivers(
  FakeMediaSessionFactory meetingFactory,
  FakeMediaSessionFactory liveFactory,
) {
  return [
    RealtimeProviderDriver(
      platforms: const {RealtimeRuntimePlatform.android},
      publicProviderId: 'aws',
      mediaRoomModes: const {MediaRoomMode.meeting},
      plugin: RealtimeProviderPlugin(
        id: 'meeting-sdk',
        metadata: const RealtimeProviderMetadata(displayName: 'AWS'),
        mediaFactory: meetingFactory,
        renderer: const _FakeRenderer(),
      ),
    ),
    RealtimeProviderDriver(
      platforms: const {RealtimeRuntimePlatform.android},
      publicProviderId: 'aws',
      mediaRoomModes: const {MediaRoomMode.broadcast},
      plugin: RealtimeProviderPlugin(
        id: 'live-sdk',
        metadata: const RealtimeProviderMetadata(displayName: 'AWS'),
        mediaFactory: liveFactory,
        renderer: const _FakeRenderer(),
      ),
    ),
  ];
}

class _FakeMediaProvisioner implements MediaRoomProvisioner {
  _FakeMediaProvisioner(this.providerId);

  final String providerId;
  MediaRoomMode? lastCreateMode;
  MediaRole? lastCreateRole;
  MediaRole? lastJoinRole;
  String? lastRoomOwnerCredential;

  @override
  Future<MediaRoomJoinResponse> create({
    required MediaIdentity identity,
    MediaRoomMode roomMode = MediaRoomMode.meeting,
    MediaRole? role,
    String? roomCode,
  }) async {
    lastCreateMode = roomMode;
    lastCreateRole = role;
    final effectiveRole =
        role ??
        (roomMode == MediaRoomMode.broadcast
            ? MediaRole.host
            : MediaRole.participant);
    return _response(
      roomCode: roomCode ?? 'created-room',
      participantId: identity.userId,
      role: effectiveRole,
    );
  }

  @override
  Future<MediaRoomJoinResponse> join({
    required String roomCode,
    required MediaIdentity identity,
    MediaRole? role,
    String? roomOwnerCredential,
  }) async {
    lastJoinRole = role;
    lastRoomOwnerCredential = roomOwnerCredential;
    return _response(
      roomCode: roomCode,
      participantId: identity.userId,
      role: role ?? MediaRole.participant,
    );
  }

  @override
  Future<MediaRoomJoinResponse> refresh({
    required String roomCode,
    required String participantId,
    required MediaRole role,
    String? participantCredential,
  }) async {
    return _response(
      roomCode: roomCode,
      participantId: participantId,
      role: role,
    );
  }

  MediaRoomJoinResponse _response({
    required String roomCode,
    required String participantId,
    required MediaRole role,
  }) {
    return MediaRoomJoinResponse(
      roomCode: roomCode,
      providerId: providerId,
      role: role,
      json: {
        'provider': providerId,
        'roomCode': roomCode,
        'participantId': participantId,
        'role': role.wireName,
      },
    );
  }
}

class _FakeStandaloneChatProvisioner implements StandaloneChatProvisioner {
  _FakeStandaloneChatProvisioner(this.providerId);

  final String providerId;
  ChatRole? lastCreateRole;
  ChatRole? lastJoinRole;

  @override
  Future<ChatJoinInfo> create({
    required String userId,
    required String displayName,
    ChatRole role = ChatRole.host,
    String? roomCode,
  }) async {
    lastCreateRole = role;
    return _joinInfo(
      roomCode: roomCode ?? 'created-chat',
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
    lastJoinRole = role;
    return _joinInfo(
      roomCode: roomCode,
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
    return _joinInfo(
      roomCode: roomCode,
      userId: participantId,
      displayName: participantId,
      role: ChatRole.participant,
    );
  }

  @override
  Future<List<ChatRoomSummary>> listRooms() async => const [];

  ChatJoinInfo _joinInfo({
    required String roomCode,
    required String userId,
    required String displayName,
    required ChatRole role,
  }) {
    final json = <String, dynamic>{
      'chatProvider': providerId,
      'roomCode': roomCode,
      'participantId': userId,
      'userId': userId,
      'displayName': displayName,
      'role': role.wireName,
    };
    return ChatJoinInfo(
      providerId: providerId,
      roomCode: roomCode,
      participantId: userId,
      userId: userId,
      displayName: displayName,
      role: role,
      json: json,
      context: ChatRoomContext.standalone,
    );
  }
}

class _FakeChatFactory implements ChatSessionFactory {
  _FakeChatFactory(this.providerId);

  @override
  final String providerId;

  final List<Map<String, dynamic>> parsedPayloads = [];

  @override
  ChatJoinInfo parseJoinInfo(Map<String, dynamic> json) {
    parsedPayloads.add(Map<String, dynamic>.from(json));
    return ChatJoinInfo(
      providerId: providerId,
      roomCode: json['roomCode']?.toString() ?? '',
      participantId: json['participantId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      role: ChatRole.tryParse(json['role']) ?? ChatRole.participant,
      json: json,
    );
  }

  @override
  ChatSession createSession(ChatJoinInfo joinInfo) =>
      _FakeChatSession(providerId, joinInfo.role);
}

class _FakeChatSession implements ChatSession {
  _FakeChatSession(this.providerId, this.role);

  @override
  final String providerId;
  @override
  final ChatRole role;

  final _states = StreamController<ChatConnectionState>.broadcast();
  final _messages = StreamController<List<ChatMessage>>.broadcast();
  final _events = StreamController<ChatEvent>.broadcast();

  @override
  ChatCapabilities get capabilities =>
      const ChatCapabilities(canSendMessage: true);
  @override
  ChatConnectionState get state => ChatConnectionState.connected;
  @override
  List<ChatMessage> get messages => const [];
  @override
  Stream<ChatConnectionState> get states => _states.stream;
  @override
  Stream<List<ChatMessage>> get messageSnapshots => _messages.stream;
  @override
  Stream<ChatEvent> get events => _events.stream;

  @override
  Future<void> connect(
    ChatJoinInfo joinInfo, {
    ChatCredentialProvider? credentialProvider,
  }) async {}
  @override
  Future<void> sendMessage(String message) async {}
  @override
  Future<void> deleteMessage(String messageId) async {}
  @override
  Future<void> disconnectUser(String userId) async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<void> dispose() async {
    await _states.close();
    await _messages.close();
    await _events.close();
  }
}

class _FakeRenderer extends MediaTrackRenderer {
  const _FakeRenderer();

  @override
  Widget buildView(
    BuildContext context,
    MediaVideoTrack track, {
    MediaVideoFit fit = MediaVideoFit.cover,
  }) =>
      const SizedBox.shrink();
}
