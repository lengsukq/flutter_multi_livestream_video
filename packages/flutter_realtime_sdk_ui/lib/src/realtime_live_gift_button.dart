import 'package:flutter/material.dart';
import 'package:flutter_realtime_live_ui/flutter_realtime_live_ui.dart';
import 'package:flutter_realtime_live_preset/flutter_realtime_live_preset.dart';
import 'room_ui_controller.dart';

class RealtimeLiveGiftButton extends StatelessWidget {
  const RealtimeLiveGiftButton({super.key, this.showLabel = false});

  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final session = RealtimeRoomUiScope.of(context).room.liveInteractions;
    if (session == null) return const SizedBox.shrink();
    return LiveGiftControlButton(
      key: ObjectKey(session),
      session: session,
      showLabel: showLabel,
    );
  }
}

/// A live gift ticker without any fixed Stack position.
