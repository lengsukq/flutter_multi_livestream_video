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
    final transport = ChatInteractionRevisionTransport(
      chat,
      roomCode: 'lesson1',
      eventType: 'classroom.state.changed',
    );
    final revisions = <int>[];
    final sub = transport.revisions.listen(revisions.add);
    chat.controller.add(
      InteractionRevisionHintCodec.encode(
        'lesson1',
        3,
        type: 'classroom.state.changed',
      ),
    );
    chat.controller.add(
      InteractionRevisionHintCodec.encode(
        'other',
        999,
        type: 'classroom.state.changed',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(revisions, [3]);
    await transport.publish(4);
    expect(chat.outbound, hasLength(1));
    final parsed = InteractionRevisionHintCodec.decode(
      chat.outbound.single,
      roomCode: 'lesson1',
      expectedType: 'classroom.state.changed',
    );
    expect(parsed, 4);
    await sub.cancel();
    await transport.dispose();
    await chat.controller.close();
  });
  test(
    'live hints are isolated from classroom hints on the same chat',
    () async {
      final chat = _FakeSystemChat();
      final classroom = ChatInteractionRevisionTransport(
        chat,
        roomCode: 'room1',
        eventType: 'classroom.state.changed',
      );
      final live = ChatInteractionRevisionTransport(
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
        InteractionRevisionHintCodec.encode(
          'room1',
          3,
          type: 'classroom.state.changed',
        ),
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
