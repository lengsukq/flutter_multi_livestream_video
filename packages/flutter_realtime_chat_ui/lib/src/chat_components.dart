import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';

import 'chat_ui_controller.dart';

/// One state subscription owner for independently positioned chat widgets.
class ChatUiScope extends StatefulWidget {
  const ChatUiScope({
    super.key,
    required this.session,
    required this.child,
    this.moderation,
    this.controller,
  });

  final ChatSession session;
  final ChatModeration? moderation;
  final ChatUiController? controller;
  final Widget child;

  static ChatUiController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_ChatUiInherited>();
    assert(scope != null, 'ChatUiScope must be an ancestor');
    return scope!.controller;
  }

  @override
  State<ChatUiScope> createState() => _ChatUiScopeState();
}

class _ChatUiScopeState extends State<ChatUiScope> {
  late ChatUiController _controller;
  late bool _owns;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() {
    _owns = widget.controller == null;
    _controller =
        widget.controller ??
        ChatUiController(widget.session, moderation: widget.moderation);
    assert(identical(_controller.session, widget.session));
  }

  @override
  void didUpdateWidget(covariant ChatUiScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.session, widget.session) ||
        !identical(oldWidget.moderation, widget.moderation) ||
        !identical(oldWidget.controller, widget.controller)) {
      if (_owns) _controller.dispose();
      _bind();
    }
  }

  @override
  void dispose() {
    if (_owns) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _ChatUiInherited(controller: _controller, child: widget.child);
}

class _ChatUiInherited extends InheritedWidget {
  const _ChatUiInherited({required this.controller, required super.child});
  final ChatUiController controller;
  @override
  bool updateShouldNotify(_ChatUiInherited oldWidget) =>
      !identical(controller, oldWidget.controller);
}

