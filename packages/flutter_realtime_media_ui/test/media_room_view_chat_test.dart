import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('standalone chat UI follows zh-CN host locale', (tester) async {
    final chat = _FakeChatSession();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: RealtimeStrings.supportedLocales,
        localizationsDelegates: RealtimeStrings.localizationsDelegates,
        home: Scaffold(
          body: RealtimeChatView(session: chat, roomCode: 'room-1'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('聊天'), findsOneWidget);
    expect(find.text('还没有消息'), findsOneWidget);
    expect(find.textContaining('房间 room-1'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await chat.dispose();
  });

  testWidgets(
    'standalone chat with showAppBar integrates back button and handles Enter to send',
    (tester) async {
      final chat = _FakeChatSession();

      await tester.pumpWidget(
        MaterialApp(
          home: RealtimeChatView(
            session: chat,
            roomCode: 'room-1',
            showAppBar: true,
          ),
        ),
      );
      await tester.pump();

      // Verify back button in glass header and no duplicate app bar
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);

      // Enter message
      await tester.enterText(find.byType(TextField), 'Hello World');
      await tester.pump();

      // Press Enter to send
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(chat.sentMessages, contains('Hello World'));

      await tester.pumpWidget(const SizedBox.shrink());
      await chat.dispose();
    },
  );

  testWidgets('standalone host can open capability-driven member management', (
    tester,
  ) async {
    final chat = _FakeChatSession(fakeRole: ChatRole.host);
    final moderation = _FakeChatModeration();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RealtimeChatView(
            session: chat,
            roomCode: 'room-1',
            moderation: moderation,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.admin_panel_settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Chat management'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.byIcon(Icons.person_remove_outlined), findsOneWidget);
    expect(find.text('Close chat room'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await chat.dispose();
  });

  testWidgets('room UI follows zh-CN host locale', (tester) async {
    final fixture = _RoomFixture();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: RealtimeStrings.supportedLocales,
        localizationsDelegates: RealtimeStrings.localizationsDelegates,
        home: MediaRoomView(
          room: fixture.room,
          renderer: const _FakeRenderer(),
          header: const Text('Current room capabilities'),
          config: const MediaRoomViewConfig(confirmBeforeLeave: false),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('现在只有你一个人'), findsOneWidget);
    expect(find.text('分享房间码即可邀请其他人加入'), findsOneWidget);
    expect(find.text('Current room capabilities'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await fixture.dispose();
  });

  testWidgets('screen share control toggles start and stop', (tester) async {
    final fixture = _RoomFixture(screenShare: true);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaRoomView(
          room: fixture.room,
          renderer: const _FakeRenderer(),
          config: const MediaRoomViewConfig(confirmBeforeLeave: false),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.screen_share_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.screen_share_outlined));
    await tester.pump();

    expect(fixture.media.screenShareCalls, <bool>[true]);
    expect(find.byIcon(Icons.stop_screen_share_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.stop_screen_share_outlined));
    await tester.pump();

    expect(fixture.media.screenShareCalls, <bool>[true, false]);
    expect(find.byIcon(Icons.screen_share_outlined), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await fixture.dispose();
  });

  testWidgets('RTC data alone does not create a product Chat button', (
    tester,
  ) async {
    final fixture = _RoomFixture();

    await tester.pumpWidget(
      MaterialApp(
        home: MediaRoomView(
          room: fixture.room,
          renderer: const _FakeRenderer(),
          config: const MediaRoomViewConfig(
            showRtcDataMessages: true,
            confirmBeforeLeave: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsNothing);
    expect(find.byIcon(Icons.data_object_rounded), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await fixture.dispose();
  });

  testWidgets('Chat panel adapts between compact and wide layouts', (
    tester,
  ) async {
    final fixture = _RoomFixture();
    final chat = _FakeChatSession();
    addTearDown(() => tester.view.resetPhysicalSize());

    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaRoomView(
          room: fixture.room,
          renderer: const _FakeRenderer(),
          chatSession: chat,
          config: const MediaRoomViewConfig(confirmBeforeLeave: false),
        ),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.data_object_rounded), findsNothing);
    await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
    await tester.pump();

    expect(find.byKey(const ValueKey('chat-panel-wide')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-panel-compact')), findsNothing);

    tester.view.physicalSize = const Size(480, 800);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('chat-panel-wide')), findsNothing);
    expect(find.byKey(const ValueKey('chat-panel-compact')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await chat.dispose();
    await fixture.dispose();
  });

  testWidgets('ChatSession drives Chat UI while RTC debug remains separate', (
    tester,
  ) async {
    final fixture = _RoomFixture();
    final chat = _FakeChatSession(
      messages: [
        ChatMessage(
          id: 'm-1',
          userId: 'user-a',
          displayName: 'Alice',
          message: 'hello',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1),
        ),
        ChatMessage(
          id: 'm-2',
          userId: 'user-me',
          displayName: 'Me',
          message: 'hi Alice',
          timestamp: DateTime.fromMillisecondsSinceEpoch(2),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaRoomView(
          room: fixture.room,
          renderer: const _FakeRenderer(),
          chatSession: chat,
          config: const MediaRoomViewConfig(
            showRtcDataMessages: true,
            confirmBeforeLeave: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.data_object_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
    await tester.pump();
    expect(
      find.byWidgetPredicate((widget) => widget is ListView && widget.reverse),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('chat-message-m-1-remote')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('chat-message-m-2-local')),
      findsOneWidget,
    );
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('hello'), findsOneWidget);
    expect(find.text('hi Alice'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.data_object_rounded));
    await tester.pump();
    expect(find.text('RTC Data'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await chat.dispose();
    await fixture.dispose();
  });

  testWidgets('screen share stage supports expand and compact toggle', (
    tester,
  ) async {
    final fixture = _RoomFixture(screenShare: true);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaRoomView(
          room: fixture.room,
          renderer: const _FakeRenderer(),
          config: const MediaRoomViewConfig(confirmBeforeLeave: false),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.screen_share_outlined));
    await tester.pump();

    expect(find.byIcon(Icons.open_in_full_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.open_in_full_rounded));
    await tester.pump();

    expect(find.byIcon(Icons.close_fullscreen_rounded), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await fixture.dispose();
  });

  testWidgets(
    'unread chat badge increments when panel is closed and clears on open',
    (tester) async {
      final fixture = _RoomFixture();
      final chat = _FakeChatSession();

      await tester.pumpWidget(
        MaterialApp(
          home: MediaRoomView(
            room: fixture.room,
            renderer: const _FakeRenderer(),
            chatSession: chat,
            config: const MediaRoomViewConfig(confirmBeforeLeave: false),
          ),
        ),
      );
      await tester.pump();

      chat.emitIncomingMessage(
        ChatMessage(
          id: 'm-new',
          userId: 'user-b',
          displayName: 'Bob',
          message: 'Unread ping',
          timestamp: DateTime.fromMillisecondsSinceEpoch(10),
        ),
      );
      await tester.pump(Duration.zero);
      await tester.pump();

      expect(find.text('1'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
      await tester.pump();

      expect(find.text('Unread ping'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await chat.dispose();
      await fixture.dispose();
    },
  );

  testWidgets(
    'room management merges Media and Chat members by logical userId',
    (tester) async {
      final fixture = _ManagedRoomFixture();
      final chat = _FakeChatSession();
      final moderation = _FakeChatModeration();

      await tester.pumpWidget(
        MaterialApp(
          home: MediaRoomView(
            room: fixture.room,
            renderer: const _FakeRenderer(),
            chatSession: chat,
            chatModeration: moderation,
            config: const MediaRoomViewConfig(confirmBeforeLeave: false),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.admin_panel_settings_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Room members'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Media online'), findsNWidgets(2));
      expect(find.text('Chat online'), findsNWidgets(2));
      expect(find.text('You'), findsOneWidget);
      expect(find.text('Remove from media'), findsOneWidget);
      expect(find.text('Remove from Chat'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await chat.dispose();
      await fixture.dispose();
    },
  );
}

class _ManagedRoomFixture {
  _ManagedRoomFixture()
    : media = _FakeMediaSession(),
      backend = MediaBackendClient(
        MediaBackendConfig.fromUrl(
          'http://localhost',
          heartbeatInterval: Duration.zero,
        ),
        transport: _ManagementTransport(),
      ) {
    room = MediaRoomSession.attach(
      roomCode: 'room-managed',
      participantId: 'participant-me',
      participantCredential: 'participant-proof',
      roomOwnerCredential: 'owner-proof',
      backendMetadata: const {
        'management': {
          'listParticipants': true,
          'removeParticipant': true,
          'closeRoom': true,
        },
      },
      session: media,
      presence: backend,
      management: backend,
      heartbeatInterval: Duration.zero,
    );
  }

  final _FakeMediaSession media;
  final MediaBackendClient backend;
  late final MediaRoomSession room;

  Future<void> dispose() async {
    await media.dispose();
    backend.dispose();
  }
}

class _ManagementTransport implements MediaBackendTransport {
  @override
  Future<MediaBackendTransportResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    String? body,
  }) async {
    if (uri.path.endsWith('/participants')) {
      return const MediaBackendTransportResponse(
        statusCode: 200,
        body:
            '{"participants":['
            '{"participantId":"participant-me","userId":"user-me","displayName":"Me","role":"participant"},'
            '{"participantId":"participant-alice","userId":"user-alice","displayName":"Alice","role":"participant"}'
            ']}',
      );
    }
    return const MediaBackendTransportResponse(
      statusCode: 200,
      body: '{"ok":true}',
    );
  }

  @override
  void close() {}
}

class _FakeChatModeration
    implements ChatModeration, ChatModerationCapabilitySource {
  final List<String> removedUsers = <String>[];

  @override
  ChatManagementCapabilities get moderationCapabilities =>
      const ChatManagementCapabilities(
        listMembers: ChatManagementCapability.backend(),
        removeMember: ChatManagementCapability.backend(),
        closeRoom: ChatManagementCapability.backend(),
      );

  @override
  Future<List<ChatMember>> listMembers() async => const [
    ChatMember(userId: 'user-me', displayName: 'Me', role: ChatRole.host),
    ChatMember(
      userId: 'user-alice',
      displayName: 'Alice',
      role: ChatRole.participant,
    ),
  ];

  @override
  Future<void> removeMember(String userId) async {
    removedUsers.add(userId);
  }

  @override
  Future<void> muteMember(String userId, {required bool muted}) async {}
  @override
  Future<void> banMember(String userId, {required bool banned}) async {}
  @override
  Future<void> recallMessage(String messageId) async {}
  @override
  Future<void> changeMemberRole(String userId, ChatRole role) async {}
  @override
  Future<void> closeRoom() async {}
}

class _FakeScreenShareTrack implements MediaVideoTrack {
  const _FakeScreenShareTrack();

  @override
  String get id => 'screen-share';

  @override
  String get participantId => 'participant-1';

  @override
  bool get isLocal => true;

  @override
  bool get isScreenShare => true;

  @override
  int get width => 1280;

  @override
  int get height => 720;

  @override
  double get aspectRatio => width / height;
}

class _RoomFixture {
  _RoomFixture({bool screenShare = false})
    : media = _FakeMediaSession(screenShare: screenShare),
      backend = MediaBackendClient(
        MediaBackendConfig.fromUrl(
          'http://localhost',
          heartbeatInterval: Duration.zero,
        ),
        transport: _FakeTransport(),
      ) {
    room = MediaRoomSession.attach(
      roomCode: 'room-1',
      participantId: 'participant-1',
      session: media,
      presence: backend,
      management: backend,
      heartbeatInterval: Duration.zero,
    );
  }

  final _FakeMediaSession media;
  final MediaBackendClient backend;
  late final MediaRoomSession room;

  Future<void> dispose() async {
    // MediaRoomView does not own the room unless the user presses Leave.
    // Close the fake provider streams directly so this widget-focused test
    // does not exercise backend leave/presence behavior covered by core tests.
    await media.dispose();
    backend.dispose();
  }
}

class _FakeTransport implements MediaBackendTransport {
  @override
  Future<MediaBackendTransportResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    String? body,
  }) async =>
      const MediaBackendTransportResponse(statusCode: 200, body: '{"ok":true}');

  @override
  void close() {}
}

class _FakeMediaSession implements InteractiveMediaSession {
  _FakeMediaSession({this.screenShare = false});

  final bool screenShare;
  final List<bool> screenShareCalls = <bool>[];
  final StreamController<MediaSessionState> _states =
      StreamController<MediaSessionState>.broadcast();
  final StreamController<MediaSnapshot> _snapshots =
      StreamController<MediaSnapshot>.broadcast();
  final StreamController<MediaEvent> _events =
      StreamController<MediaEvent>.broadcast();
  MediaSnapshot? _snapshot;

  @override
  String get providerId => 'fake';

  @override
  MediaRole get role => MediaRole.participant;

  @override
  MediaCapabilities get capabilities => MediaCapabilities(
    canSendData: true,
    canReceiveData: true,
    canScreenShare: screenShare,
  );

  @override
  MediaSessionState get state => MediaSessionState.connected;

  @override
  MediaSnapshot get snapshot =>
      _snapshot ??
      MediaSnapshot(state: state, role: role, capabilities: capabilities);

  @override
  Stream<MediaSessionState> get states => _states.stream;

  @override
  Stream<MediaSnapshot> get snapshots => _snapshots.stream;

  @override
  Stream<MediaEvent> get events => _events.stream;

  @override
  Future<void> sendMessage(String message, {String topic = 'chat'}) async {}

  @override
  Future<void> setMuted(bool muted) async {}

  @override
  Future<void> toggleMute() async {}

  @override
  Future<void> setVideoEnabled(bool enabled) async {}

  @override
  Future<void> setScreenShareEnabled(bool enabled) async {
    screenShareCalls.add(enabled);
    final next = MediaSnapshot(
      state: state,
      role: role,
      capabilities: capabilities,
      localScreenShareEnabled: enabled,
      contentShareTrack: enabled ? const _FakeScreenShareTrack() : null,
    );
    _snapshot = next;
    _snapshots.add(next);
  }

  @override
  Future<void> switchCamera(MediaCameraPosition position) async {}

  @override
  Future<List<MediaAudioDevice>> listAudioDevices() async => const [];

  @override
  Future<void> selectAudioDevice(MediaAudioDevice device) async {}

  @override
  Future<void> join(MediaJoinInfo joinInfo) async {}

  @override
  Future<void> leave() async {}

  @override
  Future<void> dispose() async {
    await _states.close();
    await _snapshots.close();
    await _events.close();
  }
}

class _FakeChatSession implements ChatSession, ChatSessionIdentity {
  _FakeChatSession({
    List<ChatMessage> messages = const [],
    this.fakeRole = ChatRole.participant,
  }) : _messages = List<ChatMessage>.of(messages);

  final List<ChatMessage> _messages;
  final ChatRole fakeRole;
  final StreamController<ChatConnectionState> _states =
      StreamController<ChatConnectionState>.broadcast();
  final StreamController<List<ChatMessage>> _snapshots =
      StreamController<List<ChatMessage>>.broadcast();
  final StreamController<ChatEvent> _events =
      StreamController<ChatEvent>.broadcast();
  bool _disposed = false;

  @override
  String get providerId => 'fake-chat';

  @override
  String get localParticipantId => 'participant-1';

  @override
  String get localUserId => 'user-me';

  @override
  String get localDisplayName => 'Me';

  @override
  ChatRole get role => fakeRole;

  @override
  ChatCapabilities get capabilities =>
      const ChatCapabilities(canSendMessage: true);

  @override
  ChatConnectionState get state =>
      _disposed ? ChatConnectionState.disposed : ChatConnectionState.connected;

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
  }) async {}

  final List<String> sentMessages = [];

  @override
  Future<void> sendMessage(String message) async {
    sentMessages.add(message);
  }

  void emitIncomingMessage(ChatMessage message) {
    _messages.add(message);
    _snapshots.add(List.unmodifiable(_messages));
  }

  @override
  Future<void> deleteMessage(String messageId) async {}

  @override
  Future<void> disconnectUser(String userId) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _states.close();
    await _snapshots.close();
    await _events.close();
  }
}

class _FakeRenderer extends MediaTrackRenderer {
  const _FakeRenderer();

  @override
  Widget buildView(BuildContext context, MediaVideoTrack track) =>
      const SizedBox.shrink();
}
