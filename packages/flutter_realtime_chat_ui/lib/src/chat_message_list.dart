import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_design_ui/flutter_realtime_design_ui.dart';
import 'chat_ui_scope.dart';
import 'chat_components_chat_avatar.dart';

/// Flat, avatar-led message stream.
///
/// Messages read like the reference room chat: avatar, name, time, optional
/// role tag and body text. The local user's messages align end and use a subtle
/// surface instead of a saturated bubble, so the stream stays calm.
class ChatMessageList extends StatefulWidget {
  const ChatMessageList({
    super.key,
    this.onMessageTap,
    this.timelineStyle = false,
  });
  final ValueChanged<ChatMessage>? onMessageTap;
  final bool timelineStyle;

  @override
  State<ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends State<ChatMessageList> {
  final _timelineScroll = ScrollController();
  int? _previousLength;

  @override
  void dispose() {
    _timelineScroll.dispose();
    super.dispose();
  }

  void _followNewMessages(int count) {
    if (!widget.timelineStyle || _previousLength == count) return;
    final follow =
        _previousLength == null ||
        !_timelineScroll.hasClients ||
        _timelineScroll.position.extentAfter < 80;
    _previousLength = count;
    if (follow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_timelineScroll.hasClients) return;
        unawaited(
          _timelineScroll.animateTo(
            _timelineScroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ChatUiScope.of(context);
    final theme = Theme.of(context);
    final zh = Localizations.localeOf(context).languageCode == 'zh';

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final messages = controller.filteredMessages;
        _followNewMessages(messages.length);
        final localId = controller.session is ChatSessionIdentity
            ? (controller.session as ChatSessionIdentity).localUserId
            : null;
        final capabilities = controller.managementCapabilities;

        if (messages.isEmpty) {
          return Center(
            // The same component is used in narrow meeting side-panels.
            // Scrolling the empty state avoids a RenderFlex overflow when
            // the available height is smaller than the illustration.
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.forum_outlined,
                        size: 26,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      zh ? '开始一段对话' : 'Your conversation starts here',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      zh
                          ? '发送消息，或者邀请其他人加入聊天室'
                          : 'Send a message or invite someone to join this room',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return ListView.builder(
          // A classroom timeline begins at the top with successive messages
          // below it; the regular chat layout still follows the newest first.
          reverse: !widget.timelineStyle,
          controller: widget.timelineStyle ? _timelineScroll : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message =
                messages[widget.timelineStyle
                    ? index
                    : messages.length - index - 1];
            final own = message.userId == localId;
            final rightAligned = own && !widget.timelineStyle;
            final canDelete =
                (own || controller.isHost) &&
                (capabilities.deleteMessage.supported ||
                    capabilities.recallMessage.supported);
            final canRemove =
                controller.isHost &&
                !own &&
                capabilities.removeMember.supported;

            final senderName = message.displayName.isNotEmpty
                ? message.displayName
                : message.userId;

            void showActions() {
              unawaited(
                showRealtimeGlassBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (sheetContext) => SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.reply_rounded, size: 20),
                          title: Text(zh ? '回复消息' : 'Reply'),
                          dense: true,
                          onTap: () {
                            Navigator.pop(sheetContext);
                            controller.selectReply(message);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.copy_rounded, size: 20),
                          title: Text(zh ? '复制内容' : 'Copy'),
                          dense: true,
                          onTap: () {
                            Navigator.pop(sheetContext);
                            unawaited(
                              Clipboard.setData(
                                ClipboardData(text: message.message),
                              ),
                            );
                            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                              SnackBar(
                                content: Text(zh ? '已复制消息' : 'Message copied'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                        if (canDelete)
                          ListTile(
                            leading: Icon(
                              Icons.delete_outline_rounded,
                              size: 20,
                              color: theme.colorScheme.error,
                            ),
                            title: Text(
                              zh ? '删除消息' : 'Delete',
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                            dense: true,
                            onTap: () {
                              Navigator.pop(sheetContext);
                              unawaited(controller.deleteMessage(message));
                            },
                          ),
                        if (canRemove)
                          ListTile(
                            leading: Icon(
                              Icons.person_remove_outlined,
                              size: 20,
                              color: theme.colorScheme.error,
                            ),
                            title: Text(
                              zh ? '移出成员' : 'Remove user',
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                            dense: true,
                            onTap: () {
                              Navigator.pop(sheetContext);
                              unawaited(
                                controller.removeMember(message.userId),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final timeStr =
                '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}';

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                mainAxisAlignment: rightAligned
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!rightAligned) ...[
                    ChatComponentsChatAvatar(
                      name: senderName,
                      avatarUrl: message.avatarUrl,
                      size: 30,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Column(
                      crossAxisAlignment: rightAligned
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (rightAligned) ...[
                              Text(
                                zh ? '你' : 'You',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ] else ...[
                              Flexible(
                                child: Text(
                                  own && widget.timelineStyle
                                      ? (zh ? '你' : 'You')
                                      : senderName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(timeStr, style: theme.textTheme.labelSmall),
                          ],
                        ),
                        const SizedBox(height: 3),
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: widget.onMessageTap == null
                              ? () => controller.selectReply(message)
                              : () => widget.onMessageTap!(message),
                          onLongPress: showActions,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 460),
                            padding: rightAligned
                                ? const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  )
                                : const EdgeInsets.only(top: 2, bottom: 6),
                            decoration: BoxDecoration(
                              color: rightAligned
                                  ? theme.colorScheme.surfaceContainer
                                  : theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              message.message,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (rightAligned) ...[
                    const SizedBox(width: 10),
                    ChatComponentsChatAvatar(
                      name: senderName,
                      avatarUrl: message.avatarUrl,
                      size: 30,
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Input, reply banner and send action share the ChatUiController.
