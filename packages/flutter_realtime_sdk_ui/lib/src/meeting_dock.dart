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
    final style = RealtimeStyle.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.classroomState?.capabilities.canSendFeedback != true) {
          return const SizedBox.shrink();
        }
        return PopupMenuButton<ClassroomFeedbackKind>(
          tooltip: strings.classroomFeedback,
          color: style.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: style.border),
          ),
          child: RealtimeDockItem(
            icon: Icons.emoji_emotions_outlined,
            label: strings.classroomFeedback,
            showLabel: showLabel,
          ),
          onSelected: (kind) => controller.sendClassroomFeedback(kind),
          itemBuilder: (_) => [
            for (final kind in ClassroomFeedbackKind.values)
              PopupMenuItem(
                value: kind,
                child: Text(
                  strings.isZh
                      ? switch (kind) {
                          ClassroomFeedbackKind.understood => '听懂了 👍',
                          ClassroomFeedbackKind.great => '太棒了 🔥',
                          ClassroomFeedbackKind.idea => '有想法 💡',
                          ClassroomFeedbackKind.question => '没听懂 ❓',
                          ClassroomFeedbackKind.clap => '鼓掌 👏',
                        }
                      : kind.name,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Action callback definition for custom reactions inside [RealtimeDockReactionsButton].
class RealtimeDockReactionAction {
  const RealtimeDockReactionAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// Consolidated reactions button for [RealtimeMeetingDock].
///
/// Merges quick emoji feedback (understood, great, idea, question, clap),
/// raise hand toggle (with active orange status indicator), and optional custom
/// interactions such as waving into a single clean popup menu.
class RealtimeDockReactionsButton extends StatelessWidget {
  const RealtimeDockReactionsButton({
    super.key,
    this.showLabel = true,
    this.onWave,
    this.extraActions = const [],
  });

  final bool showLabel;
  final VoidCallback? onWave;
  final List<RealtimeDockReactionAction> extraActions;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.maybeOf(context);
    final strings = RealtimeStrings.of(context);

    Widget buildContent(ClassroomState? state) {
      final raised =
          state != null &&
          state.students.any(
            (s) => s.userId == state.selfUserId && s.handRaised,
          );
      final canRaise = controller?.canRaiseHand ?? false;
      final canFeedback = state?.capabilities.canSendFeedback == true;

      void openMenu() {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        unawaited(
          showModalBottomSheet<void>(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (sheetContext) => SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? Colors.white12
                        : theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.5,
                          ),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: isDark
                      ? const Color(0xFF1E2533)
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          children: [
                            Text(
                              strings.reactions,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.close_rounded, size: 20),
                              onPressed: () => Navigator.pop(sheetContext),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      if (canFeedback) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              for (final kind in ClassroomFeedbackKind.values)
                                _ReactionEmojiButton(
                                  emoji: switch (kind) {
                                    ClassroomFeedbackKind.understood => '👍',
                                    ClassroomFeedbackKind.great => '🔥',
                                    ClassroomFeedbackKind.idea => '💡',
                                    ClassroomFeedbackKind.question => '❓',
                                    ClassroomFeedbackKind.clap => '👏',
                                  },
                                  label: strings.isZh
                                      ? switch (kind) {
                                          ClassroomFeedbackKind.understood =>
                                            '听懂了',
                                          ClassroomFeedbackKind.great => '太棒了',
                                          ClassroomFeedbackKind.idea => '有想法',
                                          ClassroomFeedbackKind.question =>
                                            '没听懂',
                                          ClassroomFeedbackKind.clap => '鼓掌',
                                        }
                                      : kind.name,
                                  onTap: () {
                                    Navigator.pop(sheetContext);
                                    if (controller != null) {
                                      unawaited(
                                        controller.sendClassroomFeedback(kind),
                                      );
                                    }
                                  },
                                ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                      ],
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            if (canRaise)
                              Expanded(
                                child: FilledButton.tonalIcon(
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    backgroundColor: raised
                                        ? RealtimeUiTokens.iosOrange.withValues(
                                            alpha: 0.2,
                                          )
                                        : null,
                                    foregroundColor: raised
                                        ? RealtimeUiTokens.iosOrange
                                        : null,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: Icon(
                                    raised
                                        ? Icons.pan_tool_rounded
                                        : Icons.pan_tool_outlined,
                                    size: 20,
                                    color: raised
                                        ? RealtimeUiTokens.iosOrange
                                        : null,
                                  ),
                                  label: Text(
                                    raised
                                        ? strings.lowerHand
                                        : strings.raiseHand,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(sheetContext);
                                    if (controller != null) {
                                      unawaited(
                                        controller.setHandRaised(!raised),
                                      );
                                    }
                                  },
                                ),
                              ),
                            if (canRaise && onWave != null)
                              const SizedBox(width: 12),
                            if (onWave != null)
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.waving_hand_outlined,
                                    size: 20,
                                  ),
                                  label: Text(
                                    strings.wave,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(sheetContext);
                                    onWave!();
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (extraActions.isNotEmpty) ...[
                        const Divider(height: 1),
                        for (final action in extraActions)
                          ListTile(
                            leading: Icon(action.icon),
                            title: Text(action.label),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              action.onTap();
                            },
                          ),
                      ],
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }

      return RealtimeDockItem(
        icon: raised ? Icons.pan_tool_rounded : Icons.add_reaction_outlined,
        label: raised ? strings.handRaised : strings.reactions,
        isActive: raised,
        activeColor: RealtimeUiTokens.iosOrange,
        showLabel: showLabel,
        onPressed: openMenu,
      );
    }

    if (controller != null) {
      return ListenableBuilder(
        listenable: controller,
        builder: (context, _) => buildContent(controller.classroomState),
      );
    }

    return buildContent(null);
  }
}

class _ReactionEmojiButton extends StatelessWidget {
  const _ReactionEmojiButton({
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: 0.06,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An item presented inside [RealtimeDockMoreButton]'s menu.
class RealtimeDockMoreItem {
  const RealtimeDockMoreItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.isActive = false,
    this.isDanger = false,
    this.badgeText,
    this.showBadgeDot = false,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isActive;
  final bool isDanger;
  final String? badgeText;
  final bool showBadgeDot;
  final bool enabled;
}

/// Dock "More" button consolidating secondary media controls and tools
/// (flip camera, background effects, recording, teacher tools, etc.).
class RealtimeDockMoreButton extends StatelessWidget {
  const RealtimeDockMoreButton({
    super.key,
    this.items = const [],
    this.children = const [],
    this.showLabel = true,
    this.hasActiveBadge = false,
  });

  final List<RealtimeDockMoreItem> items;
  final List<Widget> children;
  final bool showLabel;
  final bool hasActiveBadge;

  @override
  Widget build(BuildContext context) {
    final strings = RealtimeStrings.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    void openMenu() {
      unawaited(
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (sheetContext) => SafeArea(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white12
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 20,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: isDark
                    ? const Color(0xFF1E2533)
                    : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Row(
                        children: [
                          Text(
                            strings.more,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close_rounded, size: 20),
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: [
                          for (var i = 0; i < items.length; i++) ...[
                            Builder(
                              builder: (context) {
                                final item = items[i];
                                final itemColor = item.isDanger
                                    ? const Color(0xFFFF3B30)
                                    : (item.isActive
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurface);
                                return ListTile(
                                  enabled: item.enabled,
                                  leading: Badge(
                                    isLabelVisible:
                                        item.showBadgeDot ||
                                        (item.badgeText != null &&
                                            item.badgeText!.isNotEmpty),
                                    label: item.badgeText != null
                                        ? Text(item.badgeText!)
                                        : null,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color:
                                            (item.isDanger
                                                    ? const Color(0xFFFF3B30)
                                                    : (item.isActive
                                                          ? theme
                                                                .colorScheme
                                                                .primary
                                                          : (isDark
                                                                ? Colors.white
                                                                : Colors
                                                                      .black)))
                                                .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        item.icon,
                                        color: itemColor,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    item.title,
                                    style: TextStyle(
                                      color: itemColor,
                                      fontWeight: item.isActive || item.isDanger
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: item.subtitle != null
                                      ? Text(
                                          item.subtitle!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        )
                                      : null,
                                  onTap: () {
                                    Navigator.pop(sheetContext);
                                    item.onTap();
                                  },
                                );
                              },
                            ),
                            if (i < items.length - 1 || children.isNotEmpty)
                              const Divider(height: 1, indent: 56),
                          ],
                          ...children,
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return RealtimeDockItem(
      icon: Icons.more_horiz_rounded,
      label: strings.more,
      showBadgeDot: hasActiveBadge,
      showLabel: showLabel,
      onPressed: (items.isEmpty && children.isEmpty) ? null : openMenu,
    );
  }
}

/// Ready-to-use tabbed Classroom Management panel for conference sidebars or sheets.
class RealtimeClassroomPanel extends StatefulWidget {
  const RealtimeClassroomPanel({
    super.key,
    this.onClose,
    this.showHeader = true,
  });
  final VoidCallback? onClose;
  final bool showHeader;

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
    final style = RealtimeStyle.of(context);
    final controller = RealtimeRoomUiScope.of(context);

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
                    color: style.surfaceSubtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: style.border),
                  ),
                  child: ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) {
                      final state = controller.classroomState;
                      final pendingQ = state?.stats.pendingQuestions ?? 0;
                      final raisedHands = state?.stats.handsRaised ?? 0;

                      return TabBar(
                        controller: _tabController,
                        dividerColor: Colors.transparent,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: style.surface,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        labelColor: style.primary,
                        unselectedLabelColor: style.textMuted,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                        labelStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        tabs: [
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(strings.classroomQuestions),
                                if (pendingQ > 0) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: style.primary,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '$pendingQ',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(strings.classroomHands),
                                if (raisedHands > 0) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: RealtimeUiTokens.iosOrange,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '$raisedHands',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Tab(text: strings.classroomRoster),
                          Tab(text: strings.classroomActivities),
                        ],
                      );
                    },
                  ),
                ),
              ),
              if (widget.showHeader && widget.onClose != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: strings.closePanel,
                  onPressed: widget.onClose,
                  iconSize: 18,
                  style: IconButton.styleFrom(
                    backgroundColor: style.surfaceSubtle,
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
            children: [
              Column(
                children: [
                  const Expanded(child: RealtimeClassroomQuestions()),
                  ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) {
                      if (!controller.canAskQuestion) {
                        return const SizedBox.shrink();
                      }
                      return const Padding(
                        padding: EdgeInsets.fromLTRB(10, 4, 10, 10),
                        child: RealtimeClassroomQuestionComposer(),
                      );
                    },
                  ),
                ],
              ),
              const RealtimeClassroomHandQueue(),
              const RealtimeClassroomRoster(),
              const RealtimeClassroomActivityList(),
            ],
          ),
        ),
      ],
    );
  }
}
