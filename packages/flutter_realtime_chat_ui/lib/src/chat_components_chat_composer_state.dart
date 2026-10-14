import 'dart:async';
import 'package:flutter/material.dart';
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
    final isDark = theme.brightness == Brightness.dark;
    final zh = Localizations.localeOf(context).languageCode == 'zh';

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // iOS style floating reply quote banner
          if (controller.replyTo case final reply?)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (isDark
                    ? const Color(0xFF2C2C2E)
                    : const Color(0xFFF5F5F7)),
                borderRadius: BorderRadius.circular(12),
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
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Text(
                          reply.message,
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
                  IconButton(
                    iconSize: 18,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 26,
                      minHeight: 26,
                    ),
                    tooltip: zh ? '取消回复' : 'Cancel reply',
                    onPressed: () => controller.selectReply(null),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),

          // iOS style pill input capsule
          Container(
            padding: const EdgeInsets.fromLTRB(14, 2, 6, 2),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.black.withValues(alpha: 0.06),
                width: 0.8,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    enabled: controller.canSend,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => unawaited(_send(controller)),
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      hintText: widget.hintText ?? (zh ? '发消息...' : 'Message'),
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 9,
                        horizontal: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
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
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    foregroundColor: _hasText
                        ? Colors.white
                        : theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.4,
                          ),
                    padding: const EdgeInsets.all(7),
                    minimumSize: const Size(32, 32),
                  ),
                  icon: controller.isPending(ChatUiAction.send)
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.primary,
                          ),
                        )
                      : const Icon(Icons.arrow_upward_rounded, size: 18),
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
