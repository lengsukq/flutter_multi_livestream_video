import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText() == 'Alice: hello',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.data_object_rounded));
    await tester.pump();
    expect(find.text('RTC Data'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await chat.dispose();
    await fixture.dispose();
  });
}

class _RoomFixture {
  _RoomFixture()
    : media = _FakeMediaSession(),
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
      backend: backend,
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

class _FakeMediaSession implements MediaSession, MediaDataMessenger {
  final StreamController<MediaSessionState> _states =
      StreamController<MediaSessionState>.broadcast();
  final StreamController<MediaSnapshot> _snapshots =
      StreamController<MediaSnapshot>.broadcast();
  final StreamController<MediaEvent> _events =
      StreamController<MediaEvent>.broadcast();

  @override
  String get providerId => 'fake';

  @override
  MediaRole get role => MediaRole.participant;

  @override
  MediaCapabilities get capabilities =>
      const MediaCapabilities(canSendData: true, canReceiveData: true);

  @override
  MediaSessionState get state => MediaSessionState.connected;

  @override
  MediaSnapshot get snapshot =>
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

class _FakeChatSession implements ChatSession {
  _FakeChatSession({List<ChatMessage> messages = const []})
    : _messages = List<ChatMessage>.of(messages);

  final List<ChatMessage> _messages;
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
  ChatRole get role => ChatRole.participant;

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
