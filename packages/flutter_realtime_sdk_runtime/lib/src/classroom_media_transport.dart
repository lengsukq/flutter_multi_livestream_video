import 'package:flutter_realtime_live_core/flutter_realtime_live_core.dart';
import 'dart:math';

import 'package:flutter_realtime_classroom_core/flutter_realtime_classroom_core.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

/// RTC Data is only a fast invalidation hint, never an authority for a grant,
/// answer or student identity. A trusted HTTP snapshot remains the source
/// of truth and polling survives providers that cannot send RTC Data.
class ClassroomMediaRevisionTransport
    implements ClassroomRevisionTransport, LiveRevisionTransport {
  ClassroomMediaRevisionTransport(
    this.session, {
    required this.roomCode,
    this.eventType = 'classroom.state.changed',
  });
  final MediaSession session;
  final String roomCode;
  final String eventType;
  static const topic = 'classroom.v1';
  String get _topic =>
      eventType == 'classroom.state.changed' ? topic : 'live.interaction.v1';
  static final _random = Random.secure();

  @override
  Stream<int> get revisions => session.dataMessages
      .where((message) => message.topic == _topic)
      .map(
        (message) =>
            ClassroomRevisionEvent.decode(
              message.message,
              expectedRoomCode: roomCode,
              expectedType: eventType,
              nowMs: DateTime.now().millisecondsSinceEpoch,
            )?.revision ??
            -1,
      )
      .where((revision) => revision >= 0);

  @override
  Future<void> publish(int revision) async {
    if (!session.capabilities.canSendData) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await session.sendData(
      ClassroomRevisionEvent(
        roomCode: roomCode,
        eventType: eventType,
        revision: revision,
        eventId: '$now-${_random.nextInt(1 << 32)}',
        timestampMs: now,
      ).encode(),
      options: MediaSendOptions(topic: _topic),
    );
  }

  @override
  Future<void> dispose() async {}
}
