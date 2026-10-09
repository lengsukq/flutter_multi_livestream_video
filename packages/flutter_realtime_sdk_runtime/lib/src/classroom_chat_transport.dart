import 'package:flutter_realtime_live_core/flutter_realtime_live_core.dart';
import 'dart:math';

import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_classroom_core/flutter_realtime_classroom_core.dart';

/// Product IM transport for authoritative classroom revision invalidation.
/// The chat adapter filters frames from the user-facing ChatSession timeline.
/// It cannot grant speaking rights; it can only ask the SDK to refresh.
class ClassroomChatRevisionTransport
    implements ClassroomRevisionTransport, LiveRevisionTransport {
  ClassroomChatRevisionTransport(
    this.chat, {
    required this.roomCode,
    this.eventType = 'classroom.state.changed',
  });
  final ChatSystemMessaging chat;
  final String roomCode;
  final String eventType;
  static final _random = Random.secure();

  @override
  Stream<int> get revisions => chat.systemMessages
      .map(
        (raw) =>
            ClassroomRevisionEvent.decode(
              raw,
              expectedRoomCode: roomCode,
              expectedType: eventType,
              nowMs: DateTime.now().millisecondsSinceEpoch,
            )?.revision ??
            -1,
      )
      .where((revision) => revision >= 0);

  @override
  Future<void> publish(int revision) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await chat.sendSystemMessage(
      ClassroomRevisionEvent(
        roomCode: roomCode,
        eventType: eventType,
        revision: revision,
        timestampMs: timestamp,
        eventId: '$timestamp-${_random.nextInt(1 << 32)}',
      ).encode(),
    );
  }

  @override
  Future<void> dispose() async {}
}
