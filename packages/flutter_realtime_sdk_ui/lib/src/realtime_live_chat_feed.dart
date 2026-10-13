import 'package:flutter/material.dart';
import 'room_ui_controller.dart';

class RealtimeLiveChatFeed extends StatelessWidget {
  const RealtimeLiveChatFeed({super.key, this.maxMessages = 5});

  final int maxMessages;

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
        return Column(
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
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      '${messages[index].displayName.isEmpty ? messages[index].userId : messages[index].displayName}: ${messages[index].message}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Live gift control usable in a toolbar, side panel or floating overlay.
/// The provider-neutral SDK session retains gift retry/idempotency semantics.
