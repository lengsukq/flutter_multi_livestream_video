import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_live_preset/flutter_realtime_live_preset.dart';
import 'package:flutter_realtime_room_ui/flutter_realtime_room_ui.dart'
    show RealtimeConnectionIndicator;

import 'realtime_dock_item.dart';
import 'realtime_dock_microphone_button.dart';
import 'realtime_dock_camera_button.dart';
import 'realtime_live_gift_banner.dart';
import 'realtime_live_gift_button.dart';
import 'realtime_live_hearts_overlay.dart';
import 'realtime_live_like_button.dart';
import 'realtime_live_video_stage.dart';
import 'realtime_meeting_dock.dart';
import 'realtime_meeting_rail.dart';
import 'realtime_meeting_sidebar.dart';
import 'realtime_meeting_timer_badge.dart';
import 'realtime_meeting_top_bar.dart';
import 'realtime_recording_badge.dart';
import 'room_chat_components.dart';
import 'room_ui_controller.dart';

/// Live broadcast uses the same room shell as a meeting while keeping its
/// separate media renderer, live reactions, gifts and provider capabilities.
class RealtimeLiveDesktopStage extends StatelessWidget {
  const RealtimeLiveDesktopStage({
    super.key,
    this.showChat = true,
    this.showLiveInteractions = true,
    this.videoFit,
    this.onExit,
    this.exitAction,
    this.onToggleCleanScreen,
    this.onToggleVideoFit,
    this.customChatPanel,
    this.customGiftPanel,
    this.topTrailingActions,
    this.onViewAudience,
    this.onOpenHostTools,
    this.liveDuration,
    this.startedAt,
    this.initialTab = 0,
    this.onSelectedTab,
  });
  final bool showChat;
  final bool showLiveInteractions;
  final BoxFit? videoFit;
  final VoidCallback? onExit;
  final Widget? exitAction;
  final VoidCallback? onToggleCleanScreen;
  final VoidCallback? onToggleVideoFit;
  final Widget? customChatPanel;
  final Widget? customGiftPanel;
  final List<Widget>? topTrailingActions;
  final VoidCallback? onViewAudience;
  final VoidCallback? onOpenHostTools;
  final Duration? liveDuration;
  final DateTime? startedAt;
  final int initialTab;
  final ValueChanged<int>? onSelectedTab;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    final room = controller.room;
    final style = RealtimeStyle.of(context);
    final strings = RealtimeStrings.of(context);
    final isHost = room.media.role == MediaRole.host;
    final participants = controller.snapshot.participants;
    final host = isHost
        ? controller.snapshot.localParticipant
        : controller.snapshot.remoteParticipants.firstOrNull;
    final members = participants
        .map(
          (p) => RealtimeMeetingMemberItem(
            id: p.id,
            name: p.displayName.isEmpty ? p.id : p.displayName,
            avatarUrl: p.avatarUrl,
            roleTitle: p.isLocal ? (strings.isZh ? '我' : 'You') : null,
            isMuted: p.isMuted,
            isVideoOff: !p.isVideoEnabled,
            isSpeaking: p.isSpeaking,
          ),
        )
        .toList(growable: false);

