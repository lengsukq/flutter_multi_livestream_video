import 'package:flutter_realtime_room_ui/flutter_realtime_room_ui.dart' show RealtimeRoomUiAction;
import 'package:flutter/material.dart';
import 'realtime_room_action_button.dart';

class RealtimeScreenShareButton extends StatelessWidget {
  const RealtimeScreenShareButton({super.key, this.iconOnly = false});
  final bool iconOnly;
  @override
  Widget build(BuildContext context) => RealtimeRoomActionButton(
    action: RealtimeRoomUiAction.screenShare,
    iconOnly: iconOnly,
  );
}

/// Independent leave button; caller decides confirmation and navigation.
