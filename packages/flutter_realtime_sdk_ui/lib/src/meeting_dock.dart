import 'package:flutter_realtime_classroom_preset/flutter_realtime_classroom_preset.dart';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'room_classroom_activities.dart';
import 'room_classroom_interactions.dart';
import 'room_control_components.dart';
import 'room_ui_controller.dart';

/// Standard item button for [RealtimeMeetingDock].
class RealtimeDockItem extends StatelessWidget {
  const RealtimeDockItem({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.isActive = false,
    this.isDanger = false,
    this.badgeCount,
    this.showBadgeDot = false,
    this.showLabel = true,
    this.isLoading = false,
    this.activeColor,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isActive;
  final bool isDanger;
  final int? badgeCount;
  final bool showBadgeDot;
  final bool showLabel;
  final bool isLoading;
  final Color? activeColor;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = activeColor ?? theme.colorScheme.primary;

    Color iconBgColor;
    Color iconColor;

    if (isDanger) {
      iconBgColor = const Color(
        0xFFFF3B30,
      ).withValues(alpha: isDark ? 0.35 : 0.14);
      iconColor = const Color(0xFFFF3B30);
    } else if (isActive) {
      iconBgColor = primaryColor.withValues(alpha: isDark ? 0.35 : 0.18);
      iconColor = primaryColor;
    } else {
      iconBgColor = (isDark ? Colors.white : Colors.black).withValues(
        alpha: 0.06,
      );
      iconColor = theme.colorScheme.onSurface;
    }

    final buttonContent = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Badge(
          isLabelVisible:
              (badgeCount != null && badgeCount! > 0) || showBadgeDot,
          label: badgeCount != null && badgeCount! > 0
              ? Text('$badgeCount', style: const TextStyle(fontSize: 9))
              : null,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(13),
              border: isActive && !isDanger
                  ? Border.all(
                      color: primaryColor.withValues(alpha: 0.4),
                      width: 1,
                    )
                  : null,
            ),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: iconColor,
                      ),
                    )
                  : Icon(icon, size: 20, color: iconColor),
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive
                  ? primaryColor
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );

    return Tooltip(
      message: tooltip ?? label,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isLoading ? null : onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: buttonContent,
        ),
      ),
    );
  }
}

/// A unified Glassmorphic Meeting Dock for conference and classroom rooms.
///
/// Groups controls cleanly into Media, Sharing, Panels, and Exit zones,
/// preventing multi-row clutter and broken layouts.
class RealtimeMeetingDock extends StatelessWidget {
  const RealtimeMeetingDock({
    super.key,
    required this.mediaGroup,
    this.collaborationGroup = const [],
    this.panelsGroup = const [],
    this.exitAction,
    this.showLabels = true,
  });

  final List<Widget> mediaGroup;
  final List<Widget> collaborationGroup;
  final List<Widget> panelsGroup;
  final Widget? exitAction;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget divider() => Container(
      width: 1,
      height: showLabels ? 34 : 24,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
    );

