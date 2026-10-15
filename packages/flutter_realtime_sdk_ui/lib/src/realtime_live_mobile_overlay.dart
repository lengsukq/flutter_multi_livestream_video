import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_live_preset/flutter_realtime_live_preset.dart';

import 'realtime_audience_avatar_row.dart';
import 'realtime_live_chat_feed.dart';
import 'realtime_live_gift_button.dart';
import 'realtime_live_hearts_overlay.dart';
import 'realtime_live_like_button.dart';
import 'realtime_live_gift_banner.dart';
import 'realtime_role_presentation.dart';
import 'realtime_live_media_controls.dart';
import 'room_ui_controller.dart';
import 'room_chat_components.dart';

/// Full-screen mobile immersive HUD overlay for Live broadcast (matching Image 1 mobile).
///
/// Features:
/// - Top HUD: Host info capsule, Audience avatars, and Close button.
/// - Floating chat barrage on bottom-left.
/// - Floating hearts animation on bottom-right.
/// - Bottom interactive controls: Chat input pill, Gift button, Heart like button, and extra tools.
class RealtimeLiveMobileOverlay extends StatelessWidget {
  const RealtimeLiveMobileOverlay({
    super.key,
    this.showChat = true,
    this.showLiveInteractions = true,
    this.onExit,
    this.exitAction,
    this.onViewAudience,
    this.onOpenHostTools,
    this.onOpenBackgroundEffects,
    this.onOpenGiftSheet,
    this.extraBottomActions,
    this.extraTopActions = const [],
    this.videoFit,
    this.onToggleVideoFit,
    this.onToggleCleanScreen,
    this.maxChatMessages = 5,
  });

  final VoidCallback? onExit;
  final Widget? exitAction;
  final VoidCallback? onViewAudience;
  final VoidCallback? onOpenHostTools;

  /// Optional shortcut in the mobile More menu. Shown for publishers only.
  final VoidCallback? onOpenBackgroundEffects;
  final VoidCallback? onOpenGiftSheet;
  final List<Widget>? extraBottomActions;
  final List<Widget> extraTopActions;
  final int maxChatMessages;
  final bool showChat;
  final bool showLiveInteractions;
  final BoxFit? videoFit;
  final VoidCallback? onToggleVideoFit;
  final VoidCallback? onToggleCleanScreen;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    final isHost = RealtimePresentationRole.forLive(
      controller.room.media.role,
    ).canShowLiveHostTools;
    return LayoutBuilder(
      builder: (context, viewport) {
        final narrowHud = viewport.maxWidth < 300;
        final compactHud =
            viewport.maxWidth < 390 ||
            MediaQuery.textScalerOf(context).scale(17) >= 28;

        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. Top Scrim Gradient
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 140,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.65),
                        Colors.transparent,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),

