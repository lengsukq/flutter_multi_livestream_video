import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';

import 'demo_strings.dart';

/// Demo owns the layout; the SDK owns ChatSession and composable chat widgets.
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
    final strings = DemoStrings.of(context);
    final theme = Theme.of(context);
    return ChatUiScope(
      session: chatRoom.session,
      moderation: chatRoom.moderation,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: RealtimeAmbientBackground(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 600;
                final padding = compact ? 12.0 : 24.0;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(padding, 12, padding, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          RealtimeGlassSurface(
                            padding: EdgeInsets.symmetric(
                              horizontal: compact ? 10 : 18,
                              vertical: compact ? 10 : 14,
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  tooltip: strings.back,
                                  onPressed: () => Navigator.maybePop(context),
                                  icon: const Icon(Icons.arrow_back_rounded),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    gradient: RealtimeUiTokens.primaryGradient,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: const Icon(
                                    Icons.forum_rounded,
                                    color: Colors.white,
                                    size: 23,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title == 'Chat'
                                            ? (strings.isZh
                                                  ? '独立聊天'
                                                  : 'Standalone Chat')
                                            : title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${strings.roomCode} · ${chatRoom.roomCode}',
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!compact) ...[
                                  const ChatConnectionIndicator(),
                                  const SizedBox(width: 8),
                                ],
                                ChatRoomCodeCopy(roomCode: chatRoom.roomCode),
                                const ChatManagementButton(),
                              ],
                            ),
                          ),
                          SizedBox(height: compact ? 12 : 18),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 19,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    strings.conversation,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ),
                                if (compact) const ChatConnectionIndicator(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          RealtimeGlassSurface(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: const ChatSearchField(),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: RealtimeCard(
                              radius: 24,
                              padding: EdgeInsets.zero,
                              child: const ChatPanel(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
