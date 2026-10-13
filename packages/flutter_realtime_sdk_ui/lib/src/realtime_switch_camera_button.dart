import 'package:flutter_realtime_room_ui/flutter_realtime_room_ui.dart' show RealtimeRoomUiAction;
import 'package:flutter/material.dart';
import 'realtime_room_action_button.dart';

class RealtimeSwitchCameraButton extends StatelessWidget {
  const RealtimeSwitchCameraButton({super.key, this.iconOnly = false});
  final bool iconOnly;
  @override
  Widget build(BuildContext context) => RealtimeRoomActionButton(
    action: RealtimeRoomUiAction.switchCamera,
    iconOnly: iconOnly,
  );
}

/// Audio output picker without owning a screen, route or SDK session.
/// Providers may offer listing but not device selection: those entries stay
/// visible as read-only capabilities instead of silently dispatching commands.
