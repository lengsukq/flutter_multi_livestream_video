import 'dart:convert';
import 'package:flutter_realtime_classroom_core/flutter_realtime_classroom_core.dart';
import 'package:test/test.dart';

void main() {
  test('classroom events are versioned, room-bound and expire', () {
    const event = ClassroomRevisionEvent(
      roomCode: 'alpha',
      revision: 12,
      eventId: 'test-event-1',
      timestampMs: 100000,
    );
    final payload = event.encode();
    final result = ClassroomRevisionEvent.decode(
      payload,
      expectedRoomCode: 'alpha',
      nowMs: 100001,
    );
    expect(result?.revision, 12);
    expect(
      ClassroomRevisionEvent.decode(
        payload,
        expectedRoomCode: 'beta',
        nowMs: 100001,
      ),
      isNull,
    );
    expect(
      ClassroomRevisionEvent.decode(
        payload,
        expectedRoomCode: 'alpha',
        nowMs: 900000,
      ),
      isNull,
    );
    expect(
      ClassroomRevisionEvent.decode(
        jsonEncode({...jsonDecode(payload) as Map, 'v': 999}),
        expectedRoomCode: 'alpha',
        nowMs: 100001,
      ),
      isNull,
    );
    expect(
      ClassroomRevisionEvent.decode(
        'not json',
        expectedRoomCode: 'alpha',
        nowMs: 100001,
      ),
      isNull,
    );
    expect(
      ClassroomRevisionEvent.decode(
        '9' * 1025,
        expectedRoomCode: 'alpha',
        nowMs: 100001,
      ),
      isNull,
    );
  });
}