    return ColoredBox(
      color: style.background,
      child: Column(
        children: [
          RealtimeMeetingTopBar(
            title: room.media.roomCode,
            subtitle: host?.displayName.isNotEmpty == true
                ? host!.displayName
                : strings.liveRoom,
            statusWidgets: [
              RealtimeStatusPill(
                label: strings.liveStatus,
                tone: RealtimeStatusTone.live,
                showDot: true,
                blink: true,
              ),
              if (startedAt != null)
                RealtimeMeetingTimerBadge(startedAt: startedAt!, live: true)
              else if (liveDuration != null)
                RealtimeStatusPill(
                  label: _formatDuration(liveDuration!),
                  tone: RealtimeStatusTone.live,
                ),
              RealtimeRecordingBadge(room: room, compact: true),
              const RealtimeConnectionIndicator(),
            ],
            audienceNames: participants
                .map((p) => p.displayName.isEmpty ? p.id : p.displayName)
                .toList(growable: false),
            audienceCount: participants.length,
            trailingActions: [
              if (onViewAudience != null)
                IconButton.outlined(
                  tooltip: strings.participants,
                  onPressed: onViewAudience,
                  icon: const Icon(Icons.people_outline_rounded, size: 19),
                ),
              ...?topTrailingActions,
              if (exitAction != null)
                exitAction!
              else if (onExit != null)
                IconButton.filled(
                  tooltip: strings.leave,
                  onPressed: onExit,
                  icon: const Icon(Icons.call_end_rounded),
                ),
            ],
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RealtimeMeetingRail(
                  items: [
                    if (showChat)
                      RealtimeMeetingRailItem(
                        icon: Icons.chat_bubble_outline_rounded,
                        tooltip: strings.chat,
                        active: initialTab == 0,
                        onPressed: () => onSelectedTab?.call(0),
                      ),
                    RealtimeMeetingRailItem(
                      icon: Icons.people_outline_rounded,
                      tooltip: strings.participants,
                      active: initialTab == 1,
                      badgeCount: participants.length,
                      onPressed: () => onSelectedTab?.call(1),
                    ),
                  ],
                ),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              RealtimeUiTokens.stageRadius,
                            ),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: style.tile,
                                border: Border.all(color: style.border),
                                borderRadius: BorderRadius.circular(
                                  RealtimeUiTokens.stageRadius,
                                ),
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: !showLiveInteractions
                                        ? null
                                        : () => unawaited(
                                            controller
                                                .sendLiveLike()
                                                .catchError(
                                                  controller.reportActionError,
                                                ),
                                          ),
                                    onDoubleTap: !showLiveInteractions
                                        ? null
                                        : () {
                                            for (var i = 0; i < 2; i++) {
                                              unawaited(
                                                controller
                                                    .sendLiveLike()
                                                    .catchError(
                                                      controller
                                                          .reportActionError,
                                                    ),
                                              );
                                            }
                                          },
                                    child: RealtimeLiveVideoStage(
                                      fit: videoFit,
                                    ),
                                  ),
                                  if (showLiveInteractions &&
                                      room.liveInteractions != null) ...[
                                    const Positioned(
                                      right: 24,
                                      bottom: 24,
                                      width: 140,
                                      height: 280,
                                      child: IgnorePointer(
                                        child: RealtimeLiveHeartsOverlay(),
                                      ),
                                    ),
                                    const Positioned(
                                      left: 16,
                                      right: 160,
                                      bottom: 20,
                                      child: IgnorePointer(
                                        child: RealtimeLiveGiftBanner(),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                        child: Center(
                          child: RealtimeMeetingDock(
                            showLabels: false,
                            mediaGroup: [
                              if (isHost && controller.canUseMicrophone)
                                const RealtimeDockMicrophoneButton(
                                  showLabel: false,
                                ),
                              if (isHost && controller.canUseCamera)
                                const RealtimeDockCameraButton(
                                  showLabel: false,
                                ),
                              if (!isHost ||
                                  (!controller.canUseMicrophone &&
                                      !controller.canUseCamera))
                                RealtimeDockItem(
                                  icon: Icons.people_outline_rounded,
                                  label: strings.participants,
                                  showLabel: false,
                                  onPressed: onViewAudience,
                                ),
                            ],
                            collaborationGroup: [
                              if (onToggleVideoFit != null)
                                RealtimeDockItem(
                                  icon: videoFit == BoxFit.contain
                                      ? Icons.crop_free_rounded
                                      : Icons.fit_screen_rounded,
                                  label: videoFit == BoxFit.contain
                                      ? strings.fillLiveScreen
                                      : strings.showFullVideo,
                                  showLabel: false,
                                  onPressed: onToggleVideoFit,
                                ),
                              if (onToggleCleanScreen != null)
                                RealtimeDockItem(
                                  icon: Icons.fullscreen_rounded,
                                  label: strings.isZh ? '清屏' : 'Hide controls',
                                  showLabel: false,
                                  onPressed: onToggleCleanScreen,
                                ),
                              if (isHost && onOpenHostTools != null)
                                RealtimeDockItem(
                                  icon: Icons.tune_rounded,
                                  label: strings.isZh ? '主播工具' : 'Host tools',
                                  showLabel: false,
                                  onPressed: onOpenHostTools,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 340,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: style.surface,
                      border: Border(left: BorderSide(color: style.border)),
                    ),
                    child: RealtimeMeetingSidebar(
                      members: members,
                      initialTab: initialTab,
                      onTabChanged: onSelectedTab,
                      chatWidget:
                          customChatPanel ??
                          Column(
                            children: [
                              Expanded(
                                child: showChat && room.chat != null
                                    ? const RealtimeChatPanel(
                                        timelineStyle: true,
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              if (showLiveInteractions &&
                                  room.liveInteractions != null)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    6,
                                    12,
                                    10,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (customGiftPanel != null)
                                        customGiftPanel!
                                      else
                                        const RealtimeLiveGiftButton(),
                                      const SizedBox(width: 8),
                                      const RealtimeLiveLikeButton(),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                      membersWidget: const RealtimeManagedParticipantList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
