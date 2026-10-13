import 'package:flutter_realtime_room_ui/flutter_realtime_room_ui.dart'
    show RealtimeRoomUiAction;
import 'package:flutter/material.dart';
import 'realtime_room_action_button.dart';

class RealtimeMicrophoneButton extends StatelessWidget {
  const RealtimeMicrophoneButton({super.key, this.iconOnly = false});
  final bool iconOnly;
  @override
  Widget build(BuildContext context) => RealtimeRoomActionButton(
    action: RealtimeRoomUiAction.microphone,
    iconOnly: iconOnly,
  );
}
