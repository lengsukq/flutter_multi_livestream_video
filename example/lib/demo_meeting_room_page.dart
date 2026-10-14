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

  /// Pre-join display hint. The connected backend metadata / role is
  /// authoritative; this hint never confers Live broadcaster permissions.
  final MediaRoomMode? roomMode;

  static bool isLiveSession(RealtimeRoom room) {
    // Route by *connected* backend mode / token role, never the mode a guest
    // selected before joining. A stale broadcast hint must not turn an
    // ordinary Meeting participant into a Live presenter.
    final backendMode = room.media.backendMetadata['roomMode'];
    return backendMode == MediaRoomMode.broadcast.wireName ||
        (backendMode != MediaRoomMode.meeting.wireName &&
            room.media.role != MediaRole.participant);
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
    );
  }
}
