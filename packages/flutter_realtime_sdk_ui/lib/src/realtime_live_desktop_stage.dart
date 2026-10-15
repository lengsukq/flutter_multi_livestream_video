import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_live_preset/flutter_realtime_live_preset.dart';

import 'realtime_audience_avatar_row.dart';
import 'realtime_live_chat_feed.dart';
import 'realtime_live_gift_button.dart';
import 'realtime_live_gift_banner.dart';
import 'realtime_live_hearts_overlay.dart';
import 'realtime_live_like_button.dart';
import 'realtime_live_video_stage.dart';
import 'realtime_live_media_controls.dart';
import 'room_ui_controller.dart';
import 'room_chat_components.dart';

/// Desktop split-stage layout for Live broadcast (matching Image 1).
///
/// Left side (~38%): Integrated Host card, Interactive Chat Feed & Input bar.
/// Right side (~62%): Large Live Stage with live duration badge, audience avatars,
/// tap-to-like gestures, and floating hearts overlay.
class RealtimeLiveDesktopStage extends StatelessWidget {
  const RealtimeLiveDesktopStage({
    super.key,
    this.showChat = true,
    this.showLiveInteractions = true,
    this.videoFit,
    this.onExit,
    this.exitAction,
    this.onToggleCleanScreen,
    this.customChatPanel,
    this.customGiftPanel,
    this.topTrailingActions,
    this.onViewAudience,
    this.liveDuration,
  });

  final bool showChat;
  final bool showLiveInteractions;
  final BoxFit? videoFit;
  final VoidCallback? onExit;
  final Widget? exitAction;
  final VoidCallback? onToggleCleanScreen;
  final Widget? customChatPanel;
  final Widget? customGiftPanel;
  final List<Widget>? topTrailingActions;
  final VoidCallback? onViewAudience;
  final Duration? liveDuration;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = RealtimeStrings.of(context);

