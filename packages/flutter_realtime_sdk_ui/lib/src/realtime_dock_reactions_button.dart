import 'package:flutter_realtime_classroom_preset/flutter_realtime_classroom_preset.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'room_ui_controller.dart';
import 'realtime_dock_item.dart';
import 'realtime_dock_reaction_action.dart';
import 'meeting_dock_reaction_emoji_button.dart';
import 'meeting_dock_meeting_dock_modal_sheet.dart';

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
        unawaited(
          showModalBottomSheet<void>(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (sheetContext) => MeetingDockMeetingDockModalSheet(
              title: strings.reactions,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (canFeedback) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          for (final kind in ClassroomFeedbackKind.values)
                            MeetingDockReactionEmojiButton(
                              emoji: switch (kind) {
                                ClassroomFeedbackKind.understood => '👍',
                                ClassroomFeedbackKind.great => '🔥',
                                ClassroomFeedbackKind.idea => '💡',
                                ClassroomFeedbackKind.question => '❓',
                                ClassroomFeedbackKind.clap => '👏',
                              },
                              label: strings.isZh
                                  ? switch (kind) {
                                      ClassroomFeedbackKind.understood => '听懂了',
                                      ClassroomFeedbackKind.great => '太棒了',
                                      ClassroomFeedbackKind.idea => '有想法',
                                      ClassroomFeedbackKind.question => '没听懂',
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
                    const SizedBox(height: 10),
                  ],
                  if (canRaise || onWave != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
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
                                    borderRadius: BorderRadius.circular(14),
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
                                    borderRadius: BorderRadius.circular(14),
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
                    const SizedBox(height: 6),
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
                ],
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
