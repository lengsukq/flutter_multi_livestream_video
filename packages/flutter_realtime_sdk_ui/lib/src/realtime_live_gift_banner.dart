import 'package:flutter/material.dart';
import 'package:flutter_realtime_live_ui/flutter_realtime_live_ui.dart';
import 'package:flutter_realtime_live_preset/flutter_realtime_live_preset.dart';
import 'room_ui_controller.dart';

class RealtimeLiveGiftBanner extends StatelessWidget {
  const RealtimeLiveGiftBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final session = RealtimeRoomUiScope.of(context).room.liveInteractions;
    return session == null
        ? const SizedBox.shrink()
        : LiveGiftBanner(key: ObjectKey(session), session: session);
  }
}

/// Like counter and send button. Shared controller prevents duplicate sends.
