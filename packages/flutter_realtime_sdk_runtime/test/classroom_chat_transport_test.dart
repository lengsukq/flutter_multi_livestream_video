import 'dart:async';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSystemChat implements ChatSystemMessaging {
  final controller = StreamController<String>.broadcast();
  final outbound = <String>[];
  @override
  Stream<String> get systemMessages => controller.stream;
  @override
  Future<void> sendSystemMessage(String message) async {
    outbound.add(message);
  }
}

void main() {
  test('product Chat transport validates room and event envelope', () async {
    final chat = _FakeSystemChat();
    final transport = ClassroomChatRevisionTransport(chat, roomCode: 'lesson1');
    final revisions = <int>[];
    final sub = transport.revisions.listen(revisions.add);
    final now = DateTime.now().millisecondsSinceEpoch;
    chat.controller.add(
      ClassroomRevisionEvent(
        roomCode: 'lesson1',
        revision: 3,
        eventId: 'event-3',
        timestampMs: now,
      ).encode(),
    );
    chat.controller.add(
      ClassroomRevisionEvent(
        roomCode: 'other',
        revision: 999,
        eventId: 'event-4',
        timestampMs: now,
      ).encode(),
    );
    await Future<void>.delayed(Duration.zero);
    expect(revisions, [3]);
    await transport.publish(4);
    expect(chat.outbound, hasLength(1));
    final parsed = ClassroomRevisionEvent.decode(
      chat.outbound.single,
      expectedRoomCode: 'lesson1',
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
    expect(parsed?.revision, 4);
    await sub.cancel();
    await transport.dispose();
    await chat.controller.close();
  });
  test(
    'live hints are isolated from classroom hints on the same chat',
    () async {
      final chat = _FakeSystemChat();
      final classroom = ClassroomChatRevisionTransport(chat, roomCode: 'room1');
      final live = ClassroomChatRevisionTransport(
        chat,
        roomCode: 'room1',
        eventType: 'live.interaction.changed',
      );
      final classroomRevisions = <int>[], liveRevisions = <int>[];
      final c = classroom.revisions.listen(classroomRevisions.add);
      final l = live.revisions.listen(liveRevisions.add);
      await live.publish(2);
      chat.controller.add(chat.outbound.single);
      chat.controller.add(
        ClassroomRevisionEvent(
          roomCode: 'room1',
          revision: 3,
          eventId: 'classroom-3',
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        ).encode(),
      );
      await Future<void>.delayed(Duration.zero);
      expect(classroomRevisions, [3]);
      expect(liveRevisions, [2]);
      await c.cancel();
      await l.cancel();
      await chat.controller.close();
    },
  );
}
