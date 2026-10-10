import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';

/// Demo owns the Standalone Chat page, while the lightweight chat_ui package
/// owns transport subscription, search/reply/send and member actions.
class DemoComposableChatPage extends StatelessWidget {
  const DemoComposableChatPage({
    super.key,
    required this.chatRoom,
    this.title = 'Chat',
  });

  final RealtimeChatRoom chatRoom;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ChatUiScope(
      session: chatRoom.session,
      moderation: chatRoom.moderation,
      child: Scaffold(
        backgroundColor: RealtimeUiTokens.background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                    children: [
                      // iOS style header bar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 16, 6),
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: 'Back',
                              onPressed: () => Navigator.maybePop(context),
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.forum_rounded,
                                size: 20,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  Text(
                                    chatRoom.roomCode,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (wide) const ChatConnectionIndicator(),
                            const SizedBox(width: 4),
                            ChatRoomCodeCopy(roomCode: chatRoom.roomCode),
                            const ChatManagementButton(),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                        child: Row(
                          children: [
                            const Expanded(child: ChatSearchField()),
                            if (!wide) ...[
                              const SizedBox(width: 8),
                              const ChatConnectionIndicator(),
                            ],
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: RealtimeCard(
                            radius: 20,
                            padding: const EdgeInsets.only(bottom: 6),
                            child: const ChatPanel(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
