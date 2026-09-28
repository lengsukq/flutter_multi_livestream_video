import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'media_provider_label.dart';
import 'realtime_ui_style.dart';

typedef MediaParticipantBuilder =
    Widget Function(
      BuildContext context,
      MediaParticipant participant,
      MediaTrackRenderer renderer,
    );

class MediaRoomViewConfig {
  const MediaRoomViewConfig({
    this.showProvider = true,
    this.showChat = true,
    this.showRtcDataMessages = false,
    this.confirmBeforeLeave = true,
  });
  final bool showProvider;
  final bool showChat;
  final bool showRtcDataMessages;
  final bool confirmBeforeLeave;
}

class MediaRoomView extends StatefulWidget {
  const MediaRoomView({
    super.key,
    required this.room,
    required this.renderer,
    this.chatSession,
    this.config = const MediaRoomViewConfig(),
    this.participantBuilder,
    this.onLeave,
  });
  final MediaRoomSession room;
  final MediaTrackRenderer renderer;
  final ChatSession? chatSession;
  final MediaRoomViewConfig config;
  final MediaParticipantBuilder? participantBuilder;
  final VoidCallback? onLeave;
  @override
  State<MediaRoomView> createState() => _MediaRoomViewState();
}

class _MediaRoomViewState extends State<MediaRoomView> {
  final _message = TextEditingController();
  final _rtcDataMessage = TextEditingController();
  final _chatScroll = ScrollController();
  Timer? _timer;
  int _seconds = 0;
  int _lastChatMessageCount = 0;
  bool _chatOpen = false;
  bool _chatSending = false;
  bool _rtcDataOpen = false;
  bool _copied = false;
  String? _error;
  MediaSession get session => widget.room.session;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  Future<void> _showRoomManagement() async {
    final isLogicalOwner = widget.room.roomOwnerCredential?.isNotEmpty ?? false;
    List<MediaRoomParticipantSummary> participants = const [];
    Object? loadError;
    if (isLogicalOwner || session.capabilities.canListParticipants) {
      try {
        participants = await widget.room.listParticipants();
      } catch (error) {
        loadError = error;
      }
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RealtimeSheetHeader(
                title: 'Room management',
                subtitle:
                    'Provider: ${widget.room.providerId} · Role: ${widget.room.role.name}',
              ),
              if (loadError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    loadError.toString(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (participants.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...participants.map(
                  (participant) => ListTile(
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
                      participant.displayName.isEmpty
                          ? participant.participantId
                          : participant.displayName,
                    ),
                    subtitle: Text(participant.role?.wireName ?? 'participant'),
                    trailing:
                        participant.participantId ==
                                widget.room.participantId ||
                            !session.capabilities.canRemoveParticipants
                        ? null
                        : IconButton(
                            tooltip: 'Remove participant',
                            icon: const Icon(Icons.person_remove_outlined),
                            onPressed: () async {
                              Navigator.pop(sheetContext);
                              await _run(
                                () => widget.room.removeParticipant(
                                  participant.participantId,
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
              if (isLogicalOwner || session.capabilities.canCloseRoom) ...[
                const SizedBox(height: 12),
                RealtimeDangerButton(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await _run(widget.room.closeRoom);
                    if (mounted) widget.onLeave?.call();
                  },
                  icon: Icons.stop_circle_outlined,
                  label: widget.room.role == MediaRole.host
                      ? 'Close room for everyone'
                      : 'Close room',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _message.dispose();
    _rtcDataMessage.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) setState(() => _error = null);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _leave() async {
    var leave = true;
    if (widget.config.confirmBeforeLeave) {
      leave =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.white.withValues(alpha: .97),
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  RealtimeUiTokens.cardRadius,
                ),
              ),
              title: const Text('Leave Meeting?'),
              content: const Text('Are you sure you want to disconnect?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: RealtimeUiTokens.danger,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        RealtimeUiTokens.controlRadius,
                      ),
                    ),
                  ),
                  child: const Text('Leave'),
                ),
              ],
            ),
          ) ??
          false;
    }
    if (!leave) return;
    await widget.chatSession?.dispose();
    await widget.room.dispose();
    widget.onLeave?.call();
    if (widget.onLeave == null && mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: widget.room.roomCode));
    setState(() => _copied = true);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<MediaSnapshot>(
    stream: session.snapshots,
    initialData: session.snapshot,
    builder: (context, snap) {
      final value = snap.data ?? session.snapshot;
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: RealtimeAmbientBackground(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                final compact = constraints.maxWidth < 520;
                return Column(
                  children: [
                    _topBar(value, compact: compact),
                    if (_error != null) _errorView(),
                    Expanded(
                      child: wide
                          ? _wideContent(value, constraints)
                          : _compactContent(value, constraints),
                    ),
                    if (_rtcDataOpen) _rtcData(),
                    _controls(value),
                  ],
                );
              },
            ),
          ),
        ),
      );
    },
  );

  Widget _wideContent(MediaSnapshot value, BoxConstraints constraints) {
    final chat = widget.chatSession;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _mediaStage(value)),
        if (_chatOpen && chat != null) ...[
          const VerticalDivider(width: 1, thickness: 1),
          SizedBox(
            key: const ValueKey('chat-panel-wide'),
            width: (constraints.maxWidth * .30).clamp(320.0, 420.0),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 12, 8),
              child: _productChat(chat),
            ),
          ),
        ],
      ],
    );
  }

  Widget _compactContent(MediaSnapshot value, BoxConstraints constraints) {
    final chat = widget.chatSession;
    final maxChatHeight = math.max(140.0, constraints.maxHeight - 150);
    final desiredChatHeight = (constraints.maxHeight * .42).clamp(180.0, 380.0);
    final chatHeight = math.min(desiredChatHeight, maxChatHeight);
    return Column(
      children: [
        Expanded(child: _mediaStage(value)),
        if (_chatOpen && chat != null)
          SizedBox(
            key: const ValueKey('chat-panel-compact'),
            height: chatHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
              child: _productChat(chat),
            ),
          ),
      ],
    );
  }

  Widget _mediaStage(MediaSnapshot value) => Column(
    children: [
      Expanded(child: value.participants.isEmpty ? _waiting() : _grid(value)),
      if (value.contentShareTrack != null) _screenShare(value),
    ],
  );

  Widget _topBar(MediaSnapshot value, {required bool compact}) {
    final mm = (_seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (_seconds % 60).toString().padLeft(2, '0');
    return RealtimeGlassSurface(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      radius: 20,
      opacity: .88,
      child: Row(
        children: [
          _iconButton(Icons.arrow_back_ios_new_rounded, _leave),
          const SizedBox(width: 10),
          InkWell(
            onTap: _copyCode,
            child: _badge(
              widget.room.roomCode,
              _copied ? Icons.check_rounded : Icons.copy_rounded,
            ),
          ),
          if (widget.config.showProvider && !compact) ...[
            const SizedBox(width: 8),
            _providerBadge(widget.room.providerId),
          ],
          const Spacer(),
          if (!compact) ...[
            _badge('$mm:$ss', Icons.circle),
            const SizedBox(width: 8),
          ],
          if ((widget.room.roomOwnerCredential?.isNotEmpty ?? false) ||
              (widget.room.role == MediaRole.host &&
                  (session.capabilities.canListParticipants ||
                      session.capabilities.canCloseRoom)))
            IconButton(
              tooltip: 'Manage room',
              onPressed: _showRoomManagement,
              icon: const Icon(Icons.admin_panel_settings_outlined),
            ),
          _badge('${value.participants.length}', Icons.people_outline_rounded),
        ],
      ),
    );
  }

  Widget _providerBadge(String id) {
    final label = mediaProviderDisplayName(id);
    return RealtimePill(
      label: label,
      icon: Icons.hub_outlined,
      foreground: RealtimeUiTokens.primary,
      background: RealtimeUiTokens.primarySubtle,
    );
  }

  Widget _badge(String text, IconData icon) =>
      RealtimePill(label: text, icon: icon);

  Widget _errorView() => Container(
    margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: RealtimeUiTokens.dangerSubtle.withValues(alpha: .94),
      borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
      border: Border.all(color: const Color(0xFFFECACA)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _error!,
            style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
          ),
        ),
      ],
    ),
  );

  Widget _waiting() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFEEF2FF),
          ),
          child: const Icon(
            Icons.wifi_tethering_rounded,
            size: 34,
            color: Color(0xFF4F46E5),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          "You're the only one here",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'Share the room code to start streaming',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _copyCode,
          icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded),
          label: Text(_copied ? 'Copied' : 'Copy ${widget.room.roomCode}'),
        ),
      ],
    ),
  );

  Widget _grid(MediaSnapshot value) => LayoutBuilder(
    builder: (context, constraints) {
      final count = value.participants.length;
      final columns = constraints.maxWidth > 900
          ? (count <= 4 ? 2 : 3)
          : constraints.maxWidth > 600
          ? (count <= 2 ? 2 : 3)
          : (count == 1 ? 1 : 2);
      return GridView.builder(
        padding: const EdgeInsets.all(10),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          childAspectRatio: count == 1 ? 4 / 3 : 1,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: count,
        itemBuilder: (context, index) {
          final participant = value.participants[index];
          return widget.participantBuilder?.call(
                context,
                participant,
                widget.renderer,
              ) ??
              MediaParticipantTile(
                participant: participant,
                renderer: widget.renderer,
              );
        },
      );
    },
  );

  Widget _screenShare(MediaSnapshot value) => Container(
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
    height: 160,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .94),
      borderRadius: BorderRadius.circular(RealtimeUiTokens.cardRadius),
      border: Border.all(color: RealtimeUiTokens.border),
      boxShadow: RealtimeUiTokens.cardShadow,
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(RealtimeUiTokens.cardRadius - 2),
      child: MediaTrackView(
        renderer: widget.renderer,
        track: value.contentShareTrack,
      ),
    ),
  );

  Widget _productChat(ChatSession chat) => StreamBuilder<ChatConnectionState>(
    stream: chat.states,
    initialData: chat.state,
    builder: (context, stateSnapshot) {
      final connectionState = stateSnapshot.data ?? chat.state;
      return StreamBuilder<List<ChatMessage>>(
        stream: chat.messageSnapshots,
        initialData: chat.messages,
        builder: (context, messageSnapshot) {
          final messages = messageSnapshot.data ?? chat.messages;
          _syncChatScroll(messages.length);
          return RealtimeGlassSurface(
            radius: RealtimeUiTokens.cardRadius,
            opacity: .92,
            child: Column(
              children: [
                _chatHeader(connectionState, messages.length),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                Expanded(
                  child: messages.isEmpty
                      ? _emptyChat()
                      : ListView.builder(
                          key: const ValueKey('chat-message-list'),
                          controller: _chatScroll,
                          reverse: true,
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final messageIndex = messages.length - 1 - index;
                            final message = messages[messageIndex];
                            final previous = messageIndex > 0
                                ? messages[messageIndex - 1]
                                : null;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _chatMessage(
                                chat,
                                message,
                                previousMessage: previous,
                              ),
                            );
                          },
                        ),
                ),
                _chatComposer(chat, connectionState),
              ],
            ),
          );
        },
      );
    },
  );

  Widget _chatHeader(ChatConnectionState connectionState, int messageCount) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 8, 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: RealtimeUiTokens.primarySubtle,
                borderRadius: BorderRadius.circular(
                  RealtimeUiTokens.compactRadius,
                ),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 17,
                color: RealtimeUiTokens.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Chat',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (messageCount > 0) ...[
                        const SizedBox(width: 6),
                        Text(
                          '$messageCount',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: connectionState.isConnected
                              ? const Color(0xFF22C55E)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          connectionState.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Close chat',
              visualDensity: VisualDensity.compact,
              onPressed: _toggleChat,
              icon: const Icon(Icons.close_rounded, size: 19),
            ),
          ],
        ),
      );

  Widget _emptyChat() => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined, size: 28, color: Color(0xFFCBD5E1)),
          SizedBox(height: 8),
          Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 3),
          Text(
            'Start the conversation',
            style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    ),
  );

  Widget _chatMessage(
    ChatSession chat,
    ChatMessage message, {
    ChatMessage? previousMessage,
  }) {
    if (message.type != 'message') {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            message.message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
          ),
        ),
      );
    }

    final own = _isOwnChatMessage(chat, message);
    final sameSenderAsPrevious =
        previousMessage != null && previousMessage.userId == message.userId;
    final displayName = message.displayName.trim().isEmpty
        ? message.userId
        : message.displayName.trim();
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: own ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth * .80),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: own
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (!own && !sameSenderAsPrevious)
                Padding(
                  padding: const EdgeInsets.only(left: 3, bottom: 4),
                  child: Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Container(
                key: ValueKey(
                  'chat-message-${message.id}-${own ? 'local' : 'remote'}',
                ),
                padding: const EdgeInsets.fromLTRB(11, 8, 10, 6),
                decoration: BoxDecoration(
                  color: own ? const Color(0xFF4F46E5) : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(15),
                    topRight: const Radius.circular(15),
                    bottomLeft: Radius.circular(own ? 15 : 5),
                    bottomRight: Radius.circular(own ? 5 : 15),
                  ),
                  border: own
                      ? null
                      : Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        message.message,
                        style: TextStyle(
                          color: own ? Colors.white : const Color(0xFF1E293B),
                          fontSize: 12.5,
                          height: 1.28,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatChatTime(message.timestamp),
                      style: TextStyle(
                        color: own
                            ? Colors.white.withValues(alpha: .72)
                            : const Color(0xFF94A3B8),
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chatComposer(ChatSession chat, ChatConnectionState connectionState) {
    final enabled =
        connectionState.isConnected &&
        chat.capabilities.canSendMessage &&
        !_chatSending;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: RealtimeUiTokens.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                key: const ValueKey('chat-message-input'),
                controller: _message,
                enabled: enabled,
                minLines: 1,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: connectionState.isConnected
                      ? chat.capabilities.canSendMessage
                            ? 'Message…'
                            : 'Read only'
                      : 'Chat is ${connectionState.name}',
                  hintStyle: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                onSubmitted: enabled ? (_) => _sendChat(chat) : null,
              ),
            ),
          ),
          const SizedBox(width: 7),
          SizedBox(
            width: 38,
            height: 38,
            child: FilledButton(
              key: const ValueKey('chat-send-button'),
              onPressed: enabled ? () => _sendChat(chat) : null,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: _chatSending
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.arrow_upward_rounded, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  bool _isOwnChatMessage(ChatSession chat, ChatMessage message) {
    if (chat is ChatSessionIdentity) {
      final identity = chat as ChatSessionIdentity;
      final localUserId = identity.localUserId.trim();
      if (localUserId.isNotEmpty && message.userId == localUserId) return true;
      final localParticipantId = identity.localParticipantId.trim();
      if (localParticipantId.isNotEmpty &&
          message.attributes['participantId'] == localParticipantId) {
        return true;
      }
    }
    if (message.attributes['local'] == 'true') return true;
    return message.userId == widget.room.participantId;
  }

  String _formatChatTime(DateTime timestamp) {
    final local = timestamp.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _syncChatScroll(int messageCount) {
    if (_lastChatMessageCount == messageCount) return;
    final previousCount = _lastChatMessageCount;
    _lastChatMessageCount = messageCount;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_chatScroll.hasClients) return;
      final nearLatest =
          previousCount == 0 || _chatScroll.position.pixels <= 72;
      if (nearLatest) {
        _chatScroll.animateTo(
          0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _toggleChat() {
    setState(() => _chatOpen = !_chatOpen);
    if (_chatOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_chatScroll.hasClients) _chatScroll.jumpTo(0);
      });
    }
  }

  Future<void> _sendChat(ChatSession chat) async {
    final text = _message.text.trim();
    if (text.isEmpty || _chatSending) return;
    setState(() => _chatSending = true);
    try {
      await chat.sendMessage(text);
      if (!mounted) return;
      _message.clear();
      setState(() => _error = null);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_chatScroll.hasClients) {
          _chatScroll.animateTo(
            0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
        }
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _chatSending = false);
    }
  }

  Widget _rtcData() {
    if (!session.capabilities.canSendData) return const SizedBox.shrink();
    return RealtimeGlassSurface(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      radius: RealtimeUiTokens.controlRadius,
      opacity: .88,
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Text(
              'RTC Data',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _rtcDataMessage,
              decoration: const InputDecoration(
                hintText: 'Debug data payload…',
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _sendRtcData(),
            ),
          ),
          IconButton(
            onPressed: _sendRtcData,
            icon: const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }

  void _sendRtcData() {
    final text = _rtcDataMessage.text.trim();
    if (text.isEmpty) return;
    _run(
      () => session.sendData(
        text,
        options: const MediaSendOptions(topic: 'debug'),
      ),
    ).then((_) {
      if (mounted && _error == null) _rtcDataMessage.clear();
    });
  }

  Widget _controls(MediaSnapshot value) {
    final interactive = session is InteractiveMediaSession
        ? session as InteractiveMediaSession
        : null;
    final caps = value.capabilities;
    return RealtimeGlassSurface(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      radius: 26,
      opacity: .90,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (interactive != null && caps.canPublishAudio)
              _control(
                value.localMuted
                    ? Icons.mic_off_outlined
                    : Icons.mic_none_rounded,
                () => _run(interactive.toggleMute),
                active: !value.localMuted,
              ),
            if (interactive != null && caps.canPublishVideo) ...[
              const SizedBox(width: 8),
              _control(
                value.localVideoEnabled
                    ? Icons.videocam_outlined
                    : Icons.videocam_off_outlined,
                () => _run(
                  () => interactive.setVideoEnabled(!value.localVideoEnabled),
                ),
                active: value.localVideoEnabled,
              ),
            ],
            if (interactive != null && caps.canSwitchCamera) ...[
              const SizedBox(width: 8),
              _control(
                Icons.cameraswitch_outlined,
                () => _run(
                  () => interactive.switchCamera(MediaCameraPosition.back),
                ),
              ),
            ],
            if (interactive != null && caps.canScreenShare) ...[
              const SizedBox(width: 8),
              _control(
                value.localScreenShareEnabled
                    ? Icons.stop_screen_share_outlined
                    : Icons.screen_share_outlined,
                () => _run(
                  () => interactive.setScreenShareEnabled(
                    !value.localScreenShareEnabled,
                  ),
                ),
                active: value.localScreenShareEnabled,
              ),
            ],
            if (widget.config.showChat && widget.chatSession != null) ...[
              const SizedBox(width: 8),
              _control(
                Icons.chat_bubble_outline_rounded,
                _toggleChat,
                active: _chatOpen,
              ),
            ],
            if (widget.config.showRtcDataMessages && caps.canSendData) ...[
              const SizedBox(width: 8),
              _control(
                Icons.data_object_rounded,
                () => setState(() => _rtcDataOpen = !_rtcDataOpen),
                active: _rtcDataOpen,
              ),
            ],
            const SizedBox(width: 10),
            _control(Icons.call_end_rounded, _leave, endCall: true),
          ],
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback action) =>
      _control(icon, action);

  Widget _control(
    IconData icon,
    VoidCallback action, {
    bool active = false,
    bool endCall = false,
  }) => InkWell(
    onTap: action,
    borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: endCall
            ? RealtimeUiTokens.danger
            : active
            ? RealtimeUiTokens.primarySubtle
            : Colors.white.withValues(alpha: .78),
        borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
        border: Border.all(
          color: endCall
              ? RealtimeUiTokens.danger
              : active
              ? const Color(0xFFC7D2FE)
              : RealtimeUiTokens.border,
        ),
      ),
      child: Icon(
        icon,
        size: 19,
        color: endCall
            ? Colors.white
            : active
            ? RealtimeUiTokens.primary
            : RealtimeUiTokens.textMuted,
      ),
    ),
  );
}

class MediaParticipantTile extends StatelessWidget {
  const MediaParticipantTile({
    super.key,
    required this.participant,
    required this.renderer,
  });
  final MediaParticipant participant;
  final MediaTrackRenderer renderer;

  @override
  Widget build(BuildContext context) {
    final name = participant.displayName.isEmpty
        ? 'Participant'
        : participant.displayName;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(RealtimeUiTokens.cardRadius),
        border: Border.all(
          color: participant.isSpeaking
              ? const Color(0xFF10B981)
              : RealtimeUiTokens.border,
          width: participant.isSpeaking ? 2 : 1,
        ),
        boxShadow: RealtimeUiTokens.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(RealtimeUiTokens.cardRadius - 2),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (participant.videoTrack != null)
              MediaTrackView(renderer: renderer, track: participant.videoTrack)
            else
              Container(
                color: const Color(0xFFF8FAFC),
                alignment: Alignment.center,
                child: CircleAvatar(
                  radius: 29,
                  backgroundColor: RealtimeUiTokens.primarySubtle,
                  child: Text(
                    name.characters.first.toUpperCase(),
                    style: const TextStyle(
                      color: RealtimeUiTokens.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .94),
                  borderRadius: BorderRadius.circular(
                    RealtimeUiTokens.compactRadius,
                  ),
                  border: Border.all(color: RealtimeUiTokens.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$name${participant.isLocal ? ' (you)' : ''}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      participant.isMuted
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
                      size: 14,
                      color: participant.isMuted
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
