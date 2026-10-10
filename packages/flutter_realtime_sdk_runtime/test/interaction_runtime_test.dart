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

class _ChangingPlane implements InteractionControlPlane {
  int revision = 1;
  int reads = 0;
  final Completer<void>? gate;
  _ChangingPlane({this.gate});
  @override
  Future<InteractionSnapshot> snapshot() async {
    reads++;
    await gate?.future;
    return InteractionSnapshot(revision: revision, state: {'count': revision});
  }

  @override
  Future<InteractionCommandResult> execute(InteractionCommand command) async {
    revision++;
    return InteractionCommandResult(revision: revision);
  }
}

class _FakeRevisions implements InteractionRevisionTransport {
  final updates = StreamController<int>.broadcast();
  @override
  Stream<int> get revisions => updates.stream;
  @override
  Future<void> publish(int revision) async {
    updates.add(revision);
  }

  @override
  Future<void> dispose() => updates.close();
}

class _FakeSystemChat implements ChatSystemMessaging {
  final messages = StreamController<String>.broadcast();
  final sent = <String>[];
  @override
  Stream<String> get systemMessages => messages.stream;
  @override
  Future<void> sendSystemMessage(String payload) async {
    sent.add(payload);
  }
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
  test(
    'IM hint validates room/revision but only triggers trusted reads',
    () async {
      final chat = _FakeSystemChat();
      final revisions = ChatInteractionRevisionTransport(
        chat,
        roomCode: 'room-1',
      );
      final received = <int>[];
      final subscription = revisions.revisions.listen(received.add);
      await revisions.publish(9);
      expect(chat.sent, hasLength(1));
      chat.messages.add(chat.sent.single);
      chat.messages.add(InteractionRevisionHintCodec.encode('room-2', 100));
      chat.messages.add(
        '{"v":1,"type":"interaction.state.changed","roomCode":"room-1","revision":-1,"eventId":"bad","timestampMs":0}',
      );
      await Future<void>.delayed(Duration.zero);
      expect(received, [9]);
      await subscription.cancel();
      await revisions.dispose();
      await chat.messages.close();
    },
  );

  test(
    'initial snapshot, untrusted hint and stale revision recover correctly',
    () async {
      final plane = _ChangingPlane();
      final hints = _FakeRevisions();
      final session = DefaultInteractionSession(
        roomCode: 'room-1',
        senderId: 'self-1',
        transport: _FakeTransport(),
        controlPlane: plane,
        revisionTransport: hints,
        snapshotPollInterval: Duration.zero,
      );
      final snapshots = <InteractionSnapshot>[];
      final subscription = session.snapshots.listen(snapshots.add);
      await session.refresh();
      expect(session.currentSnapshot?.revision, 1);
      plane.revision = 3;
      hints.updates.add(900000);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(session.currentSnapshot?.revision, 3);
      expect(snapshots.map((snapshot) => snapshot.revision), [1, 3]);
      hints.updates.add(2);
      await Future<void>.delayed(Duration.zero);
      expect(snapshots, hasLength(2));
      await subscription.cancel();
      await session.dispose();
    },
  );

  test(
    'concurrent authoritative refreshes share one flight and stop after disposal',
    () async {
      final gate = Completer<void>();
      final plane = _ChangingPlane(gate: gate);
      final session = DefaultInteractionSession(
        roomCode: 'room-1',
        senderId: 'self-1',
        transport: _FakeTransport(),
        controlPlane: plane,
        snapshotPollInterval: Duration.zero,
      );
      final first = session.refresh();
      final second = session.refresh();
      expect(identical(first, second), isTrue);
      expect(plane.reads, 1);
      gate.complete();
      await Future.wait([first, second]);
      expect(plane.reads, 1);
      await session.dispose();
    },
  );

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
