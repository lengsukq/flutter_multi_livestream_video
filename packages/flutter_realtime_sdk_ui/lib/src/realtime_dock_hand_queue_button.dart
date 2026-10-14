import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';

import 'room_ui_controller.dart';
import 'realtime_dock_item.dart';

/// Teacher-only entry point to the hand-raise queue.
///
/// The host owns the panel placement; this component only exposes the
/// classroom state and a callback for opening the queue.
class RealtimeDockHandQueueButton extends StatelessWidget {
  const RealtimeDockHandQueueButton({
    super.key,
    required this.onPressed,
    this.showLabel = true,
  });

  final VoidCallback onPressed;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    final strings = RealtimeStrings.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.classroomState;
        if (state == null || !controller.canGrantSpeak) {
          return const SizedBox.shrink();
        }
        final pending = state.raisedHands.length;
        return RealtimeDockItem(
          icon: pending > 0 ? Icons.pan_tool_rounded : Icons.pan_tool_outlined,
          label: strings.classroomHands,
          tooltip: strings.isZh ? '举手申请：$pending' : 'Hand requests: $pending',
          badgeCount: pending,
          isActive: pending > 0,
          activeColor: RealtimeUiTokens.primary,
          showLabel: showLabel,
          onPressed: onPressed,
        );
      },
    );
  }
}
