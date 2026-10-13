import 'package:flutter_realtime_room_ui/flutter_realtime_room_ui.dart'
    show RealtimeRoomUiAction;
import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'room_ui_controller.dart';
import 'realtime_dock_item.dart';

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
                  try {
                    await controller.setHandRaised(!raised);
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                        SnackBar(content: Text(error.toString())),
                      );
                    }
                  }
                },
        );
      },
    );
  }
}

/// Dock feedback popup button aligned with [RealtimeDockItem] geometry.
