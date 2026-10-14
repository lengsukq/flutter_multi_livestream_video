import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'room_ui_controller.dart';
import 'realtime_role_presentation.dart';

class RealtimeLiveStatus extends StatelessWidget {
  const RealtimeLiveStatus({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    final strings = RealtimeStrings.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final role = RealtimePresentationRole.forLive(
          controller.room.media.role,
        );
        final isViewer = role == RealtimePresentationRole.liveViewer;
        return Chip(
          avatar: Icon(
            isViewer ? Icons.visibility_outlined : Icons.sensors,
            size: 16,
          ),
          label: Text(
            '${role == RealtimePresentationRole.liveHost
                ? strings.liveStatus
                : role == RealtimePresentationRole.liveViewer
                ? (strings.isZh ? '观看中' : 'Watching')
                : role.label(isZh: strings.isZh)} · ${controller.snapshot.participants.length}',
          ),
        );
      },
    );
  }
}

/// Displays a short-lived heart for each confirmed live-like update.
/// Animations belong to this widget, while one shared controller owns events.
