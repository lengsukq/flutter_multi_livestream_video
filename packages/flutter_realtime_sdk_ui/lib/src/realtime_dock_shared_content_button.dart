import 'package:flutter_realtime_room_ui/flutter_realtime_room_ui.dart'
    show RealtimeRoomUiAction;
import 'package:flutter_realtime_shared_content_preset/flutter_realtime_shared_content_preset.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'room_control_components.dart';
import 'room_ui_controller.dart';
import 'realtime_dock_item.dart';
import 'realtime_share_option_card.dart';
import 'meeting_dock_meeting_dock_modal_sheet.dart';

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
          final isDark = theme.brightness == Brightness.dark;
          unawaited(
            showModalBottomSheet<void>(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (sheetContext) => MeetingDockMeetingDockModalSheet(
                title: strings.chooseContentToShare,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RealtimeShareOptionCard(
                        title: strings.whiteboard,
                        subtitle: strings.whiteboardDescription,
                        icon: Icons.draw_rounded,
                        iconColor: theme.colorScheme.primary,
                        iconBackgroundColor: theme.colorScheme.primary
                            .withValues(alpha: 0.12),
                        isSelected: mode == SharedContentMode.whiteboard,
                        activeBadgeText: strings.activeSharing,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          unawaited(
                            shared.selectMode(SharedContentMode.whiteboard),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      RealtimeShareOptionCard(
                        title: strings.screenShare,
                        subtitle: strings.shareScreenDescription,
                        icon: Icons.screen_share_outlined,
                        iconColor: RealtimeUiTokens.iosGreen,
                        iconBackgroundColor: RealtimeUiTokens.iosGreen
                            .withValues(alpha: 0.12),
                        isSelected: mode == SharedContentMode.screen,
                        enabled: shared.canShare,
                        activeBadgeText: strings.activeSharing,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          unawaited(
                            shared.selectMode(SharedContentMode.screen),
                          );
                        },
                      ),
                      if (isSharing) ...[
                        const SizedBox(height: 14),
                        Container(
                          height: 1,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: isDark ? 0.08 : 0.05),
                        ),
                        const SizedBox(height: 8),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              unawaited(
                                shared.selectMode(SharedContentMode.members),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.error.withValues(
                                  alpha: isDark ? 0.15 : 0.08,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: theme.colorScheme.error.withValues(
                                    alpha: 0.25,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.stop_screen_share_rounded,
                                    size: 20,
                                    color: theme.colorScheme.error,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    strings.stopSharing,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
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
