import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'media_provider_label.dart';
import 'realtime_strings.dart';
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
    this.chatModeration,
    this.config = const MediaRoomViewConfig(),
    this.header,
    this.participantBuilder,
    this.onLeave,
  });
  final MediaRoomSession room;
  final MediaTrackRenderer renderer;
  final ChatSession? chatSession;
  final ChatModeration? chatModeration;
  final MediaRoomViewConfig config;
  final Widget? header;
  final MediaParticipantBuilder? participantBuilder;
  final VoidCallback? onLeave;
  @override
  State<MediaRoomView> createState() => _MediaRoomViewState();
}

class _MediaRoomViewState extends State<MediaRoomView> {
  final _message = TextEditingController();
  final _rtcDataMessage = TextEditingController();
  final _chatScroll = ScrollController();
  StreamSubscription<List<ChatMessage>>? _chatUnreadSub;
  Timer? _timer;
  int _seconds = 0;
  int _lastChatMessageCount = 0;
  int _seenChatMessageCount = 0;
  int _unreadChatCount = 0;
  bool _chatOpen = false;
  bool _chatSending = false;
  bool _rtcDataOpen = false;
  bool _copied = false;
  bool _screenShareExpanded = false;
  String? _focusedParticipantId;
  String? _error;
  MediaSession get session => widget.room.session;

  @override
  void initState() {
    super.initState();
    _watchUnreadChat();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  @override
  void didUpdateWidget(covariant MediaRoomView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chatSession != widget.chatSession) {
      _watchUnreadChat();
    }
  }

  void _watchUnreadChat() {
    _chatUnreadSub?.cancel();
    final chat = widget.chatSession;
    _seenChatMessageCount = chat?.messages.length ?? 0;
    _unreadChatCount = 0;
    if (chat == null) return;
    _chatUnreadSub = chat.messageSnapshots.listen((messages) {
      if (!mounted) return;
      final newMessageCount = messages.length - _seenChatMessageCount;
      _seenChatMessageCount = messages.length;
      if (_chatOpen || newMessageCount <= 0) return;
      setState(() => _unreadChatCount += newMessageCount);
    });
  }