            // 2. Bottom Scrim Gradient
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 220,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.75),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),

            // A single compact header; display actions live in the More menu.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: narrowHud ? 8 : 14,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      if (viewport.maxWidth >= 220)
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _MobileHostCapsule(
                              room: controller.room,
                              avatarOnly: narrowHud,
                            ),
                          ),
                        ),
                      if (viewport.maxWidth < 220) const Spacer(),
                      const SizedBox(width: 8),
                      RealtimeGlassSurface(
                        radius: RealtimeUiTokens.pillRadius,
                        fillColor: const Color(0xFF242426),
                        opacity: .64,
                        borderColor: Colors.white.withValues(alpha: .22),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!narrowHud)
                              Tooltip(
                                message: RealtimeStrings.of(
                                  context,
                                ).participants,
                                child: RealtimeAudienceAvatarRow(
                                  onViewAll: onViewAudience,
                                  onVideo: true,
                                  avatarSize: 24,
                                  maxAvatars: compactHud ? 0 : 1,
                                ),
                              ),
                            if (onOpenBackgroundEffects != null ||
                                onOpenHostTools != null ||
                                onToggleVideoFit != null ||
                                onToggleCleanScreen != null ||
                                narrowHud ||
                                extraTopActions.isNotEmpty)
                              IconButton(
                                tooltip: RealtimeStrings.of(context).isZh
                                    ? '显示选项'
                                    : 'Display options',
                                style: IconButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(48, 48),
                                ),
                                onPressed: () => _openDisplayOptions(context),
                                icon: const Icon(
                                  Icons.more_horiz_rounded,
                                  size: 22,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (exitAction != null || onExit != null) ...[
                        const SizedBox(width: 8),
                        exitAction ??
                            IconButton.filled(
                              tooltip: RealtimeStrings.of(context).leave,
                              style: IconButton.styleFrom(
                                backgroundColor: RealtimeUiTokens.appleDanger,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(48, 48),
                              ),
                              onPressed: onExit,
                              icon: const Icon(Icons.close_rounded, size: 20),
                            ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // 4. Floating Hearts Animation Overlay
            if (showLiveInteractions &&
                controller.room.liveInteractions != null)
              const Positioned(
                right: 16,
                bottom: 80,
                width: 120,
                height: 260,
                child: IgnorePointer(child: RealtimeLiveHeartsOverlay()),
              ),

            if (showLiveInteractions &&
                controller.room.liveInteractions != null)
              const Positioned(
                left: 12,
                right: 12,
                bottom: 214,
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: RealtimeLiveGiftBanner(),
                  ),
                ),
              ),

            // 5. Floating Chat Feed & Bottom Action Bar
            Positioned(
              left: 12,
              right: 12,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Floating Chat Feed
                    if (showChat)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: viewport.maxWidth * 0.72,
                          maxHeight:
                              (viewport.maxHeight -
                                      MediaQuery.paddingOf(context).vertical -
                                      260)
                                  .clamp(0, 180),
                        ),
                        child: RealtimeLiveChatFeed(
                          maxMessages: maxChatMessages,
                        ),
                      ),
                    const SizedBox(height: 10),

                    if (isHost) ...[
                      RealtimeLiveMediaControls(
                        onOpenHostTools: narrowHud ? null : onOpenHostTools,
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Bottom Action Bar
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final actions = SingleChildScrollView(
                            reverse: true,
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (showLiveInteractions &&
                                    onOpenGiftSheet != null) ...[
                                  _CircleIconButton(
                                    icon: Icons.card_giftcard_rounded,
                                    color: RealtimeUiTokens.appleRose,
                                    onPressed: onOpenGiftSheet!,
                                  ),
                                  const SizedBox(width: 8),
                                ] else if (showLiveInteractions &&
                                    controller.room.liveInteractions !=
                                        null) ...[
                                  const RealtimeLiveGiftButton(),
                                  const SizedBox(width: 8),
                                ],
                                if (showLiveInteractions &&
                                    controller.room.liveInteractions != null)
                                  RealtimeLiveLikeButton(iconOnly: compactHud),
                                ...?extraBottomActions,
                              ],
                            ),
                          );
                          if (!showChat || controller.room.chat == null) {
                            return actions;
                          }
                          final chat = _MobileChatInputPill(
                            onTap: () =>
                                _openChatInputDialog(context, controller),
                          );
                          if (constraints.maxWidth < 280) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                chat,
                                const SizedBox(height: 8),
                                actions,
                              ],
                            );
                          }
                          return Row(
                            children: [
                              // Chat Input Trigger Pill
                              Expanded(child: chat),
                              const SizedBox(width: 8),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: (constraints.maxWidth * 0.5).clamp(
                                    112.0,
                                    260.0,
                                  ),
                                ),
                                child: actions,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openDisplayOptions(BuildContext context) {
    final strings = RealtimeStrings.of(context);
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(
                      strings.isZh ? '显示选项' : 'Display options',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (onViewAudience != null)
                    ListTile(
                      leading: const Icon(Icons.people_outline_rounded),
                      title: Text(strings.participants),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        onViewAudience!();
                      },
                    ),
                  if (onOpenHostTools != null)
                    ListTile(
                      leading: const Icon(Icons.tune_rounded),
                      title: Text(strings.isZh ? '主播工具' : 'Host tools'),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        onOpenHostTools!();
                      },
                    ),
                  if (onOpenBackgroundEffects != null)
                    ListTile(
                      leading: const Icon(Icons.blur_on_outlined),
                      title: Text(strings.virtualBackground),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        onOpenBackgroundEffects!();
                      },
                    ),
                  if (onToggleVideoFit != null)
                    ListTile(
                      leading: Icon(
                        videoFit == BoxFit.contain
                            ? Icons.crop_free_rounded
                            : Icons.fit_screen_rounded,
                      ),
                      title: Text(
                        videoFit == BoxFit.contain
                            ? strings.fillLiveScreen
                            : strings.showFullVideo,
                      ),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        onToggleVideoFit!();
                      },
                    ),
                  if (onToggleCleanScreen != null)
                    ListTile(
                      leading: const Icon(Icons.fullscreen_rounded),
                      title: Text(strings.isZh ? '清屏' : 'Hide controls'),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        onToggleCleanScreen!();
                      },
                    ),
                  if (extraTopActions.isNotEmpty)
                    Wrap(spacing: 8, runSpacing: 8, children: extraTopActions),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openChatInputDialog(
    BuildContext context,
    RealtimeRoomUiController controller,
  ) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (dialogContext) => _ChatInputSheet(controller: controller),
      ),
    );
  }
}

class _MobileHostCapsule extends StatelessWidget {
  const _MobileHostCapsule({required this.room, this.avatarOnly = false});

  final RealtimeRoom room;
  final bool avatarOnly;

  @override
  Widget build(BuildContext context) {
    final host =
        room.media.snapshot.participants
            .where((p) => p.isVideoEnabled)
            .firstOrNull ??
        (room.media.role == MediaRole.host
            ? room.media.snapshot.localParticipant
            : room.media.snapshot.remoteParticipants.firstOrNull);
    return Container(
      padding: avatarOnly
          ? const EdgeInsets.all(4)
          : const EdgeInsets.fromLTRB(4, 4, 10, 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(RealtimeUiTokens.radiusPill),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (host != null)
            RealtimeAvatar(
              name: host.displayName,
              avatarUrl: host.avatarUrl,
              size: 28,
            )
          else
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    RealtimeUiTokens.appleBlue,
                    RealtimeUiTokens.appleIndigo,
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          if (!avatarOnly) const SizedBox(width: 8),
          if (!avatarOnly)
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    room.media.roomCode,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Text(
                    'LIVE',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFFFFB0B7),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MobileChatInputPill extends StatelessWidget {
  const _MobileChatInputPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RealtimeGlassPressable(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(RealtimeUiTokens.radiusPill),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
            width: 0.8,
          ),
        ),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 16,
              color: Colors.white.withValues(alpha: 0.70),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                RealtimeStrings.of(context).isZh ? '发送消息…' : 'Say something…',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 0.8,
        ),
      ),
      child: IconButton(
        icon: Icon(icon, size: 20, color: color ?? Colors.white),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      ),
    );
  }
}

class _ChatInputSheet extends StatelessWidget {
  const _ChatInputSheet({required this.controller});
  final RealtimeRoomUiController controller;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      top: false,
      child: RealtimeGlassSurface(
        radius: RealtimeUiTokens.sheetRadius,
        padding: const EdgeInsets.all(20),
        child: RealtimeRoomUiScope(
          room: controller.room,
          controller: controller,
          child: const RealtimeChatComposer(),
        ),
      ),
    ),
  );
}
