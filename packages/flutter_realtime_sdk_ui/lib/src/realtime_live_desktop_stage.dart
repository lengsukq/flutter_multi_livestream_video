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

/// Desktop split-stage layout for Live broadcast.
///
/// The video occupies the left/main pane and a 360 pt interaction column sits
/// on the right, matching the reference live-classroom screen: host card,
/// chat feed, composer and gift/like actions.
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
    final style = RealtimeStyle.of(context);
    final strings = RealtimeStrings.of(context);

    return Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    RealtimeUiTokens.stageRadius,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: style.tile,
                      borderRadius: BorderRadius.circular(
                        RealtimeUiTokens.stageRadius,
                      ),
                      border: Border.all(color: style.border),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
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
                        Positioned(
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
            SizedBox(
              width: 360,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
                child: Material(
                  color: style.surface,
                  borderRadius: BorderRadius.circular(
                    RealtimeUiTokens.cardRadius,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        RealtimeUiTokens.cardRadius,
                      ),
                      border: Border.all(color: style.border),
                      boxShadow: style.cardShadow,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        RealtimeUiTokens.cardRadius,
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                            child: _LiveHostHeader(
                              room: controller.room,
                              onViewAudience: onViewAudience,
                              trailing:
                                  exitAction ??
                                  (onExit == null
                                      ? null
                                      : RealtimeGlassIconButton(
                                          icon: Icons.call_end_rounded,
                                          danger: true,
                                          tooltip: strings.leave,
                                          onPressed: onExit,
                                        )),
                            ),
                          ),
                          Divider(height: 1, color: style.border),
                          Expanded(
                            child:
                                customChatPanel ??
                                (showChat
                                    ? RealtimeLiveChatFeed(maxMessages: 100)
                                    : const SizedBox.shrink()),
                          ),
                          Divider(height: 1, color: style.border),
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
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LiveHostHeader extends StatelessWidget {
  const _LiveHostHeader({
    required this.room,
    this.onViewAudience,
    this.trailing,
  });

  final RealtimeRoom room;
  final VoidCallback? onViewAudience;

  /// Exit action rendered at the end of the host row.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final strings = RealtimeStrings.of(context);
    final host =
        room.media.snapshot.participants
            .where((p) => p.isVideoEnabled)
            .firstOrNull ??
        (room.media.role == MediaRole.host
            ? room.media.snapshot.localParticipant
            : room.media.snapshot.remoteParticipants.firstOrNull);

    return Row(
      children: [
        RealtimeAvatar(
          name: host?.displayName ?? strings.liveRoom,
          avatarUrl: host?.avatarUrl,
          size: 40,
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
                  letterSpacing: -0.2,
                  color: style.text,
                ),
              ),
              Text(
                host?.displayName.isEmpty ?? true
                    ? strings.liveRoom
                    : host!.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: style.textMuted),
              ),
            ],
          ),
        ),
        RealtimeStatusPill(
          label: strings.liveStatus,
          tone: RealtimeStatusTone.live,
          showDot: true,
          blink: true,
        ),
        if (trailing != null) ...[const SizedBox(width: 6), trailing!],
      ],
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
    return RealtimeStatusPill(
      label: formatted,
      tone: RealtimeStatusTone.live,
      showDot: true,
      blink: true,
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
            controller.room.liveInteractions != null) ...[
          const SizedBox(width: 6),
          const RealtimeLiveGiftButton(),
        ],
        if (showLiveInteractions && controller.room.liveInteractions != null)
          const RealtimeLiveLikeButton(),
      ],
    ),
  );
}
