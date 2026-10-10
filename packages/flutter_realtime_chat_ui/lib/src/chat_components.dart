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
    return ListenableBuilder(
      listenable: controller,
      builder: (_, _) => Chip(
        avatar: Icon(
          controller.state.isConnected ? Icons.circle : Icons.circle_outlined,
          color: controller.state.isConnected ? Colors.green : Colors.orange,
          size: 12,
        ),
        label: Text(controller.state.name),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class ChatSearchField extends StatelessWidget {
  const ChatSearchField({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = ChatUiScope.of(context);
    return TextField(
      onChanged: controller.setSearch,
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: const Icon(Icons.search),
        hintText: Localizations.localeOf(context).languageCode == 'zh'
            ? '搜索消息'
            : 'Search messages',
        border: const OutlineInputBorder(),
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
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final messages = controller.filteredMessages;
        final localId = controller.session is ChatSessionIdentity
            ? (controller.session as ChatSessionIdentity).localUserId
            : null;
        final capabilities = controller.managementCapabilities;
        return ListView.builder(
          reverse: true,
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
            return ListTile(
              key: ValueKey(message.id),
              dense: true,
              title: Text(
                message.displayName.isNotEmpty
                    ? message.displayName
                    : message.userId,
              ),
              subtitle: Text(message.message),
              onTap: onMessageTap == null
                  ? () => controller.selectReply(message)
                  : () => onMessageTap!(message),
              trailing: PopupMenuButton<String>(
                tooltip: 'Message actions',
                onSelected: (action) async {
                  try {
                    switch (action) {
                      case 'reply':
                        controller.selectReply(message);
                      case 'delete':
                        await controller.deleteMessage(message);
                      case 'remove':
                        await controller.removeMember(message.userId);
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
                  PopupMenuItem(
                    value: 'reply',
                    child: Text(
                      Localizations.localeOf(context).languageCode == 'zh'
                          ? '回复'
                          : 'Reply',
                    ),
                  ),
                  if (canDelete)
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  if (canRemove)
                    const PopupMenuItem(
                      value: 'remove',
                      child: Text('Remove user'),
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
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (controller.replyTo case final reply?)
            ListTile(
              dense: true,
              title: Text(
                '↪ ${reply.displayName.isEmpty ? reply.userId : reply.displayName}',
              ),
              subtitle: Text(
                reply.message,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                tooltip: 'Cancel reply',
                onPressed: () => controller.selectReply(null),
                icon: const Icon(Icons.close),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _text,
                  enabled: controller.canSend,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => unawaited(_send(controller)),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: widget.hintText ?? 'Message',
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Send message',
                onPressed:
                    controller.canSend &&
                        !controller.isPending(ChatUiAction.send)
                    ? () => unawaited(_send(controller))
                    : null,
                icon: controller.isPending(ChatUiAction.send)
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
              ),
            ],
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
    if (!controller.isHost || controller.moderation == null) {
      return const SizedBox.shrink();
    }
    return IconButton(
      tooltip: 'Manage chat',
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
                      const ListTile(title: Text('Chat management')),
                      const Expanded(child: ChatMemberList()),
                      if (controller.managementCapabilities.closeRoom.supported)
                        TextButton.icon(
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Close chat room?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Close'),
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
                          label: const Text('Close room'),
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
                member.role.name,
                if (member.muted) 'muted',
                if (member.banned) 'banned',
              ].join(' · '),
            ),
            trailing: hasActions
                ? PopupMenuButton<String>(
                    tooltip: 'Manage member',
                    onSelected: (action) async {
                      try {
                        switch (action) {
                          case 'remove':
                            final approved = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('Remove member?'),
                                content: Text(
                                  member.displayName.isEmpty
                                      ? member.userId
                                      : member.displayName,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, true),
                                    child: const Text('Remove'),
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
                        const PopupMenuItem(
                          value: 'remove',
                          child: Text('Remove member'),
                        ),
                      if (capabilities.muteMember.supported)
                        PopupMenuItem(
                          value: 'mute',
                          child: Text(member.muted ? 'Unmute' : 'Mute'),
                        ),
                      if (capabilities.banMember.supported)
                        PopupMenuItem(
                          value: 'ban',
                          child: Text(member.banned ? 'Unban' : 'Ban'),
                        ),
                      if (capabilities.manageRoles.supported &&
                          member.role != ChatRole.participant)
                        const PopupMenuItem(
                          value: 'role',
                          child: Text('Make participant'),
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
  Widget build(BuildContext context) => const Column(
    children: [
      Expanded(child: ChatMessageList()),
      Padding(padding: EdgeInsets.all(8), child: ChatComposer()),
    ],
  );
}

class ChatRoomCodeCopy extends StatelessWidget {
  const ChatRoomCodeCopy({super.key, required this.roomCode});
  final String roomCode;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Copy room code',
    icon: const Icon(Icons.copy_outlined),
    onPressed: () {
      unawaited(Clipboard.setData(ClipboardData(text: roomCode)));
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text('Room code copied')));
    },
  );
}
