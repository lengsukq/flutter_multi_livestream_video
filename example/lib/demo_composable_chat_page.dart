import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';

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
  Widget build(BuildContext context) => ChatUiScope(
    session: chatRoom.session,
    moderation: chatRoom.moderation,
    child: Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1300),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Back',
                            onPressed: () => Navigator.maybePop(context),
                            icon: const Icon(Icons.arrow_back),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.forum_outlined),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                Text(
                                  chatRoom.roomCode,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (wide) const ChatConnectionIndicator(),
                          ChatRoomCodeCopy(roomCode: chatRoom.roomCode),
                          const ChatManagementButton(),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          const Expanded(child: ChatSearchField()),
                          if (!wide) const ChatConnectionIndicator(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: ChatPanel(),
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