    return SafeArea(
      top: false,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 10,
                vertical: showLabels ? 6 : 4,
              ),
              decoration: BoxDecoration(
                color: (isDark
                    ? const Color(0xE61E2533)
                    : const Color(0xF2FFFFFF)),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: (isDark ? Colors.white12 : Colors.black12),
                  width: 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Group 1: Media
                    ...mediaGroup,

                    // Divider
                    if (collaborationGroup.isNotEmpty) ...[
                      divider(),
                      ...collaborationGroup,
                    ],

                    // Divider
                    if (panelsGroup.isNotEmpty) ...[divider(), ...panelsGroup],

                    // Exit
                    if (exitAction != null) ...[divider(), exitAction!],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dock Microphone button with proper label, active state and mute toggle.
class RealtimeDockMicrophoneButton extends StatelessWidget {
  const RealtimeDockMicrophoneButton({super.key, this.showLabel = true});
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final strings = RealtimeStrings.of(context);
    return RealtimeRoomActionButton(
      action: RealtimeRoomUiAction.microphone,
      builder: (context, onPressed, active, pending) {
        return RealtimeDockItem(
          icon: active ? Icons.mic_rounded : Icons.mic_off_rounded,
          label: active ? strings.micOn : strings.muted,
          isActive: active,
          isLoading: pending,
          onPressed: onPressed,
          showLabel: showLabel,
          activeColor: RealtimeUiTokens.iosBlue,
        );
      },
    );
  }
}

/// Dock Camera button with proper label, active state and video toggle.
class RealtimeDockCameraButton extends StatelessWidget {
  const RealtimeDockCameraButton({super.key, this.showLabel = true});
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final strings = RealtimeStrings.of(context);
    return RealtimeRoomActionButton(
      action: RealtimeRoomUiAction.camera,
      builder: (context, onPressed, active, pending) {
        return RealtimeDockItem(
          icon: active ? Icons.videocam_rounded : Icons.videocam_off_rounded,
          label: active ? strings.camOn : strings.camOff,
          isActive: active,
          isLoading: pending,
          onPressed: onPressed,
          showLabel: showLabel,
          activeColor: RealtimeUiTokens.iosTeal,
        );
      },
    );
  }
}

/// Dock Shared Content Selector Button with unified mode switching (Screen/Whiteboard).
class RealtimeDockSharedContentButton extends StatelessWidget {
  const RealtimeDockSharedContentButton({super.key, this.showLabel = true});
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final room = RealtimeRoomUiScope.of(context).room;
    final shared = room.sharedContent;
    final strings = RealtimeStrings.of(context);

    if (shared == null) {
      // Standalone screen share mode without shared content controller
      return RealtimeRoomActionButton(
        action: RealtimeRoomUiAction.screenShare,
        builder: (context, onPressed, active, pending) {
          return RealtimeDockItem(
            icon: active
                ? Icons.stop_screen_share_rounded
                : Icons.screen_share_rounded,
            label: active ? strings.stopSharing : strings.screenShare,
            isActive: active,
            isLoading: pending,
            onPressed: onPressed,
            showLabel: showLabel,
            activeColor: RealtimeUiTokens.iosOrange,
          );
        },
      );
    }

    return StreamBuilder<SharedContentStatus>(
      stream: shared.statuses,
      initialData: shared.status,
      builder: (context, snapshot) {
        final status = snapshot.data ?? shared.status;
        final mode = status.content?.mode ?? SharedContentMode.members;
        final isSharing = mode != SharedContentMode.members;

        void openMenu() {
          final theme = Theme.of(context);
          unawaited(
            showModalBottomSheet<void>(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (sheetContext) => SafeArea(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          strings.chooseContentToShare,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.draw_outlined,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        title: Text(strings.whiteboard),
                        subtitle: Text(strings.whiteboardDescription),
                        selected: mode == SharedContentMode.whiteboard,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          unawaited(
                            shared.selectMode(SharedContentMode.whiteboard),
                          );
                        },
                      ),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: RealtimeUiTokens.iosGreen.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.screen_share_outlined,
                            color: RealtimeUiTokens.iosGreen,
                          ),
                        ),
                        title: Text(strings.screenShare),
                        subtitle: Text(strings.shareScreenDescription),
                        enabled: shared.canShare,
                        selected: mode == SharedContentMode.screen,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          unawaited(
                            shared.selectMode(SharedContentMode.screen),
                          );
                        },
                      ),
                      if (isSharing) ...[
                        const Divider(height: 1),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.stop_screen_share_rounded,
                              color: theme.colorScheme.error,
                            ),
                          ),
                          title: Text(
                            strings.stopSharing,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            unawaited(
                              shared.selectMode(SharedContentMode.members),
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return RealtimeDockItem(
          icon: isSharing
              ? (mode == SharedContentMode.whiteboard
                    ? Icons.draw_rounded
                    : Icons.screen_share_rounded)
              : Icons.present_to_all_rounded,
          label: isSharing
              ? (mode == SharedContentMode.whiteboard
                    ? strings.whiteboard
                    : strings.stopSharing)
              : strings.shareContent,
          isActive: isSharing,
          isLoading: status.busy,
          onPressed: status.content?.canManage == true ? openMenu : null,
          showLabel: showLabel,
          activeColor: RealtimeUiTokens.iosOrange,
        );
      },
    );
  }
}