class ChatConnectionIndicator extends StatelessWidget {
  const ChatConnectionIndicator({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = ChatUiScope.of(context);
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    return ListenableBuilder(
      listenable: controller,
      builder: (_, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: controller.state.isConnected
              ? const Color(0xFFECFDF5)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.circle,
              size: 9,
              color: controller.state.isConnected
                  ? const Color(0xFF10B981)
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 7),
            Text(
              switch (controller.state.name) {
                'connected' => zh ? '已连接' : 'Connected',
                'connecting' => zh ? '连接中' : 'Connecting',
                'reconnecting' => zh ? '重连中' : 'Reconnecting',
                'disconnected' => zh ? '已断开' : 'Disconnected',
                'failed' => zh ? '连接失败' : 'Failed',
                _ => controller.state.name,
              },
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatSearchField extends StatelessWidget {
  const ChatSearchField({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = ChatUiScope.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final zh = Localizations.localeOf(context).languageCode == 'zh';

    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.04),
          width: 0.8,
        ),
      ),
      child: TextField(
        onChanged: controller.setSearch,
        style: const TextStyle(fontSize: 14),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 19,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          hintText: zh ? '搜索消息' : 'Search messages',
          hintStyle: TextStyle(
            fontSize: 13.5,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}

/// Helper for iOS-style colorful initials avatar
class _ChatAvatar extends StatelessWidget {
  const _ChatAvatar({required this.name, this.size = 30.0});
  final String name;
  final double size;

  static const _palette = [
    [Color(0xFF0EA5E9), Color(0xFF0284C7)],
    [Color(0xFF6366F1), Color(0xFF4F46E5)],
    [Color(0xFF10B981), Color(0xFF059669)],
    [Color(0xFFF59E0B), Color(0xFFD97706)],
    [Color(0xFFEC4899), Color(0xFFDB2777)],
    [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
    [Color(0xFF14B8A6), Color(0xFF0D9488)],
    [Color(0xFFF43F5E), Color(0xFFE11D48)],
  ];

  @override
  Widget build(BuildContext context) {
    final clean = name.trim();
    final initial = clean.isEmpty ? '?' : clean.characters.first.toUpperCase();
    final colorIdx = clean.isEmpty
        ? 0
        : clean.codeUnits.fold(0, (a, b) => a + b) % _palette.length;
    final colors = _palette[colorIdx];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.44,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Messages can be placed in a page, side panel, modal or overlay.
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
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.09),
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
                      margin: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.reply_rounded),
                            title: Text(zh ? '回复消息' : 'Reply'),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              controller.selectReply(message);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.copy_rounded),
                            title: Text(zh ? '复制内容' : 'Copy'),
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
                                ),
                              );
                            },
                          ),
                          if (canDelete)
                            ListTile(
                              leading: Icon(
                                Icons.delete_outline_rounded,
                                color: theme.colorScheme.error,
                              ),
                              title: Text(
                                zh ? '删除消息' : 'Delete',
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                              onTap: () {
                                Navigator.pop(sheetContext);
                                unawaited(controller.deleteMessage(message));
                              },
                            ),
                          if (canRemove)
                            ListTile(
                              leading: Icon(
                                Icons.person_remove_outlined,
                                color: theme.colorScheme.error,
                              ),
                              title: Text(
                                zh ? '移出成员' : 'Remove user',
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                              onTap: () {
                                Navigator.pop(sheetContext);
                                unawaited(
                                  controller.removeMember(message.userId),
                                );
                              },
                            ),
                          const SizedBox(height: 6),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            final bubbleBgColor = own
                ? theme.colorScheme.primary
                : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE9E9EB));
            final bubbleTextColor = own
                ? Colors.white
                : (isDark ? Colors.white : const Color(0xFF0F172A));

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: own
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!own) ...[
                    _ChatAvatar(name: senderName, size: 30),
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
                              color: bubbleBgColor,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18),
                                topRight: const Radius.circular(18),
                                bottomLeft: Radius.circular(own ? 18 : 4),
                                bottomRight: Radius.circular(own ? 4 : 18),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message.message,
                                  style: TextStyle(
                                    color: bubbleTextColor,
                                    fontSize: 14,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
class ChatComposer extends StatefulWidget {
  const ChatComposer({super.key, this.hintText});
  final String? hintText;
  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
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
                    : const Color(0xFFF1F5F9)),
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
            padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.08),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
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
                      border: InputBorder.none,
                      hintText: widget.hintText ?? (zh ? '发消息...' : 'Message'),
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
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
class ChatManagementButton extends StatelessWidget {
  const ChatManagementButton({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = ChatUiScope.of(context);
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    if (!controller.isHost || controller.moderation == null) {
      return const SizedBox.shrink();
    }
    return IconButton(
      tooltip: zh ? '管理聊天室' : 'Manage chat',
      icon: const Icon(Icons.admin_panel_settings_outlined),
      onPressed: () async {
        try {
          await controller.refreshMembers();
          if (!context.mounted) return;
          await showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => ChatUiScope(
              session: controller.session,
              controller: controller,
              moderation: controller.moderation,
              child: SafeArea(
                child: SizedBox(
                  height: 420,
                  child: Column(
                    children: [
                      ListTile(title: Text(zh ? '聊天室管理' : 'Chat management')),
                      const Expanded(child: ChatMemberList()),
                      if (controller.managementCapabilities.closeRoom.supported)
                        TextButton.icon(
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text(zh ? '关闭聊天室？' : 'Close chat room?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: Text(zh ? '取消' : 'Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: Text(zh ? '关闭' : 'Close'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              try {
                                await controller.closeRoom();
                                if (context.mounted) Navigator.pop(context);
                              } catch (error) {
                                if (context.mounted) {
                                  ScaffoldMessenger.maybeOf(
                                    context,
                                  )?.showSnackBar(
                                    SnackBar(content: Text(error.toString())),
                                  );
                                }
                              }
                            }
                          },
                          icon: const Icon(Icons.block),
                          label: Text(zh ? '关闭聊天室' : 'Close room'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        } catch (error) {
          if (context.mounted) {
            ScaffoldMessenger.maybeOf(
              context,
            )?.showSnackBar(SnackBar(content: Text(error.toString())));
          }
        }
      },
    );
  }
}

class ChatMemberList extends StatelessWidget {
  const ChatMemberList({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = ChatUiScope.of(context);
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => ListView.builder(
        itemCount: controller.members.length,
        itemBuilder: (context, index) {
          final member = controller.members[index];
          final capabilities = controller.managementCapabilities;
          final canManage =
              controller.isHost &&
              member.role != ChatRole.host &&
              !(controller.session is ChatSessionIdentity &&
                  (controller.session as ChatSessionIdentity).localUserId ==
                      member.userId);
          final hasActions =
              canManage &&
              (capabilities.removeMember.supported ||
                  capabilities.muteMember.supported ||
                  capabilities.banMember.supported ||
                  capabilities.manageRoles.supported);
          return ListTile(
            title: Text(
              member.displayName.isEmpty ? member.userId : member.displayName,
            ),
            subtitle: Text(
              [
                zh
                    ? switch (member.role) {
                        ChatRole.host => '房主',
                        ChatRole.participant => '参与者',
                        _ => '成员',
                      }
                    : member.role.name,
                if (member.muted) (zh ? '已禁言' : 'muted'),
                if (member.banned) (zh ? '已封禁' : 'banned'),
              ].join(' · '),
            ),
            trailing: hasActions
                ? PopupMenuButton<String>(
                    tooltip: zh ? '管理成员' : 'Manage member',
                    onSelected: (action) async {
                      try {
                        switch (action) {
                          case 'remove':
                            final approved = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: Text(zh ? '移除成员？' : 'Remove member?'),
                                content: Text(
                                  member.displayName.isEmpty
                                      ? member.userId
                                      : member.displayName,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, false),
                                    child: Text(zh ? '取消' : 'Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, true),
                                    child: Text(zh ? '移除' : 'Remove'),
                                  ),
                                ],
                              ),
                            );
                            if (approved == true) {
                              await controller.removeMember(member.userId);
                            }
                          case 'mute':
                            await controller.muteMember(
                              member.userId,
                              muted: !member.muted,
                            );
                          case 'ban':
                            await controller.banMember(
                              member.userId,
                              banned: !member.banned,
                            );
                          case 'role':
                            await controller.changeMemberRole(
                              member.userId,
                              ChatRole.participant,
                            );
                        }
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                            SnackBar(content: Text(error.toString())),
                          );
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      if (capabilities.removeMember.supported)
                        PopupMenuItem(
                          value: 'remove',
                          child: Text(zh ? '移除成员' : 'Remove member'),
                        ),
                      if (capabilities.muteMember.supported)
                        PopupMenuItem(
                          value: 'mute',
                          child: Text(
                            member.muted
                                ? (zh ? '解除禁言' : 'Unmute')
                                : (zh ? '禁言' : 'Mute'),
                          ),
                        ),
                      if (capabilities.banMember.supported)
                        PopupMenuItem(
                          value: 'ban',
                          child: Text(
                            member.banned
                                ? (zh ? '解除封禁' : 'Unban')
                                : (zh ? '封禁' : 'Ban'),
                          ),
                        ),
                      if (capabilities.manageRoles.supported &&
                          member.role != ChatRole.participant)
                        PopupMenuItem(
                          value: 'role',
                          child: Text(zh ? '设为参与者' : 'Make participant'),
                        ),
                    ],
                  )
                : null,
          );
        },
      ),
    );
  }
}

/// Default grouping for applications needing a quick chat pane.
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

class ChatRoomCodeCopy extends StatelessWidget {
  const ChatRoomCodeCopy({super.key, required this.roomCode});
  final String roomCode;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: Localizations.localeOf(context).languageCode == 'zh'
        ? '复制房间码'
        : 'Copy room code',
    icon: const Icon(Icons.copy_outlined),
    onPressed: () {
      unawaited(Clipboard.setData(ClipboardData(text: roomCode)));
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            Localizations.localeOf(context).languageCode == 'zh'
                ? '房间码已复制'
                : 'Room code copied',
          ),
        ),
      );
    },
  );
}
