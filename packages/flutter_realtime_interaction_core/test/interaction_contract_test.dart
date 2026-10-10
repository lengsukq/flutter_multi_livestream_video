import 'dart:convert';

import 'package:flutter_realtime_interaction_core/flutter_realtime_interaction_core.dart';
import 'package:test/test.dart';

InteractionEvent sample({
  String roomCode = 'meeting-1',
  String senderId = 'participant-1',
  String eventId = 'event-123',
  String topic = 'custom.poll',
  int version = 1,
  Map<String, Object?> payload = const {'question': 'Lunch?', 'votes': 1},
  List<String> targets = const [],
}) => InteractionEvent(
  roomCode: roomCode,
  senderId: senderId,
  eventId: eventId,
  topic: topic,
  version: version,
  payload: payload,
  targets: targets,
  timestampMs: 1700000000000,
);

void main() {
  test('encodes a business-neutral, versioned and scoped event', () {
    final event = sample(targets: ['participant-2']);
    final decoded = InteractionEventCodec.tryDecode(
      InteractionEventCodec.encode(event),
    );
    expect(decoded, isNotNull);
    expect(decoded!.roomCode, 'meeting-1');
    expect(decoded.topic, 'custom.poll');
    expect(decoded.targets, ['participant-2']);
    expect(decoded.payload, {'question': 'Lunch?', 'votes': 1});
    expect(
      () => decoded.payload['question'] = 'changed',
      throwsUnsupportedError,
    );
    expect(() => decoded.targets.add('participant-3'), throwsUnsupportedError);
  });

  test('rejects invalid fields, unsupported versions and oversized events', () {
    for (final event in [
      sample(version: 2),
      sample(roomCode: ''),
      sample(senderId: 'someone with spaces'),
      sample(topic: ''),
      sample(targets: ['bad target']),
      sample(payload: {'body': 'x' * 18000}),
    ]) {
      expect(() => InteractionEventCodec.encode(event), throwsArgumentError);
    }
  });

  test('malformed/untrusted frames never crash the consumer', () {
    for (final value in [
      '{bad',
      '',
      '[]',
      '{"v":2}',
      jsonEncode({
        'v': 1,
        'roomCode': 'room',
        'eventId': 'event-123',
        'senderId': 'user',
        'topic': 'custom',
        'timestampMs': 1700000000000,
        'payload': <String, Object?>{},
        'targets': 'not-list',
      }),
      'x' * (InteractionEventCodec.maxEnvelopeBytes + 1),
    ]) {
      expect(InteractionEventCodec.tryDecode(value), isNull);
    }
  });

  test('command and snapshots keep independent, immutable state', () {
    final arguments = <String, Object?>{'userId': 'student-1'};
    final command = InteractionCommand(
      operation: 'classroom.approve',
      requestId: 'request-1',
      arguments: arguments,
    );
    arguments['userId'] = 'attacker';
    expect(command.arguments['userId'], 'student-1');
    final snapshot = InteractionSnapshot(
      revision: 12,
      state: {'raisedHands': 4},
    );
    expect(snapshot.revision, 12);
    expect(() => snapshot.state['raisedHands'] = 5, throwsUnsupportedError);
  });
}
