import 'package:flutter_realtime_room_ui/flutter_realtime_room_ui.dart'
    show RealtimeRoomUiAction;
import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'room_control_components.dart';
import 'realtime_dock_item.dart';

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
          icon: active ? Icons.mic_none_rounded : Icons.mic_off_rounded,
          label: active ? strings.mute : strings.unmute,
          isLoading: pending,
          onPressed: onPressed,
          showLabel: showLabel,
        );
      },
    );
  }
}

/// Dock Camera button with proper label, active state and video toggle.
