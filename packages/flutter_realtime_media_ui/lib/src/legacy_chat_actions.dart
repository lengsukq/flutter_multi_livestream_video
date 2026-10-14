part of 'realtime_chat_view.dart';

mixin _LegacyChatActions on State<RealtimeChatView> {
  ChatUiController get _chatUi;
  TextEditingController get _message;
  bool get _sending;
  set _sending(bool value);
  set _error(String? value);
  ChatMessage? get _replyingTo;
  set _replyingTo(ChatMessage? value);
  bool get _showEmojiDrawer;
  set _showEmojiDrawer(bool value);

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Replying banner
            if (_replyingTo != null)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: RealtimeUiTokens.primarySubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: RealtimeUiTokens.primaryBorder),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.reply_rounded,
                      size: 15,
                      color: RealtimeUiTokens.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${strings.replyTo(_replyingTo!.displayName.isEmpty ? _replyingTo!.userId : _replyingTo!.displayName)}: ${_replyingTo!.message}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: RealtimeUiTokens.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _replyingTo = null),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: RealtimeUiTokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),

            // Quick Replies / Phrases Carousel
            SizedBox(
              height: 28,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: strings.quickReplyPhrases.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final reply = strings.quickReplyPhrases[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: enabled
                        ? () {
                            _message.text = reply;
                            unawaited(_send());
                          }
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: RealtimeUiTokens.border),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        reply,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: RealtimeUiTokens.text,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),

            // Main Input Row
            Row(
              children: <Widget>[
                IconButton(
                  tooltip: 'Emoji',
                  icon: Icon(
                    _showEmojiDrawer
                        ? Icons.keyboard_rounded
                        : Icons.sentiment_satisfied_alt_rounded,
                    size: 22,
                    color: _showEmojiDrawer
                        ? RealtimeUiTokens.primary
                        : RealtimeUiTokens.textMuted,
                  ),
                  onPressed: () => setState(() {
                    _showEmojiDrawer = !_showEmojiDrawer;
                  }),
                ),
                Expanded(
                  child: Focus(
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.enter &&
                          !HardwareKeyboard.instance.isShiftPressed &&
                          !HardwareKeyboard.instance.isControlPressed &&
                          !HardwareKeyboard.instance.isMetaPressed &&
                          !HardwareKeyboard.instance.isAltPressed) {
                        if (enabled) {
                          unawaited(_send());
                          return KeyEventResult.handled;
                        }
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      controller: _message,
                      enabled: enabled,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
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

            // Emoji drawer
            if (_showEmojiDrawer) ...[
              const SizedBox(height: 8),
              Container(
                height: 110,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: RealtimeUiTokens.border),
                ),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  itemCount: _RealtimeChatViewState._drawerEmojis.length,
                  itemBuilder: (context, index) {
                    final em = _RealtimeChatViewState._drawerEmojis[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: enabled
                          ? () {
                              final text = _message.text;
                              _message.text = '$text$em';
                              _message.selection = TextSelection.fromPosition(
                                TextPosition(offset: _message.text.length),
                              );
                            }
                          : null,
                      child: Center(
                        child: Text(em, style: const TextStyle(fontSize: 18)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty || _sending) return;
    final strings = RealtimeStrings.of(context);
    setState(() {
      _sending = true;
      _error = null;
    });
    final session = widget.session;
    try {
      final textToSend = _replyingTo != null
          ? '「${strings.replyTo(_replyingTo!.displayName.isEmpty ? _replyingTo!.userId : _replyingTo!.displayName)}: ${_replyingTo!.message}」\n$text'
          : text;
      await _chatUi.send(textToSend);
      if (mounted && session == widget.session) {
        _message.clear();
        setState(() {
          _replyingTo = null;
          _showEmojiDrawer = false;
        });
      }
    } catch (error) {
      if (mounted && session == widget.session) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && session == widget.session) {
        setState(() => _sending = false);
      }
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(
                  RealtimeUiTokens.compactRadius,
                ),
                border: Border.all(color: RealtimeUiTokens.border),
              ),
              child: Text(
                message.message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: RealtimeUiTokens.text,
                ),
              ),
            ),
            // Quick Emoji reactions bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(
                  RealtimeUiTokens.pillRadius,
                ),
                border: Border.all(color: RealtimeUiTokens.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _RealtimeChatViewState._quickEmojis
                    .map(
                      (emoji) => InkWell(
                        onTap: () {
                          Navigator.pop(sheetContext);
                          unawaited(widget.session.sendMessage(emoji));
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  RealtimeUiTokens.controlRadius,
                ),
              ),
              leading: const Icon(
                Icons.reply_rounded,
                color: RealtimeUiTokens.primary,
              ),
              title: Text(
                strings.quoteReply,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                setState(() => _replyingTo = message);
              },
            ),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  RealtimeUiTokens.controlRadius,
                ),
              ),
              leading: const Icon(
                Icons.copy_rounded,
                color: RealtimeUiTokens.primary,
              ),
              title: Text(
                strings.copyText,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                observeDetached(
                  Clipboard.setData(ClipboardData(text: message.message)),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(strings.messageCopied),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
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
                  await _moderate(() => _chatUi.deleteMessage(message));
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
                  await _moderate(() => _chatUi.removeMember(message.userId));
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
    final controller = _chatUi;
    final capabilities = controller.managementCapabilities;
    final identity = widget.session is ChatSessionIdentity
        ? widget.session as ChatSessionIdentity
        : null;
    List<ChatMember> members = const [];
    Object? loadError;
    if (capabilities.listMembers.supported) {
      try {
        await controller.refreshMembers();
        members = controller.members;
      } catch (error) {
        loadError = error;
      }
    }
    if (!mounted || !identical(controller, _chatUi)) return;
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
                    leading: RealtimeAvatar(
                      name: member.displayName.isEmpty
                          ? member.userId
                          : member.displayName,
                      avatarUrl: member.avatarUrl,
                      size: 36,
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
                                      () => controller.removeMember(
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
                        await _moderate(controller.closeRoom);
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
