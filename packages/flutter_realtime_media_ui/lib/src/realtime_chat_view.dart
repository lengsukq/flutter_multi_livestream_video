import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';

import 'realtime_ui_style.dart';

/// Reusable chat surface for standalone and media-attached chat.
class RealtimeChatView extends StatefulWidget {
  const RealtimeChatView({
    super.key,
    required this.session,
    this.roomCode,
    this.title = 'Chat',
    this.showAppBar = false,
    this.moderation,
  });
  final ChatSession session;
  final String? roomCode;
  final String title;
  final bool showAppBar;
  final ChatModeration? moderation;
  @override
  State<RealtimeChatView> createState() => _RealtimeChatViewState();
}

class _RealtimeChatViewState extends State<RealtimeChatView> {
  final _message = TextEditingController();
  bool _sending = false;
  String? _error;
  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = StreamBuilder<ChatConnectionState>(
      stream: widget.session.states,
      initialData: widget.session.state,
      builder: (context, stateSnapshot) => StreamBuilder<List<ChatMessage>>(
        stream: widget.session.messageSnapshots,
        initialData: widget.session.messages,
        builder: (context, messagesSnapshot) {
          final state = stateSnapshot.data ?? widget.session.state;
          final messages = messagesSnapshot.data ?? widget.session.messages;
          return Column(
            children: [
              RealtimeGlassSurface(
                margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                padding: const EdgeInsets.all(14),
                radius: 20,
                opacity: .88,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              color: RealtimeUiTokens.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            [
                              if (widget.roomCode != null)
                                'Room ${widget.roomCode}',
                              widget.session.providerId,
                              state.name,
                              '${messages.length} messages',
                            ].join(' · '),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: RealtimeUiTokens.textMuted),
                          ),
                        ],
                      ),
                    ),
                    if (widget.moderation != null &&
                        widget.session.role == ChatRole.host)
                      IconButton(
                        tooltip: 'Manage chat',
                        onPressed: _showChatManagement,
                        icon: const Icon(Icons.admin_panel_settings_outlined),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: messages.isEmpty
                    ? const Center(child: Text('No messages yet'))
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(12),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[messages.length - 1 - index];
                          final identity = widget.session is ChatSessionIdentity
                              ? widget.session as ChatSessionIdentity
                              : null;
                          final own = message.userId == identity?.localUserId;
                          final canDelete =
                              widget.session.capabilities.canDeleteMessage;
                          final canRemoveUser =
                              widget.session.capabilities.canDisconnectUser &&
                              !own;
                          return Align(
                            alignment: own
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: GestureDetector(
                              onLongPress: canDelete || canRemoveUser
                                  ? () => _showMessageManagement(
                                      message,
                                      canDelete: canDelete,
                                      canRemoveUser: canRemoveUser,
                                    )
                                  : null,
                              child: Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 520,
                                ),
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: own
                                      ? RealtimeUiTokens.primary
                                      : Colors.white.withValues(alpha: .94),
                                  borderRadius: BorderRadius.circular(
                                    RealtimeUiTokens.controlRadius,
                                  ),
                                  border: own
                                      ? null
                                      : Border.all(
                                          color: RealtimeUiTokens.border,
                                        ),
                                  boxShadow: own
                                      ? const []
                                      : RealtimeUiTokens.cardShadow,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!own)
                                      Text(
                                        message.displayName,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    Text(
                                      message.message,
                                      style: TextStyle(
                                        color: own
                                            ? Colors.white
                                            : RealtimeUiTokens.text,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              _composer(state),
            ],
          );
        },
      ),
    );
    return widget.showAppBar
        ? Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: Text(widget.title),
              backgroundColor: Colors.white.withValues(alpha: .82),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
            ),
            body: RealtimeAmbientBackground(child: body),
          )
        : body;
  }

  Widget _composer(ChatConnectionState state) {
    final enabled =
        state.isConnected &&
        widget.session.capabilities.canSendMessage &&
        !_sending;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
      borderSide: const BorderSide(color: RealtimeUiTokens.border),
    );

    return SafeArea(
      top: false,
      child: RealtimeGlassSurface(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
        radius: 20,
        opacity: .90,
        child: Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _message,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                onSubmitted: enabled ? (_) => unawaited(_send()) : null,
                decoration: InputDecoration(
                  hintText: enabled ? 'Message…' : 'Chat is ${state.name}',
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: .78),
                  border: border,
                  enabledBorder: border,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      RealtimeUiTokens.controlRadius,
                    ),
                    borderSide: const BorderSide(
                      color: RealtimeUiTokens.primary,
                      width: 1.4,
                    ),
                  ),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: enabled ? _send : null,
              style: IconButton.styleFrom(
                backgroundColor: RealtimeUiTokens.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    RealtimeUiTokens.controlRadius,
                  ),
                ),
              ),
              icon: _sending
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.session.sendMessage(text);
      _message.clear();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _showMessageManagement(
    ChatMessage message, {
    required bool canDelete,
    required bool canRemoveUser,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white.withValues(alpha: .96),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const RealtimeSheetHeader(
                title: 'Message actions',
                subtitle: 'Available actions depend on provider capabilities.',
                icon: Icons.more_horiz_rounded,
              ),
              const SizedBox(height: 10),
              if (canDelete)
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      RealtimeUiTokens.controlRadius,
                    ),
                  ),
                  leading: const Icon(
                    Icons.delete_outline,
                    color: RealtimeUiTokens.danger,
                  ),
                  title: const Text('Delete message'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _moderate(
                      () => widget.session.deleteMessage(message.id),
                    );
                  },
                ),
              if (canRemoveUser)
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      RealtimeUiTokens.controlRadius,
                    ),
                  ),
                  leading: const Icon(
                    Icons.person_remove_outlined,
                    color: RealtimeUiTokens.danger,
                  ),
                  title: Text(
                    'Remove ${message.displayName.isEmpty ? message.userId : message.displayName}',
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _moderate(
                      () => widget.session.disconnectUser(message.userId),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _moderate(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) setState(() => _error = null);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _showChatManagement() async {
    final moderation = widget.moderation;
    if (moderation == null) return;
    List<ChatMember> members = const [];
    Object? loadError;
    try {
      members = await moderation.listMembers();
    } catch (error) {
      loadError = error;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white.withValues(alpha: .96),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const RealtimeSheetHeader(
                title: 'Chat management',
                subtitle: 'Host-only control plane actions',
                icon: Icons.forum_outlined,
              ),
              const SizedBox(height: 12),
              if (loadError != null)
                Text(
                  loadError.toString(),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ...members.map(
                (member) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      RealtimeUiTokens.controlRadius,
                    ),
                  ),
                  leading: const CircleAvatar(
                    backgroundColor: RealtimeUiTokens.primarySubtle,
                    child: Icon(
                      Icons.person_outline,
                      color: RealtimeUiTokens.primary,
                    ),
                  ),
                  title: Text(
                    member.displayName.isEmpty
                        ? member.userId
                        : member.displayName,
                  ),
                  subtitle: Text(member.role.name),
                ),
              ),
              const Divider(),
              RealtimeDangerButton(
                label: 'Close chat room',
                icon: Icons.stop_circle_outlined,
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  await _moderate(moderation.closeRoom);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
