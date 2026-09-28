import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';

/// Minimal application-facing flow.
///
/// The full showcase keeps provider registration in provider_adapters.dart.
/// A real application creates [RealtimeSdk] once with its provider plugins.
Future<void> openMinimalRealtimeRoom({
  required BuildContext context,
  required RealtimeSdk sdk,
  required String roomCode,
  required String participantId,
  required String displayName,
}) async {
  final room = await sdk.joinRoom(
    roomCode: roomCode,
    user: MediaIdentity(
      userId: participantId,
      displayName: displayName,
    ),
  );
  if (!context.mounted) {
    await room.dispose();
    return;
  }

  try {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RealtimeRoomView(
          room: room,
          config: const MediaRoomViewConfig(showChat: true),
        ),
      ),
    );
  } finally {
    await room.dispose();
  }
}
