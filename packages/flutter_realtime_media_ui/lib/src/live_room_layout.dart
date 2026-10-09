import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';

import 'media_room_layout_host.dart';
import 'room_regions.dart';
import 'realtime_strings.dart';
import 'realtime_style.dart';
import 'realtime_ui_style.dart';

/// Immersive livestream layout mimicking Douyin, TikTok Live, and Twitch.
class LiveRoomViewLayout extends StatelessWidget {
  const LiveRoomViewLayout({
    required this.host,
    required this.snapshot,
    required this.constraints,
  });

  final MediaRoomLayoutHost host;
  final MediaSnapshot snapshot;
  final BoxConstraints constraints;

  @override
  Widget build(BuildContext context) {
    final strings = RealtimeStrings.of(context);
    final isHost = host.view.room.role == MediaRole.host;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (host.cleanScreen) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: RealtimeAmbientBackground(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: host.toggleCleanScreen,
            child: Stack(
              fit: StackFit.expand,
              children: [
                host.mediaStage(snapshot),
                Positioned(
                  top: 16,
                  right: 16,
                  child: SafeArea(
                    child: RealtimePill(
                      label: strings.exitCleanScreen,
                      icon: Icons.fullscreen_exit_rounded,
                      foreground: isDark ? Colors.white : RealtimeUiTokens.text,
                      background: isDark
                          ? Colors.black.withValues(alpha: 0.65)
                          : Colors.white.withValues(alpha: 0.85),
                      borderColor: isDark
                          ? Colors.white.withValues(alpha: 0.35)
                          : RealtimeUiTokens.border,
                      onTap: host.toggleCleanScreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RealtimeAmbientBackground(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Fullscreen Video Canvas with tap-to-like
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: host.sendLike,
              onDoubleTap: () {
                host.sendLike();
                host.sendLike();
              },
              child: host.mediaStage(snapshot),
            ),

            // 2. Top Scrim Gradient for text contrast
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 140,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              Colors.black.withValues(alpha: 0.70),
                              Colors.transparent,
                            ]
                          : [
                              Colors.white.withValues(alpha: 0.70),
                              Colors.transparent,
                            ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),

            // 3. Bottom Scrim Gradient for danmaku & control contrast
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 260,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.85),
                            ]
                          : [
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.85),
                            ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),

            // 4. Floating Hearts Particle Layer
            Positioned.fill(
              child: RoomRegion(
                revision: host.likeRevision,
                builder: (_) => Stack(children: [host.floatingHeartsOverlay()]),
              ),
            ),

            // 5. HUD Top Bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: _LiveTopBar(
                  host: host,
                  snapshot: snapshot,
                  isHost: isHost,
                ),
              ),
            ),

            // 6. Header extension if supplied
            if (host.view.header != null)
              Positioned(
                top: 70,
                left: 12,
                right: 12,
                child: SafeArea(top: false, child: host.view.header!),
              ),

            // 7. Connection Banner
            if (snapshot.state == MediaSessionState.reconnecting ||
                snapshot.state == MediaSessionState.failed ||
                snapshot.state == MediaSessionState.ended)
              Positioned(
                top: 80,
                left: 16,
                right: 16,
                child: host.connectionBanner(snapshot.state),
              ),

            // 8. Bottom-Left Floating Danmaku Stream
            Positioned(
              left: 14,
              bottom: 84,
              width: math.min(320.0, constraints.maxWidth * 0.72),
              child: _LiveFloatingDanmakuFeed(host: host),
            ),

            // 9. Bottom Interaction Dock
            Positioned(
              left: 12,
              right: 12,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: RoomRegion(
                  revision: host.controlRevision,
                  builder: (_) => _LiveBottomControls(
                    host: host,
                    snapshot: snapshot,
                    isHost: isHost,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating live top bar with anchor capsule, viewer count, and close button.
class _LiveTopBar extends StatelessWidget {
  const _LiveTopBar({
    required this.host,
    required this.snapshot,
    required this.isHost,
  });

  final MediaRoomLayoutHost host;
  final MediaSnapshot snapshot;
  final bool isHost;

  @override
  Widget build(BuildContext context) {
    final strings = RealtimeStrings.of(context);
    final roomCode = host.view.room.roomCode;
    final viewerCount = snapshot.participants.length;
    final style = RealtimeStyle.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Anchor capsule: Avatar + LIVE pill + Room code
          Container(
            padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
            decoration: BoxDecoration(
              color: style.isDark
                  ? Colors.black.withValues(alpha: 0.65)
                  : Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
              border: Border.all(
                color: style.isDark
                    ? Colors.white.withValues(alpha: 0.20)
                    : style.border,
                width: 1,
              ),
              boxShadow: style.isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Anchor avatar
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFFF43F5E), Color(0xFFFB923C)],
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.person_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE11D48),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          strings.liveStatus,
                          style: const TextStyle(
                            fontSize: 7.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      strings.liveStream,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: style.text,
                      ),
                    ),
                    Text(
                      roomCode,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: style.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Viewers online count pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: style.isDark
                  ? Colors.black.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
              border: Border.all(
                color: style.isDark
                    ? Colors.white.withValues(alpha: 0.20)
                    : style.border,
                width: 1,
              ),
              boxShadow: style.isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.visibility_rounded,
                  size: 13,
                  color: style.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  strings.viewingCount(viewerCount),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: style.text,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Clean Screen button
          RealtimeGlassIconButton(
            tooltip: strings.cleanScreen,
            icon: Icons.fullscreen_rounded,
            size: 36,
            radius: RealtimeUiTokens.pillRadius,
            onPressed: host.toggleCleanScreen,
          ),

          const SizedBox(width: 8),

          // Close button
          RealtimeGlassIconButton(
            tooltip: isHost ? strings.endBroadcast : strings.leaveLiveRoom,
            icon: Icons.close_rounded,
            size: 36,
            radius: RealtimeUiTokens.pillRadius,
            danger: isHost,
            onPressed: isHost ? host.showLiveHostLeaveConfirmation : host.leave,
          ),
        ],
      ),
    );
  }
}

