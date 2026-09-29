import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';

import 'realtime_strings.dart';
import 'realtime_ui_style.dart';

/// Reusable chat surface for standalone and media-attached chat.
class RealtimeChatView extends StatefulWidget {
  const RealtimeChatView({
    super.key,
    required this.session,
    this.roomCode,
    this.title,
    this.showAppBar = false,
    this.moderation,
  });
  final ChatSession session;
  final String? roomCode;
  final String? title;
  final bool showAppBar;
  final ChatModeration? moderation;
  @override
  State<RealtimeChatView> createState() => _RealtimeChatViewState();
}

class _RealtimeChatViewState extends State<RealtimeChatView> {
  final _message = TextEditingController();
  bool _sending = false;
  bool _copiedCode = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  void _copyRoomCode() {
    final code = widget.roomCode;
    if (code == null || code.isEmpty) return;
    Clipboard.setData(ClipboardData(text: code));
    setState(() => _copiedCode = true);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copiedCode = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = RealtimeStrings.of(context);
    final resolvedTitle = widget.title ?? strings.chat;
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                radius: RealtimeUiTokens.cardRadius,
                opacity: .86,
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: RealtimeUiTokens.primarySubtle,
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.compactRadius,
                        ),
                        border: Border.all(
                          color: RealtimeUiTokens.primaryBorder,
                        ),
                      ),
                      child: const Icon(
                        Icons.forum_outlined,
                        color: RealtimeUiTokens.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  resolvedTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: RealtimeUiTokens.text,
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: state.isConnected
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            [
                              if (widget.roomCode != null)
                                strings.roomLabel(widget.roomCode!),
                              widget.session.providerId,
                              strings.chatConnectionState(state.name),
                              strings.messageCount(messages.length),
                            ].join(' · '),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: RealtimeUiTokens.textMuted),
                          ),
                        ],
                      ),
                    ),
                    if (widget.roomCode != null && widget.roomCode!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: RealtimePill(
                          label: widget.roomCode!,
                          icon: _copiedCode
                              ? Icons.check_rounded
                              : Icons.copy_rounded,
                          foreground: _copiedCode
                              ? RealtimeUiTokens.success
                              : RealtimeUiTokens.primary,
                          background: _copiedCode
                              ? RealtimeUiTokens.successSubtle
                              : RealtimeUiTokens.primarySubtle,
                          borderColor: _copiedCode
                              ? RealtimeUiTokens.successBorder
                              : RealtimeUiTokens.primaryBorder,
                          onTap: _copyRoomCode,
                        ),
                      ),
                    if (widget.moderation != null &&
                        widget.session.role == ChatRole.host)
                      RealtimeGlassIconButton(
                        tooltip: strings.manageChat,
                        onPressed: _showChatManagement,
                        icon: Icons.admin_panel_settings_outlined,
                        size: 40,
                        radius: RealtimeUiTokens.compactRadius,
                      ),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: RealtimeUiTokens.animNormal,
                  child: messages.isEmpty
                      ? _emptyState(strings)
                      : ListView.builder(
                          key: const ValueKey('realtime-chat-list'),
                          reverse: true,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message =
                                messages[messages.length - 1 - index];
                            final identity =
                                widget.session is ChatSessionIdentity
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
                              child: RealtimeGlassPressable(
                                onLongPress: canDelete || canRemoveUser
                                    ? () => _showMessageManagement(
                                        message,
                                        canDelete: canDelete,
                                        canRemoveUser: canRemoveUser,
                                      )
                                    : null,
                                borderRadius: RealtimeUiTokens.controlRadius,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    maxWidth: 520,
                                  ),
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: own
                                        ? RealtimeUiTokens.primaryGradient
                                        : null,
                                    color: own
                                        ? null
                                        : Colors.white.withValues(alpha: .88),
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(
                                        RealtimeUiTokens.controlRadius,
                                      ),
                                      topRight: const Radius.circular(
                                        RealtimeUiTokens.controlRadius,
                                      ),
                                      bottomLeft: Radius.circular(
                                        own
                                            ? RealtimeUiTokens.controlRadius
                                            : 6,
                                      ),
                                      bottomRight: Radius.circular(
                                        own
                                            ? 6
                                            : RealtimeUiTokens.controlRadius,
                                      ),
                                    ),
                                    border: own
                                        ? null
                                        : Border.all(
                                            color: RealtimeUiTokens.border,
                                          ),
                                    boxShadow: own
                                        ? [
                                            BoxShadow(
                                              color: RealtimeUiTokens.primary
                                                  .withValues(alpha: 0.22),
                                              blurRadius: 14,
                                              offset: const Offset(0, 4),
                                            ),
                                          ]
                                        : RealtimeUiTokens.cardShadow,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (!own)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 3,
                                          ),
                                          child: Text(
                                            message.displayName,
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w800,
                                              color: RealtimeUiTokens.primary,
                                            ),
                                          ),
                                        ),
                                      Text(
                                        message.message,
                                        style: TextStyle(
                                          color: own
                                              ? Colors.white
                                              : RealtimeUiTokens.text,
                                          fontSize: 13.5,
                                          height: 1.35,
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
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: RealtimeUiTokens.dangerSubtle,
                      borderRadius: BorderRadius.circular(
                        RealtimeUiTokens.compactRadius,
                      ),
                      border: Border.all(color: RealtimeUiTokens.dangerBorder),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12.5,
                      ),
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
            extendBodyBehindAppBar: false,
            appBar: AppBar(
              title: Text(resolvedTitle),
              backgroundColor: Colors.white.withValues(alpha: .78),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
            ),
            body: RealtimeAmbientBackground(child: body),
          )
        : body;
  }

  Widget _emptyState(RealtimeStrings strings) => Center(
    child: RealtimeGlassSurface(
      radius: RealtimeUiTokens.cardRadius,
      opacity: 0.78,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: RealtimeUiTokens.primarySubtle,
              borderRadius: BorderRadius.circular(
                RealtimeUiTokens.compactRadius,
              ),
              border: Border.all(color: RealtimeUiTokens.primaryBorder),
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: RealtimeUiTokens.primary,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            strings.noMessagesYet,
            style: const TextStyle(
              color: RealtimeUiTokens.text,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            strings.startConversation,
            style: const TextStyle(
              color: RealtimeUiTokens.textMuted,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _composer(ChatConnectionState state) {
    final strings = RealtimeStrings.of(context);
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
        radius: RealtimeUiTokens.cardRadius,
        opacity: .88,
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
                  hintText: enabled
                      ? strings.messageHint
                      : strings.chatState(state.name),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: .82),
                  border: border,
                  enabledBorder: border,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      RealtimeUiTokens.controlRadius,
                    ),
                    borderSide: const BorderSide(
                      color: RealtimeUiTokens.primary,
                      width: 1.5,
                    ),
                  ),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            RealtimeGlassPressable(
              borderRadius: RealtimeUiTokens.controlRadius,
              child: IconButton.filled(
                onPressed: enabled ? _send : null,
                style: IconButton.styleFrom(
                  backgroundColor: RealtimeUiTokens.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(44, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      RealtimeUiTokens.controlRadius,
                    ),
                  ),
                ),
                icon: _sending
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 19),
              ),
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
    final strings = RealtimeStrings.of(context);
    await showRealtimeGlassBottomSheet<void>(
      context: context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RealtimeSheetHeader(
              title: strings.messageActions,
              subtitle: strings.capabilityDependentActions,
              icon: Icons.more_horiz_rounded,
            ),
            const SizedBox(height: 12),
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
                title: Text(
                  strings.deleteMessage,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
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
                  strings.removeUser(
                    message.displayName.isEmpty
                        ? message.userId
                        : message.displayName,
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w600),
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
    final strings = RealtimeStrings.of(context);
    final capabilities = moderation is ChatModerationCapabilitySource
        ? (moderation as ChatModerationCapabilitySource).moderationCapabilities
        : const ChatManagementCapabilities(
            listMembers: ChatManagementCapability.backend(),
            closeRoom: ChatManagementCapability.backend(),
          );
    final identity = widget.session is ChatSessionIdentity
        ? widget.session as ChatSessionIdentity
        : null;
    List<ChatMember> members = const [];
    Object? loadError;
    if (capabilities.listMembers.supported) {
      try {
        members = await moderation.listMembers();
      } catch (error) {
        loadError = error;
      }
    }
    if (!mounted) return;
    await showRealtimeGlassBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RealtimeSheetHeader(
                title: strings.chatManagement,
                subtitle: strings.hostOnlyActions,
                icon: Icons.forum_outlined,
              ),
              const SizedBox(height: 14),
              if (loadError != null)
                Text(
                  loadError.toString(),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ...members.map(
                (member) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(
                      RealtimeUiTokens.controlRadius,
                    ),
                    border: Border.all(color: RealtimeUiTokens.border),
                  ),
                  child: ListTile(
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
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      member.userId == identity?.localUserId
                          ? '${strings.roleLabel(member.role.name)} · ${strings.you}'
                          : strings.roleLabel(member.role.name),
                    ),
                    trailing: member.userId == identity?.localUserId
                        ? null
                        : IconButton(
                            tooltip: capabilities.removeMember.supported
                                ? strings.removeFromChat
                                : capabilities.removeMember.reason ??
                                      strings.chatManagementUnavailable,
                            onPressed: capabilities.removeMember.supported
                                ? () async {
                                    Navigator.pop(sheetContext);
                                    await _moderate(
                                      () => moderation.removeMember(
                                        member.userId,
                                      ),
                                    );
                                  }
                                : null,
                            icon: const Icon(
                              Icons.person_remove_outlined,
                              color: RealtimeUiTokens.danger,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              RealtimeDangerButton(
                label: strings.closeChatRoom,
                icon: Icons.stop_circle_outlined,
                onPressed: capabilities.closeRoom.supported
                    ? () async {
                        Navigator.pop(sheetContext);
                        await _moderate(moderation.closeRoom);
                      }
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
