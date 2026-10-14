import 'package:flutter/material.dart';
import 'room_ui_controller.dart';
import 'package:flutter_realtime_design_ui/flutter_realtime_design_ui.dart';

class RealtimeLiveChatFeed extends StatelessWidget {
  const RealtimeLiveChatFeed({
    super.key,
    this.maxMessages = 5,
    this.onVideo = true,
  });

  final int maxMessages;
  final bool onVideo;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    if (controller.room.chat == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final messages = controller.messages;
        final count = messages.length < maxMessages
            ? messages.length
            : maxMessages;
        return SingleChildScrollView(
          reverse: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (
                var index = messages.length - count;
                index < messages.length;
                index++
              )
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: onVideo
                          ? Colors.black.withValues(alpha: 0.70)
                          : const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RealtimeAvatar(
                            name: messages[index].displayName.isEmpty
                                ? messages[index].userId
                                : messages[index].displayName,
                            avatarUrl: messages[index].avatarUrl,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${messages[index].displayName.isEmpty ? messages[index].userId : messages[index].displayName}: ${messages[index].message}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: onVideo
                                    ? Colors.white
                                    : const Color(0xFF1D1D1F),
                                fontSize: 15,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Live gift control usable in a toolbar, side panel or floating overlay.
/// The provider-neutral SDK session retains gift retry/idempotency semantics.
