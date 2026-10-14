import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_chat_ui/flutter_realtime_chat_ui.dart';

import 'realtime_strings.dart';
import 'realtime_ui_style.dart';

part 'legacy_chat_actions.dart';

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

class _RealtimeChatViewState extends State<RealtimeChatView>
    with _LegacyChatActions {
  @override
  late ChatUiController _chatUi;
  @override
  final _message = TextEditingController();
  final _scrollController = ScrollController();
  @override
  bool _sending = false;
  bool _copiedCode = false;
  Timer? _copyTimer;
  bool _showScrollToBottom = false;
  @override
  String? _error;

  bool _isSearching = false;
  @override
  ChatMessage? _replyingTo;
  @override
  bool _showEmojiDrawer = false;

  static const _quickEmojis = ['👍', '❤️', '👏', '🎉', '🔥', '🚀', '💯', '😂'];
  static const _drawerEmojis = [
    '👍',
    '❤️',
    '👏',
    '🎉',
    '🔥',
    '🚀',
    '💯',
    '😂',
    '😊',
    '😍',
    '🤝',
    '🙌',
    '✨',
    '🌟',
    '💪',
    '💡',
    '☕️',
    '🎈',
    '👌',
    '🙏',
    '👀',
    '🤔',
    '👋',
    '☀️',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _chatUi = ChatUiController(widget.session, moderation: widget.moderation);
  }

  final Set<String> _visibleMessageIds = {};
  bool _timelineInitialized = false;
  bool _newMessages = false;

  @override
  void didUpdateWidget(covariant RealtimeChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.session, widget.session) ||
        !identical(oldWidget.moderation, widget.moderation)) {
      _chatUi.dispose();
      _chatUi = ChatUiController(widget.session, moderation: widget.moderation);
    }
    if (oldWidget.session != widget.session) {
      _visibleMessageIds.clear();
      _timelineInitialized = false;
      _sending = false;
      _error = null;
      _newMessages = false;
      _message.clear();
      _replyingTo = null;
      _isSearching = false;
      _showEmojiDrawer = false;
    }
  }

  void _syncMessages(List<ChatMessage> messages) {
    final first = !_timelineInitialized;
    final added = messages.any((m) => !_visibleMessageIds.contains(m.id));
    _timelineInitialized = true;
    _visibleMessageIds
      ..clear()
      ..addAll(messages.map((m) => m.id));
    if (!first && !added) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (first || _scrollController.offset <= 72) {
        _scrollController.animateTo(
          0,
          duration: RealtimeUiTokens.animNormal,
          curve: Curves.easeOut,
        );
      } else {
        setState(() => _newMessages = true);
      }
    });
  }

  void _onScroll() {
    final show = _scrollController.hasClients && _scrollController.offset > 100;
    if (show != _showScrollToBottom) {
      setState(() => _showScrollToBottom = show);
    }
  }

  @override
  void dispose() {
    _chatUi.dispose();
    _copyTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _message.dispose();
    super.dispose();
  }

  void _copyRoomCode() {
    final code = widget.roomCode;
    if (code == null || code.isEmpty) return;
    observeDetached(Clipboard.setData(ClipboardData(text: code)));
    setState(() => _copiedCode = true);
    _copyTimer?.cancel();
    _copyTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copiedCode = false);
    });
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final strings = RealtimeStrings.of(context);
    final resolvedTitle = widget.title ?? strings.chat;
    final body = ListenableBuilder(
      listenable: _chatUi,
      builder: (context, _) {
        final state = _chatUi.state;
        final messages = _chatUi.messages;
        final style = RealtimeStyle.of(context);
        _syncMessages(messages);
        return Column(
          children: [
            RealtimeGlassSurface(
              margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              radius: RealtimeUiTokens.cardRadius,
              opacity: .86,
              child: Row(
                children: [
                  if (widget.showAppBar) ...[
                    RealtimeGlassIconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icons.arrow_back_rounded,
                      size: 40,
                      radius: RealtimeUiTokens.compactRadius,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: RealtimeUiTokens.primarySubtle,
                      borderRadius: BorderRadius.circular(
                        RealtimeUiTokens.compactRadius,
                      ),
                      border: Border.all(color: RealtimeUiTokens.primaryBorder),
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
                                style: TextStyle(
                                  color: RealtimeStyle.of(context).text,
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                  const SizedBox(width: 4),
                  RealtimeGlassIconButton(
                    tooltip: strings.searchMessages,
                    onPressed: () => setState(() {
                      _isSearching = !_isSearching;
                      if (!_isSearching) _chatUi.setSearch('');
                    }),
                    icon: _isSearching
                        ? Icons.search_off_rounded
                        : Icons.search_rounded,
                    size: 40,
                    radius: RealtimeUiTokens.compactRadius,
                    active: _isSearching,
                  ),
                ],
              ),
            ),
            if (_isSearching)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: TextField(
                  autofocus: true,
                  onChanged: _chatUi.setSearch,
                  decoration: InputDecoration(
                    hintText: strings.searchMessagesHint,
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    isDense: true,
                    filled: true,
                    fillColor: style.surfaceSubtle,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        RealtimeUiTokens.compactRadius,
                      ),
                      borderSide: BorderSide(color: style.border),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedSwitcher(
                      duration: RealtimeUiTokens.animNormal,
                      child: () {
                        final filteredMessages = _isSearching
                            ? _chatUi.filteredMessages
                            : messages;

                        if (filteredMessages.isEmpty) {
                          return _isSearching
                              ? Center(
                                  child: Text(
                                    strings.noMessagesFound,
                                    style: const TextStyle(
                                      color: RealtimeUiTokens.textMuted,
                                    ),
                                  ),
                                )
                              : _emptyState(strings);
                        }

                        return ListView.builder(
                          key: const ValueKey('realtime-chat-list'),
                          controller: _scrollController,
                          reverse: true,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          itemCount: filteredMessages.length,
                          itemBuilder: (context, index) {
                            final style = RealtimeStyle.of(context);
                            final message =
                                filteredMessages[filteredMessages.length -
                                    1 -
                                    index];
                            final identity =
                                widget.session is ChatSessionIdentity
                                ? widget.session as ChatSessionIdentity
                                : null;
                            final own = message.userId == identity?.localUserId;
                            final capabilities = _chatUi.managementCapabilities;
                            final canDelete =
                                (own || _chatUi.isHost) &&
                                (capabilities.deleteMessage.supported ||
                                    capabilities.recallMessage.supported);
                            final canRemoveUser =
                                _chatUi.isHost &&
                                capabilities.removeMember.supported &&
                                !own;

                            final bubble = RealtimeGlassPressable(
                              onLongPress: () => _showMessageManagement(
                                message,
                                canDelete: canDelete,
                                canRemoveUser: canRemoveUser,
                              ),
                              borderRadius: RealtimeUiTokens.controlRadius,
                              child: Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 520,
                                ),
                                margin: const EdgeInsets.only(bottom: 8),
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
                                      : style.surface.withValues(alpha: .92),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(
                                      RealtimeUiTokens.controlRadius,
                                    ),
                                    topRight: const Radius.circular(
                                      RealtimeUiTokens.controlRadius,
                                    ),
                                    bottomLeft: Radius.circular(
                                      own ? RealtimeUiTokens.controlRadius : 4,
                                    ),
                                    bottomRight: Radius.circular(
                                      own ? 4 : RealtimeUiTokens.controlRadius,
                                    ),
                                  ),
                                  border: own
                                      ? null
                                      : Border.all(color: style.border),
                                  boxShadow: own
                                      ? [
                                          BoxShadow(
                                            color: style.primary.withValues(
                                              alpha: 0.22,
                                            ),
                                            blurRadius: 14,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : style.cardShadow,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!own)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 3,
                                        ),
                                        child: Text(
                                          message.displayName.isEmpty
                                              ? message.userId
                                              : message.displayName,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                            color: style.textSecondary,
                                          ),
                                        ),
                                      ),
                                    Text(
                                      message.message,
                                      style: TextStyle(
                                        color: own ? Colors.white : style.text,
                                        fontSize: 13.5,
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Align(
                                      alignment: Alignment.bottomRight,
                                      child: Text(
                                        _formatTime(message.timestamp),
                                        style: TextStyle(
                                          color: own
                                              ? Colors.white.withValues(
                                                  alpha: .72,
                                                )
                                              : style.textMuted,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );

                            if (own) {
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Flexible(child: bubble),
                                  const SizedBox(width: 8),
                                  RealtimeAvatar(
                                    name: message.displayName.isEmpty
                                        ? message.userId
                                        : message.displayName,
                                    avatarUrl: message.avatarUrl,
                                    size: 32,
                                  ),
                                ],
                              );
                            }

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RealtimeAvatar(
                                    name: message.displayName.isEmpty
                                        ? message.userId
                                        : message.displayName,
                                    avatarUrl: message.avatarUrl,
                                    size: 32,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: bubble,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      }(),
                    ),
                  ),
                  if (_showScrollToBottom)
                    Positioned(
                      bottom: 12,
                      right: 14,
                      child: RealtimeGlassSurface(
                        radius: RealtimeUiTokens.pillRadius,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        opacity: .94,
                        child: InkWell(
                          onTap: () {
                            setState(() => _newMessages = false);
                            _scrollController.animateTo(
                              0.0,
                              duration: RealtimeUiTokens.animNormal,
                              curve: Curves.easeOutCubic,
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.arrow_downward_rounded,
                                size: 14,
                                color: RealtimeUiTokens.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _newMessages
                                    ? strings.newMessages
                                    : strings.scrollToBottom,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: RealtimeUiTokens.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
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
    );
    return widget.showAppBar
        ? Scaffold(
            backgroundColor: Colors.transparent,
            body: RealtimeAmbientBackground(child: SafeArea(child: body)),
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
}