/// Floating semi-transparent chat comments stream in livestream.
class _LiveFloatingDanmakuFeed extends StatelessWidget {
  const _LiveFloatingDanmakuFeed({required this.host});

  final MediaRoomLayoutHost host;

  @override
  Widget build(BuildContext context) {
    final chat = host.view.chatSession;
    if (chat == null) return const SizedBox.shrink();

    return ValueListenableBuilder<List<ChatMessage>>(
      valueListenable: host.chatMessages,
      builder: (context, messages, _) {
        if (messages.isEmpty) return const SizedBox.shrink();

        final recent = messages.length > 5
            ? messages.sublist(messages.length - 5)
            : messages;

        final identity = chat is ChatSessionIdentity
            ? chat as ChatSessionIdentity
            : null;
        final myId = identity?.localUserId;
        final strings = RealtimeStrings.of(context);

        final isDark = Theme.of(context).brightness == Brightness.dark;
        return ShaderMask(
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [Colors.transparent, Colors.white],
            stops: const [0.0, 0.25],
          ).createShader(rect),
          blendMode: BlendMode.dstIn,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: recent.map((m) {
              final isOwn = m.userId == myId;
              final isAnchor =
                  m.userId == host.view.room.participantId &&
                  host.view.room.role == MediaRole.host;

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.55)
                      : Colors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : RealtimeUiTokens.border,
                    width: 0.8,
                  ),
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: RichText(
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    children: [
                      if (isAnchor)
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Container(
                            margin: const EdgeInsets.only(right: 5),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              strings.anchorTag,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                      else if (isOwn)
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Container(
                            margin: const EdgeInsets.only(right: 5),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              strings.meTag,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      TextSpan(
                        text:
                            '${m.displayName.isEmpty ? m.userId : m.displayName}: ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isAnchor
                              ? const Color(0xFFD97706)
                              : isOwn
                              ? const Color(0xFF0284C7)
                              : (isDark
                                    ? const Color(0xFFCBD5E1)
                                    : RealtimeUiTokens.text),
                        ),
                      ),
                      TextSpan(
                        text: m.message,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : RealtimeUiTokens.text,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

/// Bottom interaction controls in livestream: comment pill, gift button, like button.
class _LiveBottomControls extends StatelessWidget {
  const _LiveBottomControls({
    required this.host,
    required this.snapshot,
    required this.isHost,
  });

  final MediaRoomLayoutHost host;
  final MediaSnapshot snapshot;
  final bool isHost;

  @override
  Widget build(BuildContext context) {
    final strings = RealtimeStrings.of(context);
    final style = RealtimeStyle.of(context);
    final isDark = style.isDark;
    final interactive = host.session is InteractiveMediaSession
        ? host.session as InteractiveMediaSession
        : null;
    final caps = snapshot.capabilities;
    final chatSession = host.view.chatSession;
    final inputOpen = host.liveChatInputOpen && chatSession != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (inputOpen) _LiveInlineChatInput(host: host, chat: chatSession),
          if (inputOpen) const SizedBox(height: 8),
          Row(
            children: [
              // "Say something..." input capsule trigger
              Expanded(
                child: InkWell(
                  onTap: inputOpen
                      ? host.hideLiveChatInput
                      : host.showLiveChatInputSheet,
                  borderRadius: BorderRadius.circular(
                    RealtimeUiTokens.pillRadius,
                  ),
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.52)
                          : style.surface.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(
                        RealtimeUiTokens.pillRadius,
                      ),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.20)
                            : style.border,
                        width: 1,
                      ),
                      boxShadow: isDark
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 16,
                          color: isDark ? Colors.white70 : style.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            strings.sendComment,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white60 : style.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

          const SizedBox(width: 8),

          if (isHost && interactive != null && caps.canPublishAudio) ...[
            RealtimeGlassIconButton(
              tooltip: snapshot.localMuted ? strings.unmute : strings.mute,
              icon: snapshot.localMuted
                  ? Icons.mic_off_rounded
                  : Icons.mic_rounded,
              size: 40,
              radius: RealtimeUiTokens.pillRadius,
              danger: snapshot.localMuted,
              active: !snapshot.localMuted,
              onPressed: () => host.runAction(interactive.toggleMute),
            ),
            const SizedBox(width: 8),
          ],

              // Host tool: Camera Toggle
              if (isHost && interactive != null && caps.canPublishVideo) ...[
                RealtimeGlassIconButton(
                  tooltip: snapshot.localVideoEnabled
                      ? strings.stopVideo
                      : strings.startVideo,
                  icon: snapshot.localVideoEnabled
                      ? Icons.videocam_rounded
                      : Icons.videocam_off_rounded,
                  size: 40,
                  radius: RealtimeUiTokens.pillRadius,
                  danger: !snapshot.localVideoEnabled,
                  active: snapshot.localVideoEnabled,
                  onPressed: () => host.runAction(
                    () => interactive.setVideoEnabled(
                      !snapshot.localVideoEnabled,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Host tool: Switch Camera
              if (isHost &&
                  interactive != null &&
                  caps.canSwitchCamera &&
                  snapshot.localVideoEnabled) ...[
                RealtimeGlassIconButton(
                  tooltip: strings.switchCamera,
                  icon: Icons.cameraswitch_rounded,
                  size: 40,
                  radius: RealtimeUiTokens.pillRadius,
                  onPressed: () => host.runAction(
                    () => interactive.switchCamera(MediaCameraPosition.back),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Host tool: Virtual Background / Beauty
              if (isHost &&
                  caps.canPublishVideo &&
                  host
                      .backgroundEffects
                      .backgroundCapabilities
                      .isSupported) ...[
                RealtimeGlassIconButton(
                  tooltip: strings.virtualBackground,
                  icon: Icons.auto_fix_high_rounded,
                  size: 40,
                  radius: RealtimeUiTokens.pillRadius,
                  active: host.backgroundEffects.backgroundEffect.enabled,
                  onPressed: host.openBackgroundEffects,
                ),
                const SizedBox(width: 8),
              ],

              // Gift Button (Viewer & Host if custom)
              if (!isHost ||
                  host.view.liveGiftPanelOpener != null ||
                  host.view.extraControlsBuilder != null) ...[
                RealtimeGlassIconButton(
                  tooltip: strings.sendGift,
                  icon: Icons.card_giftcard_rounded,
                  size: 40,
                  radius: RealtimeUiTokens.pillRadius,
                  onPressed: () => host.showLiveGiftSheet(),
                ),
              ],

              if (host.view.liveLikes != null) ...[
                const SizedBox(width: 8),
                // Only expose interactions backed by an actual SDK controller.
                Tooltip(
                  message: '${strings.totalLikes} ${host.likeCount}',
                  child: InkWell(
                    onTap: host.sendLike,
                    borderRadius: BorderRadius.circular(
                      RealtimeUiTokens.pillRadius,
                    ),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF2D55), Color(0xFFFF5252)],
                        ),
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.pillRadius,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFFF2D55,
                            ).withValues(alpha: 0.40),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.favorite_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          if (host.likeCount > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              '${host.likeCount}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Inline live chat input rendered directly above the bottom dock.
///
/// Replaces the previous second bottom sheet: tapping the "Say something…"
/// capsule expands this editor in place, so the keyboard no longer lifts a
/// separate sheet that feels like a redundant extra dialog.
class _LiveInlineChatInput extends StatefulWidget {
  const _LiveInlineChatInput({required this.host, required this.chat});

  final MediaRoomLayoutHost host;
  final ChatSession chat;

  @override
  State<_LiveInlineChatInput> createState() => _LiveInlineChatInputState();
}

class _LiveInlineChatInputState extends State<_LiveInlineChatInput> {
  late final TextEditingController _controller = TextEditingController();
  late final FocusNode _focusNode = FocusNode();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.chat.sendMessage(trimmed);
      if (!mounted) return;
      widget.host.hideLiveChatInput();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = RealtimeStrings.of(context);
    final style = RealtimeStyle.of(context);
    final isDark = style.isDark;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.72)
            : style.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.20) : style.border,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: TextStyle(
                color: isDark ? Colors.white : style.text,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: strings.sendComment,
                hintStyle: TextStyle(
                  color: isDark ? Colors.white60 : style.textMuted,
                ),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : style.surfaceSubtle,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: strings.sendComment,
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            style: IconButton.styleFrom(
              backgroundColor: style.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
