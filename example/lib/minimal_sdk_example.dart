import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';

/// Minimal application-facing flow.
///
/// The full showcase uses [RealtimeSdk.standard], which selects the built-in
/// provider driver for the current platform inside the SDK.
/// A real application normally creates [RealtimeSdk.standard] once; provider
/// and platform routing stay inside that SDK instance.
Future<void> openMinimalRealtimeRoom({
  required BuildContext context,
  required RealtimeSdk sdk,
  required String roomCode,
  required String participantId,
  required String displayName,
}) async {
  final room = await sdk.joinRoom(
    roomCode: roomCode,
    user: MediaIdentity(userId: participantId, displayName: displayName),
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
