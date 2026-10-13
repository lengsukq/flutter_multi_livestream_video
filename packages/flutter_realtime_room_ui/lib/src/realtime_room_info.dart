import 'package:flutter/material.dart';
import 'realtime_room_ui_scope.dart';

class RealtimeRoomInfo extends StatelessWidget {
  const RealtimeRoomInfo({super.key, this.style});
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    return Text(controller.room.roomCode, style: style);
  }
}

/// Connection status that can be placed beside the title or over the video.
///
/// Renders as a [RealtimePill] so it matches the surrounding glassmorphic
/// header instead of the default Material chip, with a localized label.
