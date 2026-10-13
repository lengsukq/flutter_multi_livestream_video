import 'package:flutter/material.dart';
import 'chat_message_list.dart';
import 'chat_composer.dart';

class ChatPanel extends StatelessWidget {
  const ChatPanel({super.key});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Expanded(child: ChatMessageList()),
      Container(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: const ChatComposer(),
      ),
    ],
  );
}
