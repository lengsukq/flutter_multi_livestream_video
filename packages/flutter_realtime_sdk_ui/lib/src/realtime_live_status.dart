import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'room_ui_controller.dart';

class RealtimeLiveStatus extends StatelessWidget {
  const RealtimeLiveStatus({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    final strings = RealtimeStrings.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isViewer = controller.room.media.role == MediaRole.viewer;
        return Chip(
          avatar: Icon(
            isViewer ? Icons.visibility_outlined : Icons.sensors,
            size: 16,
          ),
          label: Text(
            '${isViewer ? (strings.isZh ? '观看中' : 'Watching') : strings.liveStatus} · ${controller.snapshot.participants.length}',
          ),
        );
      },
    );
  }
}

/// Displays a short-lived heart for each confirmed live-like update.
/// Animations belong to this widget, while one shared controller owns events.
