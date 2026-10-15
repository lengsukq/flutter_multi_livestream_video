import 'support/design_capture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeDesignCapture);
  testWidgets('standalone Chat Demo composes SDK widgets at any width', (
    tester,
  ) async {
    final session = _ChatSessionStub();
    final chatRoom = RealtimeChatRoom(
      room: ChatRoomSession(
        roomCode: 'room-42',
        participantId: 'p1',
        userId: 'student',
        role: ChatRole.participant,
        session: session,
      ),
      disposeClient: () {},
    );
    addTearDown(chatRoom.dispose);

    for (final width in [390.0, 768.0, 1280.0, 1440.0]) {
      await tester.binding.setSurfaceSize(Size(width, 850));
      await tester.pumpWidget(
        designCaptureApp(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: designTestTheme(),
            home: RealtimeChatPage(chatRoom: chatRoom, title: 'Product chat'),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(ChatUiScope), findsOneWidget);
      expect(find.byType(ChatSearchField), findsOneWidget);
      expect(find.byType(ChatMessageList), findsOneWidget);
      expect(find.byType(ChatComposer), findsOneWidget);
      expect(find.text('Product chat'), findsOneWidget);
      expect(find.textContaining('Chat member'), findsOneWidget);
      expect(find.byTooltip('Manage chat'), findsNothing);
      expect(tester.takeException(), isNull);
      if ([390.0, 1440.0].contains(width)) {
        await captureDesign(tester, 'chat-room-${width.toInt()}');
      }
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('chat creator and guest have different role UI', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final role in [ChatRole.host, ChatRole.participant]) {
      final chatRoom = RealtimeChatRoom(
        room: ChatRoomSession(
          roomCode: 'shared-room',
          participantId: 'p1',
          userId: role == ChatRole.host ? 'owner' : 'guest',
          role: role,
          session: _ChatSessionStub(role: role),
        ),
        disposeClient: () {},
      );
      addTearDown(chatRoom.dispose);
      await tester.pumpWidget(
        MaterialApp(home: RealtimeChatPage(chatRoom: chatRoom)),
      );
      await tester.pump();
      expect(
        find.textContaining(
          role == ChatRole.host ? 'Chat host' : 'Chat member',
        ),
        findsOneWidget,
      );
      expect(
        find.byTooltip('Manage chat'),
        role == ChatRole.host ? findsOneWidget : findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}

class _ChatSessionStub extends Fake implements ChatSession {
  _ChatSessionStub({this.role = ChatRole.participant});
  @override
  String get providerId => 'fake';
  @override
  final ChatRole role;
  @override
  ChatCapabilities get capabilities =>
      const ChatCapabilities(canSendMessage: true);
  @override
  ChatConnectionState get state => ChatConnectionState.connected;
  @override
  List<ChatMessage> get messages => const [];
  @override
  Stream<List<ChatMessage>> get messageSnapshots => const Stream.empty();
  @override
  Stream<ChatConnectionState> get states => const Stream.empty();
  @override
  Stream<ChatEvent> get events => const Stream.empty();
  @override
  Future<void> sendMessage(String message) async {}
  @override
  Future<void> dispose() async {}
}
