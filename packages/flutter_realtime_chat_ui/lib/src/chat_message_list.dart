import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'chat_ui_scope.dart';
import 'chat_components_chat_avatar.dart';

class ChatMessageList extends StatelessWidget {
  const ChatMessageList({super.key, this.onMessageTap});
  final ValueChanged<ChatMessage>? onMessageTap;

  @override
  Widget build(BuildContext context) {
    final controller = ChatUiScope.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final zh = Localizations.localeOf(context).languageCode == 'zh';

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final messages = controller.filteredMessages;
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
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.09,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.forum_outlined,
                        size: 30,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      zh ? '开始一段对话' : 'Your conversation starts here',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      zh
                          ? '发送消息，或者邀请其他人加入聊天室'
                          : 'Send a message or invite someone to join this room',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[messages.length - index - 1];
            final own = message.userId == localId;
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

            // Action popover
            void showActions() {
              unawaited(
                showModalBottomSheet<void>(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (sheetContext) => SafeArea(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E22) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.08),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.35 : 0.08,
                            ),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 10),
                          Center(
                            child: Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.2)
                                    : Colors.black.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ListTile(
                            leading: const Icon(Icons.reply_rounded, size: 20),
                            title: Text(
                              zh ? '回复消息' : 'Reply',
                              style: const TextStyle(fontSize: 14),
                            ),
                            dense: true,
                            onTap: () {
                              Navigator.pop(sheetContext);
                              controller.selectReply(message);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.copy_rounded, size: 20),
                            title: Text(
                              zh ? '复制内容' : 'Copy',
                              style: const TextStyle(fontSize: 14),
                            ),
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
                                  content: Text(
                                    zh ? '已复制消息' : 'Message copied',
                                  ),
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
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.colorScheme.error,
                                ),
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
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.colorScheme.error,
                                ),
                              ),
                              dense: true,
                              onTap: () {
                                Navigator.pop(sheetContext);
                                unawaited(
                                  controller.removeMember(message.userId),
                                );
                              },
                            ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            final bubbleBgColor = own
                ? theme.colorScheme.primary
                : (isDark ? const Color(0xFF262629) : const Color(0xFFF5F5F7));
            final bubbleTextColor = own
                ? Colors.white
                : (isDark ? Colors.white : const Color(0xFF1D1D1F));
            final timeStr =
                '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}';

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: own
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!own) ...[
                    ChatComponentsChatAvatar(
                      name: senderName,
                      avatarUrl: message.avatarUrl,
                      size: 30,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Column(
                      crossAxisAlignment: own
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        if (!own)
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 2),
                            child: Text(
                              senderName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: onMessageTap == null
                              ? () => controller.selectReply(message)
                              : () => onMessageTap!(message),
                          onLongPress: showActions,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 420),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              gradient: own
                                  ? LinearGradient(
                                      colors: [
                                        theme.colorScheme.primary,
                                        theme.colorScheme.primary.withValues(
                                          alpha: 0.88,
                                        ),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: own ? null : bubbleBgColor,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18),
                                topRight: const Radius.circular(18),
                                bottomLeft: Radius.circular(own ? 18 : 4),
                                bottomRight: Radius.circular(own ? 4 : 18),
                              ),
                              border: Border.all(
                                color: own
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : (isDark
                                          ? Colors.white.withValues(alpha: 0.08)
                                          : Colors.black.withValues(
                                              alpha: 0.05,
                                            )),
                                width: 0.8,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: isDark ? 0.25 : 0.04,
                                  ),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: own
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message.message,
                                  style: TextStyle(
                                    color: bubbleTextColor,
                                    fontSize: 14,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w400,
                                    color: own
                                        ? Colors.white.withValues(alpha: 0.72)
                                        : theme.colorScheme.onSurfaceVariant
                                              .withValues(alpha: 0.65),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (own) ...[
                    const SizedBox(width: 8),
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