  Future<void> _showRoomManagement() async {
    final mediaCapabilities = widget.room.managementCapabilities;
    final chatModeration = widget.chatModeration;
    final chatCapabilities = chatModeration is ChatModerationCapabilitySource
        ? (chatModeration as ChatModerationCapabilitySource)
              .moderationCapabilities
        : const ChatManagementCapabilities();
    List<MediaRoomParticipantSummary> mediaParticipants = const [];
    List<ChatMember> chatMembers = const [];
    final loadErrors = <Object>[];
    if (mediaCapabilities.listParticipants.supported) {
      try {
        mediaParticipants = await widget.room.listParticipants();
      } catch (error) {
        loadErrors.add(error);
      }
    }
    if (chatModeration != null && chatCapabilities.listMembers.supported) {
      try {
        chatMembers = await chatModeration.listMembers();
      } catch (error) {
        loadErrors.add(error);
      }
    }
    if (!mounted) return;
    final strings = RealtimeStrings.of(context);
    final members = _mergeManagedMembers(
      mediaParticipants,
      chatMembers,
      localMediaParticipantId: widget.room.participantId,
      localChatUserId: widget.chatSession is ChatSessionIdentity
          ? (widget.chatSession as ChatSessionIdentity).localUserId
          : null,
    );
    await showRealtimeGlassBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RealtimeSheetHeader(
                title: strings.roomMembers,
                subtitle: strings.roomManagementSubtitle(
                  widget.room.providerId,
                  strings.roleLabel(widget.room.role.name),
                ),
              ),
              if (loadErrors.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    loadErrors.map((error) => error.toString()).join('\n'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (members.isEmpty && loadErrors.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 18, bottom: 4),
                  child: Text(
                    strings.noManagedMembers,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: RealtimeUiTokens.textMuted),
                  ),
                ),
              if (members.isNotEmpty) ...[
                const SizedBox(height: 14),
                ...members.map(
                  (member) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(
                        RealtimeUiTokens.controlRadius,
                      ),
                      border: Border.all(color: RealtimeUiTokens.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CircleAvatar(
                          backgroundColor: RealtimeUiTokens.primarySubtle,
                          child: Icon(
                            Icons.person_outline,
                            color: RealtimeUiTokens.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      member.displayName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (member.isSelf)
                                    RealtimePill(
                                      label: strings.you,
                                      foreground: RealtimeUiTokens.primary,
                                      background:
                                          RealtimeUiTokens.primarySubtle,
                                      borderColor:
                                          RealtimeUiTokens.primaryBorder,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                member.roleLabel(strings),
                                style: const TextStyle(
                                  color: RealtimeUiTokens.textMuted,
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  if (member.media != null)
                                    RealtimePill(
                                      label: strings.mediaOnline,
                                      icon: Icons.videocam_outlined,
                                      foreground: const Color(0xFF047857),
                                      background: const Color(0xFFECFDF5),
                                      borderColor: const Color(0xFFA7F3D0),
                                    ),
                                  if (member.chat != null)
                                    RealtimePill(
                                      label: strings.chatOnline,
                                      icon: Icons.forum_outlined,
                                      foreground: RealtimeUiTokens.primary,
                                      background:
                                          RealtimeUiTokens.primarySubtle,
                                      borderColor:
                                          RealtimeUiTokens.primaryBorder,
                                    ),
                                ],
                              ),
                              if (!member.isSelf) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    if (member.media != null)
                                      OutlinedButton.icon(
                                        onPressed:
                                            mediaCapabilities
                                                .removeParticipant
                                                .supported
                                            ? () async {
                                                Navigator.pop(sheetContext);
                                                await _run(
                                                  () => widget.room
                                                      .removeParticipant(
                                                        member
                                                            .media!
                                                            .participantId,
                                                      ),
                                                );
                                              }
                                            : null,
                                        icon: const Icon(
                                          Icons.person_remove_outlined,
                                          size: 17,
                                        ),
                                        label: Text(strings.removeFromMedia),
                                      ),
                                    if (member.media != null &&
                                        mediaCapabilities
                                            .muteParticipant
                                            .supported)
                                      OutlinedButton.icon(
                                        onPressed: () async {
                                          Navigator.pop(sheetContext);
                                          await _run(
                                            () => widget.room.muteParticipant(
                                              member.media!.participantId,
                                            ),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.mic_off_outlined,
                                          size: 17,
                                        ),
                                        label: Text(strings.muteParticipant),
                                      ),
                                    if (member.media != null &&
                                        mediaCapabilities
                                            .stopParticipantVideo
                                            .supported)
                                      OutlinedButton.icon(
                                        onPressed: () async {
                                          Navigator.pop(sheetContext);
                                          await _run(
                                            () => widget.room
                                                .stopParticipantVideo(
                                                  member.media!.participantId,
                                                ),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.videocam_off_outlined,
                                          size: 17,
                                        ),
                                        label: Text(
                                          strings.stopParticipantVideo,
                                        ),
                                      ),
                                    if (member.chat != null &&
                                        chatModeration != null)
                                      OutlinedButton.icon(
                                        onPressed:
                                            chatCapabilities
                                                .removeMember
                                                .supported
                                            ? () async {
                                                Navigator.pop(sheetContext);
                                                await _run(
                                                  () => chatModeration
                                                      .removeMember(
                                                        member.chat!.userId,
                                                      ),
                                                );
                                              }
                                            : null,
                                        icon: const Icon(
                                          Icons.forum_outlined,
                                          size: 17,
                                        ),
                                        label: Text(strings.removeFromChat),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (chatModeration != null &&
                  chatCapabilities.closeRoom.supported) ...[
                const SizedBox(height: 12),
                RealtimeDangerButton(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await _run(chatModeration.closeRoom);
                  },
                  icon: Icons.forum_outlined,
                  label: strings.closeChatRoom,
                ),
              ],
              if (mediaCapabilities.closeRoom.supported) ...[
                const SizedBox(height: 12),
                RealtimeDangerButton(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await _run(widget.room.closeRoom);
                    if (mounted) widget.onLeave?.call();
                  },
                  icon: Icons.stop_circle_outlined,
                  label: strings.closeRoomForEveryone,
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
    _chatUnreadSub?.cancel();
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
      final strings = RealtimeStrings.of(context);
      leave =
          await showDialog<bool>(
            context: context,
            barrierColor: const Color(0xFF0F172A).withValues(alpha: 0.34),
            builder: (context) => RealtimeGlassDialog(
              icon: Icons.call_end_rounded,
              iconColor: RealtimeUiTokens.danger,
              iconBackground: RealtimeUiTokens.dangerSubtle,
              title: Text(strings.leaveRoomTitle),
              content: Text(
                strings.leaveRoomConfirmation,
                style: const TextStyle(
                  color: RealtimeUiTokens.textMuted,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(strings.cancel),
                ),
                RealtimeGlassPressable(
                  borderRadius: RealtimeUiTokens.controlRadius,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: RealtimeUiTokens.danger,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.controlRadius,
                        ),
                      ),
                    ),
                    child: Text(strings.leave),
                  ),
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
                    if (widget.header != null) widget.header!,
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
        if (_chatOpen && chat != null)
          SizedBox(
            key: const ValueKey('chat-panel-wide'),
            width: (constraints.maxWidth * .31).clamp(320.0, 420.0),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: RealtimeUiTokens.animNormal,
              curve: Curves.easeOutCubic,
              builder: (context, progress, child) => Opacity(
                opacity: progress,
                child: Transform.translate(
                  offset: Offset((1 - progress) * 16, 0),
                  child: child,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
                child: _productChat(chat),
              ),
            ),
          ),
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
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: RealtimeUiTokens.animNormal,
              curve: Curves.easeOutCubic,
              builder: (context, progress, child) => Opacity(
                opacity: progress,
                child: Transform.translate(
                  offset: Offset(0, (1 - progress) * 14),
                  child: child,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
                child: _productChat(chat),
              ),
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
    final strings = RealtimeStrings.of(context);
    final mm = (_seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (_seconds % 60).toString().padLeft(2, '0');
    return RealtimeGlassSurface(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      radius: RealtimeUiTokens.dockRadius,
      opacity: .86,
      child: Row(
        children: [
          RealtimeGlassIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onPressed: _leave,
            size: 40,
            radius: RealtimeUiTokens.compactRadius,
          ),
          const SizedBox(width: 10),
          RealtimePill(
            label: widget.room.roomCode,
            icon: _copied ? Icons.check_rounded : Icons.copy_rounded,
            foreground: _copied
                ? RealtimeUiTokens.success
                : RealtimeUiTokens.text,
            background: _copied
                ? RealtimeUiTokens.successSubtle
                : RealtimeUiTokens.surfaceSubtle,
            borderColor: _copied
                ? RealtimeUiTokens.successBorder
                : RealtimeUiTokens.border,
            onTap: _copyCode,
          ),
          if (widget.config.showProvider && !compact) ...[
            const SizedBox(width: 8),
            _providerBadge(widget.room.providerId),
          ],
          const Spacer(),
          if (!compact) ...[
            RealtimePill(
              label: '$mm:$ss',
              leadingDotColor: _seconds.isEven
                  ? const Color(0xFF10B981)
                  : const Color(0xFF34D399),
            ),
            const SizedBox(width: 8),
          ],
          if ((widget.room.roomOwnerCredential?.isNotEmpty ?? false) ||
              (widget.room.role == MediaRole.host &&
                  (widget
                          .room
                          .managementCapabilities
                          .listParticipants
                          .supported ||
                      widget.room.managementCapabilities.closeRoom.supported)))
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: RealtimeGlassIconButton(
                tooltip: strings.manageRoom,
                onPressed: _showRoomManagement,
                icon: Icons.admin_panel_settings_outlined,
                size: 40,
                radius: RealtimeUiTokens.compactRadius,
              ),
            ),
          _badge('${value.participants.length}', Icons.people_outline_rounded),
        ],
      ),
    );
  }

  Widget _providerBadge(String id) {
    final presentation = mediaProviderPresentation(id);
    return RealtimePill(
      label: presentation.label,
      icon: Icons.hub_outlined,
      foreground: presentation.foreground,
      background: presentation.background,
      borderColor: presentation.border,
    );
  }

  Widget _badge(String text, IconData icon) =>
      RealtimePill(label: text, icon: icon);

  Widget _errorView() => RealtimeGlassSurface(
    margin: const EdgeInsets.fromLTRB(12, 6, 12, 2),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    radius: RealtimeUiTokens.controlRadius,
    fillColor: RealtimeUiTokens.dangerSubtle,
    borderColor: RealtimeUiTokens.dangerBorder,
    opacity: .92,
    shadow: false,
    child: Row(
      children: [
        const Icon(
          Icons.error_outline_rounded,
          size: 18,
          color: RealtimeUiTokens.danger,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _error!,
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFFB91C1C),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          onPressed: () => setState(() => _error = null),
          icon: const Icon(
            Icons.close_rounded,
            size: 16,
            color: Color(0xFFB91C1C),
          ),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    ),
  );

  Widget _waiting() {
    final strings = RealtimeStrings.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: RealtimeGlassSurface(
          radius: RealtimeUiTokens.sheetRadius,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
          opacity: 0.84,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOut,
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RealtimeUiTokens.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: RealtimeUiTokens.primary.withValues(
                        alpha: _seconds.isEven ? 0.32 : 0.16,
                      ),
                      blurRadius: _seconds.isEven ? 24 : 14,
                      spreadRadius: _seconds.isEven ? 3 : 0,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.wifi_tethering_rounded,
                  size: 36,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                strings.onlyOneHere,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: RealtimeUiTokens.text,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                strings.shareRoomCode,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: RealtimeUiTokens.textMuted,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 18),
              RealtimeGlassButton(
                onPressed: _copyCode,
                icon: _copied ? Icons.check_rounded : Icons.copy_rounded,
                child: Text(
                  _copied
                      ? strings.copied
                      : strings.copyRoom(widget.room.roomCode),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grid(MediaSnapshot value) => LayoutBuilder(
    builder: (context, constraints) {
      final participants = value.participants;
      final count = participants.length;
      final focused = count > 1 && _focusedParticipantId != null
          ? participants.where((p) => p.id == _focusedParticipantId).firstOrNull
          : null;

      if (focused != null) {
        final others = participants
            .where((p) => p.id != focused.id)
            .toList(growable: false);
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          child: Column(
            children: [
              Expanded(
                flex: 3,
                child: _buildParticipantWidget(
                  focused,
                  isFocused: true,
                  canFocus: true,
                ),
              ),
              if (others.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: others.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) => AspectRatio(
                      aspectRatio: 4 / 3,
                      child: _buildParticipantWidget(
                        others[index],
                        isFocused: false,
                        canFocus: true,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      }

      final columns = constraints.maxWidth > 900
          ? (count <= 4 ? 2 : 3)
          : constraints.maxWidth > 600
          ? (count <= 2 ? 2 : 3)
          : (count == 1 ? 1 : 2);
      return GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          childAspectRatio: count == 1 ? 4 / 3 : 1,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: count,
        itemBuilder: (context, index) {
          final participant = participants[index];
          return _buildParticipantWidget(
            participant,
            isFocused: false,
            canFocus: count > 1,
          );
        },
      );
    },
  );

  Widget _buildParticipantWidget(
    MediaParticipant participant, {
    required bool isFocused,
    required bool canFocus,
  }) {
    if (widget.participantBuilder != null) {
      return widget.participantBuilder!(context, participant, widget.renderer);
    }
    return MediaParticipantTile(
      participant: participant,
      renderer: widget.renderer,
      isFocused: isFocused,
      onTap: canFocus
          ? () => setState(() {
              _focusedParticipantId = _focusedParticipantId == participant.id
                  ? null
                  : participant.id;
            })
          : null,
    );
  }

  Widget _screenShare(MediaSnapshot value) {
    final strings = RealtimeStrings.of(context);
    return AnimatedContainer(
      duration: RealtimeUiTokens.animNormal,
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      height: _screenShareExpanded ? 260 : 168,
      decoration: BoxDecoration(
        gradient: RealtimeUiTokens.glassGradient(opacity: 0.90),
        borderRadius: BorderRadius.circular(RealtimeUiTokens.cardRadius),
        border: Border.all(color: RealtimeUiTokens.border, width: 1.1),
        boxShadow: RealtimeUiTokens.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(RealtimeUiTokens.cardRadius - 2),
        child: Stack(
          fit: StackFit.expand,
          children: [
            MediaTrackView(
              renderer: widget.renderer,
              track: value.contentShareTrack,
            ),
            Positioned(
              left: 10,
              right: 10,
              top: 10,
              child: Row(
                children: [
                  RealtimePill(
                    label: strings.screenShare,
                    icon: Icons.present_to_all_rounded,
                    foreground: RealtimeUiTokens.primary,
                    background: Colors.white.withValues(alpha: 0.90),
                    borderColor: RealtimeUiTokens.primaryBorder,
                  ),
                  const Spacer(),
                  RealtimeGlassIconButton(
                    tooltip: _screenShareExpanded
                        ? strings.compactStage
                        : strings.expandStage,
                    icon: _screenShareExpanded
                        ? Icons.close_fullscreen_rounded
                        : Icons.open_in_full_rounded,
                    size: 34,
                    radius: RealtimeUiTokens.compactRadius,
                    onPressed: () => setState(
                      () => _screenShareExpanded = !_screenShareExpanded,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
            opacity: .90,
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
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: RealtimeUiTokens.primarySubtle,
                borderRadius: BorderRadius.circular(
                  RealtimeUiTokens.compactRadius,
                ),
                border: Border.all(color: RealtimeUiTokens.primaryBorder),
              ),
              child: const Icon(
                Icons.forum_outlined,
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
                      Text(
                        RealtimeStrings.of(context).chat,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: RealtimeUiTokens.text,
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
                            color: RealtimeUiTokens.primarySubtle,
                            borderRadius: BorderRadius.circular(
                              RealtimeUiTokens.pillRadius,
                            ),
                          ),
                          child: Text(
                            '$messageCount',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: RealtimeUiTokens.primary,
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
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: RealtimeUiTokens.textMuted,
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
              icon: const Icon(Icons.close_rounded, size: 19),
            ),
          ],
        ),
      );

  Widget _emptyChat() {
    final strings = RealtimeStrings.of(context);
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
                color: RealtimeUiTokens.primarySubtle,
                borderRadius: BorderRadius.circular(
                  RealtimeUiTokens.compactRadius,
                ),
              ),
              child: const Icon(
                Icons.forum_outlined,
                size: 22,
                color: RealtimeUiTokens.primary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              strings.noMessagesYet,
              style: const TextStyle(
                fontSize: 12.5,
                color: RealtimeUiTokens.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              strings.startConversation,
              style: const TextStyle(
                fontSize: 11,
                color: RealtimeUiTokens.textMuted,
              ),
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
    if (message.type != 'message') {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: RealtimeUiTokens.surfaceSubtle,
            borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
            border: Border.all(color: RealtimeUiTokens.border),
          ),
          child: Text(
            message.message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10.5,
              color: RealtimeUiTokens.textMuted,
            ),
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
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: RealtimeUiTokens.textMuted,
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
                  color: own ? null : Colors.white.withValues(alpha: 0.90),
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
                  border: own
                      ? null
                      : Border.all(color: RealtimeUiTokens.border),
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
    final strings = RealtimeStrings.of(context);
    final enabled =
        connectionState.isConnected &&
        chat.capabilities.canSendMessage &&
        !_chatSending;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        border: const Border(top: BorderSide(color: RealtimeUiTokens.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(
                  RealtimeUiTokens.controlRadius,
                ),
                border: Border.all(color: RealtimeUiTokens.border),
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
                            ? strings.messageHint
                            : strings.readOnly
                      : strings.chatState(connectionState.name),
                  hintStyle: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                  ),
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
    setState(() {
      _chatOpen = !_chatOpen;
      if (_chatOpen) {
        _unreadChatCount = 0;
        _seenChatMessageCount = widget.chatSession?.messages.length ?? 0;
      }
    });
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
    final strings = RealtimeStrings.of(context);
    return RealtimeGlassSurface(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      radius: RealtimeUiTokens.controlRadius,
      opacity: .88,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: RealtimePill(
              label: strings.rtcData,
              foreground: RealtimeUiTokens.primary,
              background: RealtimeUiTokens.primarySubtle,
              borderColor: RealtimeUiTokens.primaryBorder,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _rtcDataMessage,
              decoration: InputDecoration(
                hintText: strings.debugDataPayload,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              onSubmitted: (_) => _sendRtcData(),
            ),
          ),
          IconButton(
            onPressed: _sendRtcData,
            icon: const Icon(
              Icons.send_rounded,
              color: RealtimeUiTokens.primary,
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      radius: RealtimeUiTokens.dockRadius,
      opacity: .88,
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
                badgeCount: _unreadChatCount,
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

  Widget _control(
    IconData icon,
    VoidCallback action, {
    bool active = false,
    bool endCall = false,
    int badgeCount = 0,
  }) => RealtimeGlassIconButton(
    icon: icon,
    onPressed: action,
    active: active,
    danger: endCall,
    badgeCount: badgeCount,
    size: 46,
    radius: RealtimeUiTokens.controlRadius,
  );
}

class _ManagedRoomMember {
  const _ManagedRoomMember({
    required this.userId,
    required this.displayName,
    this.media,
    this.chat,
    required this.isSelf,
  });

  final String userId;
  final String displayName;
  final MediaRoomParticipantSummary? media;
  final ChatMember? chat;
  final bool isSelf;

  String roleLabel(RealtimeStrings strings) {
    final mediaRole = media?.role?.wireName;
    final chatRole = chat?.role.name;
    final value = mediaRole ?? chatRole ?? 'participant';
    return strings.roleLabel(value);
  }
}

List<_ManagedRoomMember> _mergeManagedMembers(
  List<MediaRoomParticipantSummary> media,
  List<ChatMember> chat, {
  required String localMediaParticipantId,
  String? localChatUserId,
}) {
  final mediaByKey = <String, MediaRoomParticipantSummary>{};
  final chatByKey = <String, ChatMember>{};
  final orderedKeys = <String>[];

  String mediaKey(MediaRoomParticipantSummary item) =>
      item.userId.trim().isNotEmpty
      ? item.userId.trim()
      : 'media:${item.participantId}';

  for (final item in media) {
    final key = mediaKey(item);
    mediaByKey[key] = item;
    if (!orderedKeys.contains(key)) orderedKeys.add(key);
  }
  for (final item in chat) {
    final key = item.userId.trim();
    if (key.isEmpty) continue;
    chatByKey[key] = item;
    if (!orderedKeys.contains(key)) orderedKeys.add(key);
  }

  return orderedKeys
      .map((key) {
        final mediaMember = mediaByKey[key];
        final chatMember = chatByKey[key];
        final rawName = mediaMember?.displayName.trim().isNotEmpty == true
            ? mediaMember!.displayName.trim()
            : chatMember?.displayName.trim().isNotEmpty == true
            ? chatMember!.displayName.trim()
            : key;
        final selfByMedia =
            mediaMember?.participantId == localMediaParticipantId;
        final selfByChat =
            localChatUserId != null &&
            localChatUserId.isNotEmpty &&
            chatMember?.userId == localChatUserId;
        return _ManagedRoomMember(
          userId: key,
          displayName: rawName,
          media: mediaMember,
          chat: chatMember,
          isSelf: selfByMedia || selfByChat,
        );
      })
      .toList(growable: false);
}

class MediaParticipantTile extends StatelessWidget {
  const MediaParticipantTile({
    super.key,
    required this.participant,
    required this.renderer,
    this.isFocused = false,
    this.onTap,
  });
  final MediaParticipant participant;
  final MediaTrackRenderer renderer;
  final bool isFocused;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final strings = RealtimeStrings.of(context);
    final name = participant.displayName.isEmpty
        ? strings.participant
        : participant.displayName;
    final speaking = participant.isSpeaking;

    Widget tile = AnimatedContainer(
      duration: RealtimeUiTokens.animNormal,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: RealtimeUiTokens.glassGradient(opacity: 0.90),
        borderRadius: BorderRadius.circular(RealtimeUiTokens.cardRadius),
        border: Border.all(
          color: speaking
              ? const Color(0xFF10B981)
              : isFocused
              ? RealtimeUiTokens.primary
              : RealtimeUiTokens.border,
          width: speaking || isFocused ? 2.2 : 1.1,
        ),
        boxShadow: speaking
            ? [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.22),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ]
            : RealtimeUiTokens.cardShadow,
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
                color: RealtimeUiTokens.background,
                alignment: Alignment.center,
                child: AnimatedContainer(
                  duration: RealtimeUiTokens.animNormal,
                  padding: EdgeInsets.all(speaking ? 8 : 0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: speaking
                        ? Border.all(
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.45),
                            width: 2.5,
                          )
                        : null,
                  ),
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: RealtimeUiTokens.primarySubtle,
                    child: Text(
                      name.characters.first.toUpperCase(),
                      style: const TextStyle(
                        color: RealtimeUiTokens.primary,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            if (onTap != null)
              Positioned(
                top: 10,
                right: 10,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    RealtimeUiTokens.pillRadius,
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.76),
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.pillRadius,
                        ),
                        border: Border.all(color: RealtimeUiTokens.border),
                      ),
                      child: Icon(
                        isFocused
                            ? Icons.grid_view_rounded
                            : Icons.open_in_full_rounded,
                        size: 13,
                        color: RealtimeUiTokens.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  RealtimeUiTokens.compactRadius,
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: RealtimeUiTokens.subtleBlur,
                    sigmaY: RealtimeUiTokens.subtleBlur,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .84),
                      borderRadius: BorderRadius.circular(
                        RealtimeUiTokens.compactRadius,
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.90),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$name${participant.isLocal ? strings.youSuffix : ''}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: RealtimeUiTokens.text,
                            ),
                          ),
                        ),
                        Icon(
                          participant.isMuted
                              ? Icons.mic_off_rounded
                              : Icons.mic_rounded,
                          size: 15,
                          color: participant.isMuted
                              ? RealtimeUiTokens.danger
                              : speaking
                              ? const Color(0xFF10B981)
                              : RealtimeUiTokens.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (onTap != null) {
      tile = RealtimeGlassPressable(
        onTap: onTap,
        pressedScale: 0.985,
        borderRadius: RealtimeUiTokens.cardRadius,
        child: tile,
      );
    }
    return tile;
  }
}
