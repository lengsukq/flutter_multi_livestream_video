import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';

/// Minimal application-facing flow using the simplified facade.
Future<void> openMinimalRealtimeRoom({
  required BuildContext context,
  required Realtime realtime,
  required String roomCode,
  required String participantId,
  required String displayName,
}) async {
  final connection = await realtime.open(
    RealtimeRequest.join(
      type: RealtimeExperience.meeting,
      roomCode: roomCode,
      user: RealtimeUser(id: participantId, name: displayName),
    ),
  );
  final room = connection.mediaRoom!;
  if (!context.mounted) {
    await connection.dispose();
    return;
  }

  try {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RealtimeRoomView(
          room: room,
          config: const RealtimeRoomViewConfig(showChat: true),
        ),
      ),
    );
  } finally {
    await connection.dispose();
  }
}
