import 'package:flutter_realtime_classroom_preset/flutter_realtime_classroom_preset.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'room_ui_controller.dart';
import 'realtime_dock_item.dart';

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
          onSelected: (kind) {
            unawaited(
              controller
                  .sendClassroomFeedback(kind)
                  .catchError(controller.reportActionError),
            );
          },
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
