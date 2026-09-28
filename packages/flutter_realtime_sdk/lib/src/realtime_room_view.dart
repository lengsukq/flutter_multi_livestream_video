import 'package:flutter/widgets.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';

import 'realtime_room.dart';

/// Recommended ready-to-use UI for a fully resolved [RealtimeRoom].
///
/// Applications that need lower-level UI composition can continue to use
/// [MediaRoomView] directly.
class RealtimeRoomView extends StatelessWidget {
  const RealtimeRoomView({
    super.key,
    required this.room,
    this.config = const MediaRoomViewConfig(),
    this.participantBuilder,
    this.onLeave,
  });

  final RealtimeRoom room;
  final MediaRoomViewConfig config;
  final MediaParticipantBuilder? participantBuilder;
  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context) => MediaRoomView(
    room: room.media,
    renderer: room.renderer,
    chatSession: room.chat,
    config: config,
    participantBuilder: participantBuilder,
    onLeave: onLeave,
  );
}
