import 'dart:convert';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final envelope = {
    'v': 1,
    'type': 'classroom.state.changed',
    'roomCode': 'r1',
    'revision': 2,
    'eventId': 'e1',
    'timestampMs': 1,
  };
  test('revision frames require the complete typed envelope', () {
    final payload = jsonEncode(envelope);
    expect(
      ChatSystemMessageCodec.decode(ChatSystemMessageCodec.encode(payload)),
      payload,
    );
    for (final key in envelope.keys) {
      final missing = Map.of(envelope)..remove(key);
      expect(
        ChatSystemMessageCodec.decode(
          '${ChatSystemMessageCodec.prefix}${jsonEncode(missing)}',
        ),
        isNull,
      );
    }
    expect(
      ChatSystemMessageCodec.decode(
        '${ChatSystemMessageCodec.prefix}arbitrary text',
      ),
      isNull,
    );
    expect(
      () => ChatSystemMessageCodec.encode('arbitrary text'),
      throwsArgumentError,
    );
    expect(
      ChatSystemMessageCodec.decode(
        '${ChatSystemMessageCodec.prefix}${jsonEncode({...envelope, 'revision': -1})}',
      ),
      isNull,
    );
  });
  test('literal reserved prefixes and escapes round trip as ordinary text', () {
    for (final text in [
      'normal',
      '${ChatSystemMessageCodec.prefix}${jsonEncode(envelope)}',
      '${ChatSystemMessageCodec.textPrefix}"nested"',
    ]) {
      final encoded = ChatSystemMessageCodec.encodeUserText(text);
      expect(ChatSystemMessageCodec.decode(encoded), isNull);
      expect(ChatSystemMessageCodec.decodeUserText(encoded), text);
    }
    expect(
      ChatSystemMessageCodec.decodeUserText(
        '${ChatSystemMessageCodec.textPrefix}broken',
      ),
      '${ChatSystemMessageCodec.textPrefix}broken',
    );
  });
}
