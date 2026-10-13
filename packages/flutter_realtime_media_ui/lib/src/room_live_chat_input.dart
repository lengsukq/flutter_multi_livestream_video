import 'package:flutter/material.dart';
import 'realtime_strings.dart';
import 'realtime_style.dart';
import 'realtime_ui_style.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'room_chat_presentation_controller.dart';

/// In-place live chat input directly embedded into the bottom dock.
///
/// Avoids evoking a redundant second input box or floating popup.
/// Users type and send directly inside this bottom capsule slot.
class RoomLiveChatInput extends StatefulWidget {
  const RoomLiveChatInput({
    required this.controller,
    required this.onOpen,
    required this.onClose,
    this.chat,
    required this.inputOpen,
  });

  final RoomChatPresentationController controller;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final ChatSession? chat;
  final bool inputOpen;

  @override
  State<RoomLiveChatInput> createState() => RoomLiveChatInputState();
}

class RoomLiveChatInputState extends State<RoomLiveChatInput> {
  TextEditingController get _controller => widget.controller.message;
  late final FocusNode _focusNode = FocusNode();
  bool get _sending => widget.controller.sending;

  @override
  void initState() {
    super.initState();
    if (widget.inputOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(covariant RoomLiveChatInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.inputOpen && !oldWidget.inputOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    } else if (!widget.inputOpen && oldWidget.inputOpen) {
      _focusNode.unfocus();
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (widget.chat case final chat?) await widget.controller.send(chat);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => _buildInput(context),
  );
  Widget _buildInput(BuildContext context) {
    final strings = RealtimeStrings.of(context);
    final style = RealtimeStyle.of(context);
    final isDark = style.isDark;

    if (!widget.inputOpen) {
      // Inactive capsule in the dock
      return InkWell(
        onTap: widget.onOpen,
        borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.52)
                : style.surface.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.20)
                  : style.border,
              width: 1,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 16,
                color: isDark ? Colors.white70 : style.textMuted,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  strings.sendComment,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : style.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Active in-place text input in the dock: NO SECOND INPUT BOX!
    return InkWell(
      onTap: widget.onClose,
      borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
      child: Container(
        height: 40,
        padding: const EdgeInsets.fromLTRB(10, 0, 4, 0),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.black.withValues(alpha: 0.76)
              : style.surface.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
          border: Border.all(
            color: isDark
                ? style.primary.withValues(alpha: 0.8)
                : style.primaryBorder,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: style.primary.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.chat_bubble_rounded, size: 16, color: style.primary),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: TextStyle(
                  color: isDark ? Colors.white : style.text,
                  fontSize: 13.5,
                ),
                decoration: InputDecoration(
                  hintText: strings.sendComment,
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white60 : style.textMuted,
                    fontSize: 13,
                  ),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 4),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) {
                final hasText = value.text.trim().isNotEmpty;
                return SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    tooltip: strings.sendComment,
                    padding: EdgeInsets.zero,
                    onPressed: (_sending || !hasText) ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            Icons.send_rounded,
                            size: 16,
                            color: hasText
                                ? Colors.white
                                : (isDark ? Colors.white38 : style.textMuted),
                          ),
                    style: IconButton.styleFrom(
                      backgroundColor: hasText
                          ? style.primary
                          : (isDark ? Colors.white10 : style.surfaceSubtle),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                );
              },
            ),
            IconButton(
              tooltip: strings.closeCommentInput,
              icon: Icon(
                Icons.close_rounded,
                color: isDark ? Colors.white70 : style.textMuted,
                size: 17,
              ),
              onPressed: widget.onClose,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}
