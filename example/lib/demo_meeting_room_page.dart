import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'demo_composable_meeting_page.dart';
import 'demo_composable_live_page.dart';

/// Demo room view driven entirely by the room and capability objects returned
/// by the high-level SDK.
class MeetingRoomPage extends StatelessWidget {
  const MeetingRoomPage({
    super.key,
    required this.room,
    required this.initialMediaSettings,
    this.roomMode,
  });

  final RealtimeRoom room;
  final MediaLocalPreviewSettings initialMediaSettings;
  final MediaRoomMode? roomMode;

  @override
  Widget build(BuildContext context) {
    // Both Meeting and Live layouts are now owned by the Demo. The default
    // RealtimeRoomView remains available for quick SDK integration.
    if (roomMode == MediaRoomMode.broadcast ||
        room.media.role == MediaRole.viewer) {
      return DemoComposableLivePage(
        room: room,
        initialSettings: initialMediaSettings,
      );
    }
    return DemoComposableMeetingPage(
      room: room,
      initialSettings: initialMediaSettings,
    );
  }
}
