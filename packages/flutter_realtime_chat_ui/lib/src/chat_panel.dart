import 'package:flutter/material.dart';
import 'package:flutter_realtime_design_ui/flutter_realtime_design_ui.dart';

import 'chat_message_list.dart';
import 'chat_composer.dart';

class ChatPanel extends StatelessWidget {
  const ChatPanel({super.key, this.recipientLabel, this.timelineStyle = false});

  /// Optional audience line above the composer ("To Everyone"). Standalone
  /// chat pages omit it; room panels pass the active recipient.
  final String? recipientLabel;

  /// Show everyone in the same avatar-led feed, including the local user.
  /// Useful for a meeting sidebar rather than a direct-message conversation.
  final bool timelineStyle;

  @override
  Widget build(BuildContext context) {
    final label = recipientLabel;
    return Column(
      children: [
        Expanded(child: ChatMessageList(timelineStyle: timelineStyle)),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (label != null)
                Padding(
                  padding: const EdgeInsets.only(left: 2, bottom: 6),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: RealtimeStyle.of(context).textMuted,
                    ),
                  ),
                ),
              const ChatComposer(),
            ],
          ),
        ),
      ],
    );
  }
}
