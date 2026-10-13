import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'realtime_room_ui_scope.dart';

class RealtimeVideoTile extends StatelessWidget {
  const RealtimeVideoTile({
    super.key,
    required this.participant,
    this.onTap,
    this.isFocused = false,
    this.showNameTag = true,
    this.borderless = false,
    this.fit = BoxFit.contain,
  });

  final MediaParticipant participant;
  final VoidCallback? onTap;
  final bool isFocused;
  final bool showNameTag;
  final bool borderless;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    return MediaParticipantTile(
      participant: participant,
      renderer: controller.room.renderer,
      isFocused: isFocused,
      onTap: onTap,
      showNameTag: showNameTag,
      borderless: borderless,
      fit: fit,
    );
  }
}

/// Only renders media tiles. The application decides its size and position.
