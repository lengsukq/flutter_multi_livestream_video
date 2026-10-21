import 'package:flutter_realtime_classroom_preset/flutter_realtime_classroom_preset.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'room_ui_controller.dart';
import 'realtime_dock_item.dart';
import 'realtime_dock_reaction_action.dart';
import 'realtime_dock_compact_menu.dart';

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
      final canFeedback = state?.capabilities.canSendFeedback == true;

      // Quick feedback is a selection, not an entire page of settings.
      return RealtimeDockCompactMenu(
        actions: [
          if (canFeedback)
            for (final kind in ClassroomFeedbackKind.values)
              RealtimeCompactMenuAction(
                label: strings.isZh
                    ? switch (kind) {
                        ClassroomFeedbackKind.understood => '听懂了',
                        ClassroomFeedbackKind.great => '太棒了',
                        ClassroomFeedbackKind.idea => '有想法',
                        ClassroomFeedbackKind.question => '没听懂',
                        ClassroomFeedbackKind.clap => '鼓掌',
                      }
                    : kind.name,
                icon: Text(switch (kind) {
                  ClassroomFeedbackKind.understood => '👍',
                  ClassroomFeedbackKind.great => '🔥',
                  ClassroomFeedbackKind.idea => '💡',
                  ClassroomFeedbackKind.question => '❓',
                  ClassroomFeedbackKind.clap => '👏',
                }, style: const TextStyle(fontSize: 18)),
                onSelected: () {
                  if (controller != null) {
                    unawaited(
                      controller
                          .sendClassroomFeedback(kind)
                          .catchError(controller.reportActionError),
                    );
                  }
                },
              ),
          if (onWave != null)
            RealtimeCompactMenuAction(
              label: strings.wave,
              icon: const Icon(Icons.waving_hand_outlined),
              dividerBefore: canFeedback,
              onSelected: onWave!,
            ),
          for (final action in extraActions)
            RealtimeCompactMenuAction(
              label: action.label,
              icon: Icon(action.icon),
              onSelected: action.onTap,
            ),
        ],
        triggerBuilder: (toggle) => RealtimeDockItem(
          icon: Icons.add_reaction_outlined,
          label: strings.reactions,
          showLabel: showLabel,
          onPressed: canFeedback || onWave != null || extraActions.isNotEmpty
              ? toggle
              : null,
        ),
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
