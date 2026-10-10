import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_chat_ui/flutter_realtime_chat_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('empty chat fits a short embedded meeting panel', (tester) async {
    final session = _FakeChatSession();
    addTearDown(session.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ChatUiScope(
          session: session,
          child: const Scaffold(
            body: Center(
              child: SizedBox(width: 300, height: 75, child: ChatMessageList()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(ChatMessageList), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'empty chat and connection state follow the host Chinese locale',
    (tester) async {
      final session = _FakeChatSession();
      addTearDown(session.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          supportedLocales: const [Locale('zh'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: ChatUiScope(
            session: session,
            child: const Scaffold(
              body: Column(
                children: [
                  ChatConnectionIndicator(),
                  Expanded(child: ChatMessageList()),
                  ChatComposer(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('开始一段对话'), findsOneWidget);
      expect(find.text('已连接'), findsOneWidget);
      expect(find.byTooltip('发送消息'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('search, reply, send and UI disposal share one ChatSession', () async {
    final session = _FakeChatSession();
    final controller = ChatUiController(session);
    expect(session.messageSubscriptions, 1);
    expect(session.stateSubscriptions, 1);
    session.add('hello world', id: 'one');
    session.add('second message', id: 'two');
    await Future<void>.delayed(Duration.zero);
    controller.setSearch('world');
    expect(controller.filteredMessages.map((m) => m.id), ['one']);
    controller.setSearch('');
    controller.selectReply(session.messages.first);
    await controller.send('thanks');
    expect(session.sent.single, contains('Reply to User'));
    expect(session.sent.single, contains('thanks'));
    expect(controller.replyTo, isNull);
    controller.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(session.messageSubscriptions, 0);
    expect(session.stateSubscriptions, 0);
    expect(
      session.disposed,
      isFalse,
      reason: 'unmounting UI must not disconnect ChatSession',
    );
    await session.dispose();
  });

  testWidgets('chat widgets recompose on phone and desktop without overflow', (
    tester,
  ) async {
    final session = _FakeChatSession();
    session.add('hello', id: 'initial');
    addTearDown(session.dispose);
    for (final width in [390.0, 768.0, 1280.0]) {
      await tester.binding.setSurfaceSize(Size(width, 850));
      await tester.pumpWidget(
        MaterialApp(
          home: ChatUiScope(
            session: session,
            child: const Scaffold(
              body: Column(
                children: [
                  ChatConnectionIndicator(),
                  ChatSearchField(),
                  Expanded(child: ChatMessageList()),
                  ChatComposer(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('hello'), findsOneWidget);
      expect(find.byType(ChatComposer), findsOneWidget);
      expect(session.messageSubscriptions, 1);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.binding.setSurfaceSize(null);
    await tester.pump();
    expect(session.messageSubscriptions, 0);
  });

  testWidgets('reply and message send share the controller', (tester) async {
    final session = _FakeChatSession();
    session.add('a quote', id: 'message');
    addTearDown(session.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ChatUiScope(
          session: session,
          child: const Scaffold(
            body: Column(
              children: [
                Expanded(child: ChatMessageList()),
                ChatComposer(),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('a quote'));
    await tester.pump();
    expect(find.textContaining('↪ User'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'reply text');
    await tester.pump(); // The composer enables Send on the next UI frame.
    await tester.tap(find.byTooltip('Send message'));
    await tester.pump();
    expect(session.sent, hasLength(1));
    expect(session.sent.single, contains('reply text'));
  });

  test(
    'chat host actions use moderation capabilities and refresh members',
    () async {
      final session = _FakeHostSession();
      final moderation = _FakeModeration();
      final controller = ChatUiController(session, moderation: moderation);
      addTearDown(() async {
        controller.dispose();
        await session.dispose();
      });
      await controller.refreshMembers();
      expect(controller.members.single.userId, 'student');
      await controller.muteMember('student', muted: true);
      await controller.banMember('student', banned: true);
      await controller.changeMemberRole('student', ChatRole.viewer);
      await controller.deleteMessage(
        ChatMessage(
          id: 'message-1',
          userId: 'student',
          message: 'hello',
          timestamp: DateTime(2026),
        ),
      );
      await controller.closeRoom();
      expect(moderation.actions, [
        'mute:student:true',
        'ban:student:true',
        'role:student:viewer',
        'delete:message-1',
        'close',
      ]);
      await controller.removeMember('student');
      expect(moderation.actions.last, 'remove:student');
      await controller.removeMember('teacher');
      expect(
        moderation.actions.last,
        'remove:student',
        reason: 'UI must never request removing the current host',
      );
    },
  );

  testWidgets('default chat template is composed from public widgets', (
    tester,
  ) async {
    final session = _FakeChatSession();
    addTearDown(session.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ChatDefaultPage(session: session, roomCode: 'room-1'),
      ),
    );
    expect(find.byType(ChatUiScope), findsOneWidget);
    expect(find.byType(ChatMessageList), findsOneWidget);
    expect(find.byType(ChatComposer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeHostSession extends _FakeChatSession implements ChatSessionIdentity {
  @override
  ChatRole get role => ChatRole.host;
  @override
  String get localParticipantId => 'teacher';
  @override
  String get localUserId => 'teacher';
  @override
  String get localDisplayName => 'Teacher';
}

class _FakeModeration extends Fake
    implements
        ChatModeration,
        ChatModerationCapabilitySource,
        ChatMessageDeleteAction {
  final actions = <String>[];
  @override
  ChatManagementCapabilities get moderationCapabilities =>
      const ChatManagementCapabilities(
        listMembers: ChatManagementCapability.client(),
        removeMember: ChatManagementCapability.client(),
        muteMember: ChatManagementCapability.client(),
        banMember: ChatManagementCapability.client(),
        manageRoles: ChatManagementCapability.client(),
        deleteMessage: ChatManagementCapability.client(),
        closeRoom: ChatManagementCapability.client(),
      );
  @override
  Future<List<ChatMember>> listMembers() async => const [
    ChatMember(userId: 'student', displayName: 'Student'),
  ];
  @override
  Future<void> removeMember(String userId) async =>
      actions.add('remove:$userId');
  @override
  Future<void> muteMember(String userId, {required bool muted}) async =>
      actions.add('mute:$userId:$muted');
  @override
  Future<void> banMember(String userId, {required bool banned}) async =>
      actions.add('ban:$userId:$banned');
  @override
  Future<void> changeMemberRole(String userId, ChatRole role) async =>
      actions.add('role:$userId:${role.name}');
  @override
  Future<void> deleteMessage(String messageId) async =>
      actions.add('delete:$messageId');
  @override
  Future<void> closeRoom() async => actions.add('close');
}

class _FakeChatSession extends Fake implements ChatSession {
  final _messages = <ChatMessage>[];
  final _messageController = StreamController<List<ChatMessage>>.broadcast(
    onListen: () {},
  );
  final _states = StreamController<ChatConnectionState>.broadcast();
  final sent = <String>[];
  bool disposed = false;
  int messageSubscriptions = 0;
  int stateSubscriptions = 0;

  _FakeChatSession();

  @override
  String get providerId => 'fake';
  @override
  ChatRole get role => ChatRole.participant;
  @override
  ChatCapabilities get capabilities =>
      const ChatCapabilities(canSendMessage: true);
  @override
  ChatConnectionState get state => ChatConnectionState.connected;
  @override
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  @override
  Stream<List<ChatMessage>> get messageSnapshots => Stream.multi((controller) {
    messageSubscriptions++;
    final subscription = _messageController.stream.listen(controller.add);
    controller.onCancel = () async {
      messageSubscriptions--;
      await subscription.cancel();
    };
  }, isBroadcast: true);
  @override
  Stream<ChatConnectionState> get states => Stream.multi((controller) {
    stateSubscriptions++;
    final subscription = _states.stream.listen(controller.add);
    controller.onCancel = () async {
      stateSubscriptions--;
      await subscription.cancel();
    };
  }, isBroadcast: true);
  @override
  Stream<ChatEvent> get events => const Stream.empty();

  void add(String content, {required String id}) {
    _messages.add(
      ChatMessage(
        id: id,
        userId: 'u',
        displayName: 'User',
        message: content,
        timestamp: DateTime(2026),
      ),
    );
    _messageController.add(List.unmodifiable(_messages));
  }

  @override
  Future<void> sendMessage(String message) async => sent.add(message);
  @override
  Future<void> dispose() async {
    disposed = true;
    await _states.close();
    await _messageController.close();
  }
}