/// Dock raise-hand button aligned with [RealtimeDockItem] geometry and badges.
class RealtimeDockRaiseHandButton extends StatelessWidget {
  const RealtimeDockRaiseHandButton({super.key, this.showLabel = true});
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    final strings = RealtimeStrings.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.classroomState;
        if (state == null || !controller.canRaiseHand) {
          return const SizedBox.shrink();
        }
        final raised = state.students.any(
          (student) => student.userId == state.selfUserId && student.handRaised,
        );
        return RealtimeDockItem(
          icon: raised ? Icons.pan_tool_rounded : Icons.pan_tool_outlined,
          label: raised ? strings.handRaised : strings.raiseHand,
          isActive: raised,
          activeColor: RealtimeUiTokens.iosOrange,
          showLabel: showLabel,
          onPressed: controller.isPending(RealtimeRoomUiAction.classroom)
              ? null
              : () async {
                  await controller.setHandRaised(!raised);
                },
        );
      },
    );
  }
}

/// Dock feedback popup button aligned with [RealtimeDockItem] geometry.
class RealtimeDockFeedbackButton extends StatelessWidget {
  const RealtimeDockFeedbackButton({super.key, this.showLabel = true});
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    final strings = RealtimeStrings.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.classroomState?.capabilities.canSendFeedback != true) {
          return const SizedBox.shrink();
        }
        return PopupMenuButton<ClassroomFeedbackKind>(
          tooltip: strings.isZh ? '课堂反馈' : 'Classroom feedback',
          child: RealtimeDockItem(
            icon: Icons.emoji_emotions_outlined,
            label: strings.isZh ? '课堂反馈' : 'Classroom feedback',
            showLabel: showLabel,
          ),
          onSelected: (kind) => controller.sendClassroomFeedback(kind),
          itemBuilder: (_) => [
            for (final kind in ClassroomFeedbackKind.values)
              PopupMenuItem(value: kind, child: Text(kind.name)),
          ],
        );
      },
    );
  }
}

/// Ready-to-use tabbed Classroom Management panel for conference sidebars or sheets.
class RealtimeClassroomPanel extends StatefulWidget {
  const RealtimeClassroomPanel({super.key, this.onClose});
  final VoidCallback? onClose;

  @override
  State<RealtimeClassroomPanel> createState() => _RealtimeClassroomPanelState();
}

class _RealtimeClassroomPanelState extends State<RealtimeClassroomPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 4,
    vsync: this,
  );

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = RealtimeStrings.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: isDark ? const Color(0xFF2C3240) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    labelColor: theme.colorScheme.onSurface,
                    unselectedLabelColor: RealtimeUiTokens.textMuted,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: [
                      Tab(text: strings.classroomQuestions),
                      Tab(text: strings.classroomHands),
                      Tab(text: strings.classroomRoster),
                      Tab(text: strings.classroomActivities),
                    ],
                  ),
                ),
              ),
              if (widget.onClose != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: strings.closePanel,
                  onPressed: widget.onClose,
                  iconSize: 18,
                  style: IconButton.styleFrom(
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.10)
                        : Colors.black.withValues(alpha: 0.06),
                    padding: const EdgeInsets.all(6),
                    minimumSize: const Size(28, 28),
                  ),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ],
          ),
        ),
        Divider(
          height: 1,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              Column(
                children: [
                  Expanded(child: RealtimeClassroomQuestions()),
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: RealtimeClassroomQuestionComposer(),
                  ),
                ],
              ),
              RealtimeClassroomHandQueue(),
              RealtimeClassroomRoster(),
              RealtimeClassroomActivityList(),
            ],
          ),
        ),
      ],
    );
  }
}
