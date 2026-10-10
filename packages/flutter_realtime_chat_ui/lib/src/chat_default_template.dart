import 'package:flutter/material.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';

import 'chat_components.dart';

/// Optional zero-layout-work chat page built entirely from public widgets.
/// Applications with their own design should compose ChatUiScope directly.
class ChatDefaultPage extends StatelessWidget {
  const ChatDefaultPage({
    super.key,
    required this.session,
    required this.roomCode,
    this.moderation,
    this.title = 'Chat',
    this.onBack,
  });

  final ChatSession session;
  final String roomCode;
  final ChatModeration? moderation;
  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => ChatUiScope(
    session: session,
    moderation: moderation,
    child: Scaffold(
      appBar: AppBar(
        leading: onBack == null
            ? null
            : IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
        title: Text(title),
        actions: [
          ChatRoomCodeCopy(roomCode: roomCode),
          const ChatManagementButton(),
        ],
      ),
      body: const SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(child: ChatSearchField()),
                  ChatConnectionIndicator(),
                ],
              ),
            ),
            Expanded(child: ChatPanel()),
          ],
        ),
      ),
    ),
  );
}