    return Stack(
      children: [
        Row(
          textDirection: TextDirection.rtl,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Left Interaction Column (~38%)
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 320, maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                child: RealtimeCardSurface(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      // Top Host Card
                      Padding(
                        padding: const EdgeInsets.only(right: 52),
                        child: _LiveHostHeader(
                          room: controller.room,
                          onViewAudience: onViewAudience,
                        ),
                      ),
                      const Divider(height: 1),

                      // Middle Interactive Feed (Chat / Gifts)
                      Expanded(
                        child:
                            customChatPanel ??
                            (showChat
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Align(
                                      alignment: Alignment.bottomLeft,
                                      child: RealtimeLiveChatFeed(
                                        maxMessages: 20,
                                        onVideo: false,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink()),
                      ),

                      const Divider(height: 1),
                      // Bottom Chat Input & Interaction Row
                      _LiveBottomBar(
                        controller: controller,
                        showChat: showChat,
                        showLiveInteractions: showLiveInteractions,
                        customGiftButton: customGiftPanel,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 2. Right Live Video Stage (~62%)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    RealtimeUiTokens.radiusCard,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      // Camera-off is not a black video texture. Let the
                      // participant placeholder blend into the light stage.
                      color: isDark
                          ? const Color(0xFF181B22)
                          : RealtimeUiTokens.surfaceSubtle,
                      borderRadius: BorderRadius.circular(
                        RealtimeUiTokens.radiusCard,
                      ),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : RealtimeUiTokens.border,
                        width: 0.8,
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // A. Video Canvas with Double-Tap to Like
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: !showLiveInteractions
                              ? null
                              : () => unawaited(
                                  controller.sendLiveLike().catchError(
                                    controller.reportActionError,
                                  ),
                                ),
                          onDoubleTap: !showLiveInteractions
                              ? null
                              : () {
                                  unawaited(
                                    controller.sendLiveLike().catchError(
                                      controller.reportActionError,
                                    ),
                                  );
                                  unawaited(
                                    controller.sendLiveLike().catchError(
                                      controller.reportActionError,
                                    ),
                                  );
                                },
                          child: RealtimeLiveVideoStage(fit: videoFit),
                        ),

                        const Positioned(
                          left: 16,
                          right: 16,
                          bottom: 16,
                          child: SafeArea(
                            top: false,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: RealtimeLiveMediaControls(),
                            ),
                          ),
                        ),

                        // B. Floating Hearts Animation Overlay
                        if (showLiveInteractions &&
                            controller.room.liveInteractions != null)
                          const Positioned(
                            right: 24,
                            bottom: 40,
                            width: 140,
                            height: 280,
                            child: IgnorePointer(
                              child: RealtimeLiveHeartsOverlay(),
                            ),
                          ),

                        // All viewers and the host receive gift events even
                        // when their gift panel is closed.
                        if (showLiveInteractions &&
                            controller.room.liveInteractions != null)
                          const Positioned(
                            left: 16,
                            right: 150,
                            bottom: 88,
                            child: IgnorePointer(
                              child: Align(
                                alignment: Alignment.bottomLeft,
                                child: RealtimeLiveGiftBanner(),
                              ),
                            ),
                          ),

                        Positioned(
                          top: 14,
                          left: 14,
                          right: 14,
                          child: Row(
                            children: [
                              _LiveDurationBadge(duration: liveDuration),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      RealtimeAudienceAvatarRow(
                                        onViewAll: onViewAudience,
                                      ),
                                      if (onToggleCleanScreen != null)
                                        RealtimeGlassIconButton(
                                          icon: Icons.fullscreen_rounded,
                                          tooltip: strings.isZh
                                              ? '清屏'
                                              : 'Hide controls',
                                          onPressed: onToggleCleanScreen,
                                        ),
                                      ...?topTrailingActions,
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (exitAction != null || onExit != null)
          Positioned(
            top: 16,
            right: 16,
            child:
                exitAction ??
                RealtimeGlassIconButton(
                  icon: Icons.close_rounded,
                  danger: true,
                  tooltip: strings.leave,
                  onPressed: onExit,
                ),
          ),
      ],
    );
  }
}

class _LiveHostHeader extends StatelessWidget {
  const _LiveHostHeader({required this.room, this.onViewAudience});

  final RealtimeRoom room;
  final VoidCallback? onViewAudience;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final strings = RealtimeStrings.of(context);
    final host =
        room.media.snapshot.participants
            .where((p) => p.isVideoEnabled)
            .firstOrNull ??
        (room.media.role == MediaRole.host
            ? room.media.snapshot.localParticipant
            : room.media.snapshot.remoteParticipants.firstOrNull);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          if (host != null)
            RealtimeAvatar(
              name: host.displayName,
              avatarUrl: host.avatarUrl,
              size: 40,
            )
          else
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    RealtimeUiTokens.appleBlue,
                    RealtimeUiTokens.appleIndigo,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.live_tv_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  room.media.roomCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isDark ? Colors.white : RealtimeUiTokens.text,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: RealtimeUiTokens.appleSuccess,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      strings.live,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: RealtimeUiTokens.appleSuccess,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveDurationBadge extends StatelessWidget {
  const _LiveDurationBadge({this.duration});

  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    final d = duration ?? Duration.zero;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final formatted = h > 0 ? '$h:$m:$s' : '$m:$s';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(RealtimeUiTokens.radiusPill),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: RealtimeUiTokens.appleDanger,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            formatted,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveBottomBar extends StatelessWidget {
  const _LiveBottomBar({
    required this.controller,
    this.customGiftButton,
    required this.showChat,
    required this.showLiveInteractions,
  });
  final bool showChat;
  final bool showLiveInteractions;
  final RealtimeRoomUiController controller;
  final Widget? customGiftButton;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        if (showChat && controller.room.chat != null)
          const Expanded(child: RealtimeChatComposer())
        else
          const Spacer(),
        if (customGiftButton != null)
          customGiftButton!
        else if (showLiveInteractions &&
            controller.room.liveInteractions != null)
          const RealtimeLiveGiftButton(),
        if (showLiveInteractions && controller.room.liveInteractions != null)
          const RealtimeLiveLikeButton(),
      ],
    ),
  );
}
