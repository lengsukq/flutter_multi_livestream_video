part of 'media_room_view.dart';

class _RoomChatPanel extends StatelessWidget {
  const _RoomChatPanel({
    required this.host,
    required this.chat,
    required this.showHeader,
  });
  final _MediaRoomViewState host;
  final ChatSession chat;
  final bool showHeader;
  @override
  Widget build(BuildContext context) => RoomRegion(
    revision: host._chatRevision,
    builder: (_) => host._renderProductChat(chat, showHeader: showHeader),
  );
}

extension _RoomChatRendering on _MediaRoomViewState {
  Widget _renderProductChat(
    ChatSession chat, {
    bool showHeader = true,
  }) => StreamBuilder<ChatConnectionState>(
    key: ValueKey(chat),
    stream: chat.states,
    initialData: chat.state,
    builder: (context, stateSnapshot) {
      final connectionState = stateSnapshot.data ?? chat.state;
      return ValueListenableBuilder<List<ChatMessage>>(
        valueListenable: _chatEvents.danmaku,
        builder: (context, messages, _) {
          _syncChatScroll(messages);
          return RealtimeGlassSurface(
            radius: RealtimeUiTokens.cardRadius,
            opacity: .90,
            child: Column(
              children: [
                if (showHeader) ...[
                  _chatHeader(connectionState, messages.length),
                  Divider(height: 1, color: RealtimeStyle.of(context).border),
                ],
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
                if (_hasNewChatMessages)
                  TextButton.icon(
                    icon: const Icon(Icons.arrow_downward_rounded),
                    label: Text(RealtimeStrings.of(context).newMessages),
                    onPressed: () {
                      _hasNewChatMessages = false;
                      _chatRevision.value++;
                      if (_chatScroll.hasClients) {
                        _chatScroll.animateTo(
                          0,
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                        );
                      }
                    },
                  ),
                _chatComposer(chat, connectionState),
              ],
            ),
          );
        },
      );
    },
  );

  Widget _chatHeader(ChatConnectionState connectionState, int messageCount) {
    final style = RealtimeStyle.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: style.primarySubtle,
              borderRadius: BorderRadius.circular(
                RealtimeUiTokens.compactRadius,
              ),
              border: Border.all(color: style.primaryBorder),
            ),
            child: Icon(Icons.forum_outlined, size: 17, color: style.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      RealtimeStrings.of(context).chat,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: style.text,
                      ),
                    ),
                    if (messageCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: style.primarySubtle,
                          borderRadius: BorderRadius.circular(
                            RealtimeUiTokens.pillRadius,
                          ),
                        ),
                        child: Text(
                          '$messageCount',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: style.primary,
                            fontWeight: FontWeight.w800,
                          ),
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
                        RealtimeStrings.of(
                          context,
                        ).chatConnectionState(connectionState.name),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: style.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: RealtimeStrings.of(context).closeChat,
            visualDensity: VisualDensity.compact,
            onPressed: _toggleChat,
            icon: Icon(Icons.close_rounded, size: 19, color: style.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _emptyChat() {
    final strings = RealtimeStrings.of(context);
    final style = RealtimeStyle.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: style.primarySubtle,
                borderRadius: BorderRadius.circular(
                  RealtimeUiTokens.compactRadius,
                ),
              ),
              child: Icon(Icons.forum_outlined, size: 22, color: style.primary),
            ),
            const SizedBox(height: 10),
            Text(
              strings.noMessagesYet,
              style: TextStyle(
                fontSize: 12.5,
                color: style.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              strings.startConversation,
              style: TextStyle(fontSize: 11, color: style.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chatMessage(
    ChatSession chat,
    ChatMessage message, {
    ChatMessage? previousMessage,
  }) {
    final style = RealtimeStyle.of(context);
    if (message.type != 'message') {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: style.surfaceSubtle,
            borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
            border: Border.all(color: style.border),
          ),
          child: Text(
            message.message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10.5, color: style.textMuted),
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
          constraints: BoxConstraints(maxWidth: constraints.maxWidth * .82),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: own
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (!own && !sameSenderAsPrevious)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: style.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Container(
                key: ValueKey(
                  'chat-message-${message.id}-${own ? 'local' : 'remote'}',
                ),
                padding: const EdgeInsets.fromLTRB(12, 9, 11, 7),
                decoration: BoxDecoration(
                  gradient: own ? RealtimeUiTokens.primaryGradient : null,
                  color: own ? null : style.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(
                      RealtimeUiTokens.controlRadius,
                    ),
                    topRight: const Radius.circular(
                      RealtimeUiTokens.controlRadius,
                    ),
                    bottomLeft: Radius.circular(
                      own ? RealtimeUiTokens.controlRadius : 6,
                    ),
                    bottomRight: Radius.circular(
                      own ? 6 : RealtimeUiTokens.controlRadius,
                    ),
                  ),
                  border: own ? null : Border.all(color: style.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        message.message,
                        style: TextStyle(
                          color: own ? Colors.white : style.text,
                          fontSize: 12.5,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatChatTime(message.timestamp),
                      style: TextStyle(
                        color: own
                            ? Colors.white.withValues(alpha: .74)
                            : style.textMuted,
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
    final strings = RealtimeStrings.of(context);
    final style = RealtimeStyle.of(context);
    final enabled =
        connectionState.isConnected &&
        chat.capabilities.canSendMessage &&
        !_chatSending;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: style.surface.withValues(alpha: style.isDark ? 0.85 : 0.95),
        border: Border(top: BorderSide(color: style.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: style.surfaceSubtle,
                borderRadius: BorderRadius.circular(
                  RealtimeUiTokens.controlRadius,
                ),
                border: Border.all(color: style.border),
              ),
              child: TextField(
                key: const ValueKey('chat-message-input'),
                controller: _message,
                enabled: enabled,
                minLines: 1,
                maxLines: 3,
                style: TextStyle(color: style.text, fontSize: 13),
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: connectionState.isConnected
                      ? chat.capabilities.canSendMessage
                            ? strings.messageHint
                            : strings.readOnly
                      : strings.chatState(connectionState.name),
                  hintStyle: TextStyle(fontSize: 12, color: style.textMuted),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                onSubmitted: enabled ? (_) => _sendChat(chat) : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            height: 40,
            child: FilledButton(
              key: const ValueKey('chat-send-button'),
              onPressed: enabled ? () => _sendChat(chat) : null,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    RealtimeUiTokens.compactRadius,
                  ),
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
}
