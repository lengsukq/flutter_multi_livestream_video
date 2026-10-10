import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_example/demo_composable_chat_page.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
        MaterialApp(
          home: DemoComposableChatPage(
            chatRoom: chatRoom,
            title: 'Product chat',
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(ChatUiScope), findsOneWidget);
      expect(find.byType(ChatSearchField), findsOneWidget);
      expect(find.byType(ChatMessageList), findsOneWidget);
      expect(find.byType(ChatComposer), findsOneWidget);
      expect(find.text('Product chat'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });
}

class _ChatSessionStub extends Fake implements ChatSession {
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
