import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';
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
    this.initialSharedContentMode,
  });

  final RealtimeRoom room;
  final MediaLocalPreviewSettings initialMediaSettings;

  /// Pre-join display hint. The connected backend metadata / role is
  /// authoritative; this hint never confers Live broadcaster permissions.
  final MediaRoomMode? roomMode;

  /// Shared-content mode requested by the Pre-Join entry intent.
  final SharedContentMode? initialSharedContentMode;

  static bool isLiveSession(RealtimeRoom room) {
    return RealtimeRoomView.isLiveSession(room);
  }

  @override
  Widget build(BuildContext context) {
    if (isLiveSession(room)) {
      return DemoComposableLivePage(
        room: room,
        initialSettings: initialMediaSettings,
      );
    }
    return DemoComposableMeetingPage(
      room: room,
      initialSettings: initialMediaSettings,
      initialSharedContentMode: initialSharedContentMode,
    );
  }
}
