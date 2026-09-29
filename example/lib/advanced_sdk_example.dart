import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';

/// Advanced API example for applications that need direct [RealtimeSdk]
/// orchestration rather than the simplified [Realtime] facade.
Future<void> openAdvancedRealtimeRoom({
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
