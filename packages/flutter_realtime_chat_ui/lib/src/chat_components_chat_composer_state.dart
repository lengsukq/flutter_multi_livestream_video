import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_design_ui/flutter_realtime_design_ui.dart';
import 'chat_ui_controller.dart';
import 'chat_ui_scope.dart';
import 'chat_composer.dart';

class ChatComponentsChatComposerState extends State<ChatComposer> {
  final _text = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(() {
      final has = _text.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send(ChatUiController controller) async {
    final message = _text.text;
    if (message.trim().isEmpty || !controller.canSend) return;
    try {
      await controller.send(message);
      if (mounted) _text.clear();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ChatUiScope.of(context);
    final theme = Theme.of(context);
    final zh = Localizations.localeOf(context).languageCode == 'zh';

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (controller.replyTo case final reply?)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(10),
                border: Border(
                  left: BorderSide(color: theme.colorScheme.primary, width: 3),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '↪ ${reply.displayName.isEmpty ? reply.userId : reply.displayName}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          reply.message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    iconSize: 18,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    tooltip: zh ? '取消回复' : 'Cancel reply',
                    onPressed: () => controller.selectReply(null),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),

          // Boxed composer matching the reference: input line plus a quiet
          // action row with a dark circular send button.
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(
                RealtimeUiThemeExtension.of(context).controlRadius,
              ),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _text,
                        enabled: controller.canSend,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => unawaited(_send(controller)),
                        style: theme.textTheme.bodyMedium,
                        decoration: InputDecoration(
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          hintText:
                              widget.hintText ?? (zh ? '发消息…' : 'Message'),
                          hintStyle: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.7),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: zh ? '发送消息' : 'Send message',
                      onPressed:
                          controller.canSend &&
                              _hasText &&
                              !controller.isPending(ChatUiAction.send)
                          ? () => unawaited(_send(controller))
                          : null,
                      style: IconButton.styleFrom(
                        backgroundColor: _hasText
                            ? theme.colorScheme.onSurface
                            : Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        foregroundColor: _hasText
                            ? theme.colorScheme.surface
                            : theme.colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.45,
                              ),
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(44, 44),
                        maximumSize: const Size(44, 44),
                        shape: const CircleBorder(),
                      ),
                      icon: controller.isPending(ChatUiAction.send)
                          ? SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.surface,
                              ),
                            )
                          : const Icon(Icons.arrow_upward_rounded, size: 17),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Provider-neutral member list, host actions and close-room affordance.
