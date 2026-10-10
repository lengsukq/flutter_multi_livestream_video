import 'dart:async';

import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTransport implements InteractionTransport {
  final inbox = StreamController<InteractionFrame>.broadcast();
  final published = <String>[];
  InteractionCapabilities providedCapabilities = const InteractionCapabilities(
    canPublish: true,
    canSubscribe: true,
    canTarget: false,
    canSendUnreliable: false,
    maxMessageBytes: 16384,
  );
  @override
  InteractionCapabilities get capabilities => providedCapabilities;
  @override
  Stream<InteractionFrame> get frames => inbox.stream;
  @override
  Future<void> publish(
    String encoded,
    InteractionPublishOptions options,
  ) async {
    published.add(encoded);
  }

  @override
  Future<void> dispose() => inbox.close();
}

class _FakeMedia implements MediaSession, MediaDataMessenger {
  final inbound = StreamController<MediaEvent>.broadcast();
  final sent = <String>[];
  final topics = <String>[];
  @override
  String get providerId => 'fake';
  @override
  MediaCapabilities get capabilities => const MediaCapabilities(
    canSendData: true,
    canReceiveData: true,
    maxDataMessageBytes: 16384,
  );
  @override
  Stream<MediaEvent> get events => inbound.stream;
  @override
  Future<void> sendMessage(String message, {String topic = 'chat'}) async {
    sent.add(message);
    topics.add(topic);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TrustedPlane implements InteractionControlPlane {
  @override
  Future<InteractionSnapshot> snapshot() async =>
      InteractionSnapshot(revision: 2, state: {'votes': 10});
  @override
  Future<InteractionCommandResult> execute(InteractionCommand command) async =>
      InteractionCommandResult(revision: 3, value: {'ok': true});
}

InteractionFrame _frame({
  String room = 'room-1',
  String reportedSender = 'student-1',
  String actualSender = 'student-1',
  String eventId = 'event-123',
  List<String> targets = const [],
}) => InteractionFrame(
  senderId: actualSender,
  topic: InteractionEventCodec.transportTopic,
  content: InteractionEventCodec.encode(
    InteractionEvent(
      roomCode: room,
      eventId: eventId,
      senderId: reportedSender,
      topic: 'poll.vote',
      timestampMs: 1700000000000,
      payload: {'answer': 'A'},
      targets: targets,
    ),
  ),
);

void main() {
  test('existing MediaSession Data API delivers Interaction frames', () async {
    final media = _FakeMedia();
    final session = DefaultInteractionSession(
      roomCode: 'room-1',
      senderId: 'teacher-1',
      transport: MediaInteractionTransport(media),
    );
    final received = <InteractionEvent>[];
    final subscription = session.events.listen(received.add);
    await session.publish('custom.poll', {'title': 'Vote'});
    expect(media.topics, [InteractionEventCodec.transportTopic]);
    media.inbound.add(
      MediaMessageReceived(
        MediaMessage(
          participantId: 'teacher-1',
          message: media.sent.single,
          topic: InteractionEventCodec.transportTopic,
          timestampMs: 1700000000000,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(received, hasLength(1));
    expect(received.single.topic, 'custom.poll');
    await subscription.cancel();
    await session.dispose();
    await media.inbound.close();
  });

  test(
    'publishes business-neutral messages over a provider-neutral adapter',
    () async {
      final transport = _FakeTransport();
      final session = DefaultInteractionSession(
        roomCode: 'room-1',
        senderId: 'teacher-1',
        transport: transport,
      );
      await session.publish('custom.poll', {'title': 'Vote'});
      expect(transport.published, hasLength(1));
      expect(
        InteractionEventCodec.tryDecode(transport.published.single)?.topic,
        'custom.poll',
      );
      expect(session.capabilities.canExecuteCommands, isFalse);
      await session.dispose();
      await session.dispose();
    },
  );

  test(
    'rejects wrong room, forged sender, duplicate and wrong recipient',
    () async {
      final transport = _FakeTransport();
      final session = DefaultInteractionSession(
        roomCode: 'room-1',
        senderId: 'teacher-1',
        transport: transport,
      );
      final received = <InteractionEvent>[];
      final subscription = session.events.listen(received.add);
      transport.inbox.add(_frame(room: 'room-2'));
      transport.inbox.add(_frame(actualSender: 'attacker'));
      transport.inbox.add(_frame(targets: ['another-teacher']));
      transport.inbox.add(_frame());
      transport.inbox.add(_frame());
      transport.inbox.add(_frame(eventId: 'event-456'));
      await Future<void>.delayed(Duration.zero);
      expect(received.map((event) => event.eventId), [
        'event-123',
        'event-456',
      ]);
      await subscription.cancel();
      await session.dispose();
    },
  );

  test(
    'unsupported delivery modes fail instead of silently broadcasting',
    () async {
      final transport = _FakeTransport();
      final session = DefaultInteractionSession(
        roomCode: 'room-1',
        senderId: 'teacher-1',
        transport: transport,
      );
      await expectLater(
        session.publish(
          'vote',
          {},
          options: const InteractionPublishOptions(targets: ['student-1']),
        ),
        throwsUnsupportedError,
      );
      await expectLater(
        session.publish(
          'vote',
          {},
          options: const InteractionPublishOptions(
            reliability: InteractionReliability.unreliable,
          ),
        ),
        throwsUnsupportedError,
      );
      expect(transport.published, isEmpty);
      await session.dispose();
    },
  );

  test(
    'only explicit trusted control planes execute authoritative commands',
    () async {
      final noPlane = DefaultInteractionSession(
        roomCode: 'room-1',
        senderId: 'user-1',
        transport: _FakeTransport(),
      );
      final command = InteractionCommand(
        operation: 'poll.close',
        requestId: 'request-1',
        arguments: {},
      );
      await expectLater(noPlane.execute(command), throwsUnsupportedError);
      await expectLater(noPlane.snapshot(), throwsUnsupportedError);
      await noPlane.dispose();

      final withPlane = DefaultInteractionSession(
        roomCode: 'room-1',
        senderId: 'user-1',
        transport: _FakeTransport(),
        controlPlane: _TrustedPlane(),
      );
      expect(withPlane.capabilities.canReadSnapshots, isTrue);
      expect((await withPlane.snapshot()).revision, 2);
      expect((await withPlane.execute(command)).revision, 3);
      await withPlane.dispose();
    },
  );
}
