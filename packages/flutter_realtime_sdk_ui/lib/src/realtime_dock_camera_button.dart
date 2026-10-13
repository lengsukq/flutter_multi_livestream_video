import 'package:flutter_realtime_room_ui/flutter_realtime_room_ui.dart'
    show RealtimeRoomUiAction;
import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'room_control_components.dart';
import 'realtime_dock_item.dart';

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
