import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage message(String id, int time, {String text = 'hello'}) =>
    ChatMessage(
      id: id,
      userId: 'user',
      displayName: 'User',
      message: text,
      timestamp: DateTime.fromMillisecondsSinceEpoch(time),
      providerId: 'fake',
    );

void main() {
  test('capacity must be positive', () {
    expect(() => ChatMessageBuffer(maxMessages: 0), throwsArgumentError);
    expect(() => ChatMessageBuffer(maxMessages: -1), throwsArgumentError);
  });
  test('ordered, stable, bounded, immutable and replacement-aware', () {
    final buffer = ChatMessageBuffer(maxMessages: 3);
    buffer.upsert(message('b', 2));
    buffer.upsert(message('a', 1));
    buffer.upsert(message('c', 2));
    final previous = buffer.messages;
    expect(previous.map((m) => m.id), ['a', 'b', 'c']);
    expect(buffer.upsert(message('b', 2, text: 'updated')), isFalse);
    expect(buffer.messages.map((m) => m.id), ['a', 'b', 'c']);
    expect(buffer.messages[1].message, 'updated');
    buffer.upsert(message('d', 3));
    expect(buffer.messages.map((m) => m.id), ['b', 'c', 'd']);
    expect(buffer.contains('a'), isFalse);
    expect(buffer.upsert(message('a', 1)), isFalse);
    expect(buffer.indexedMessageCount, 3);
    expect(previous.length, 3);
    expect(() => previous.clear(), throwsUnsupportedError);
    buffer.remove('c');
    expect(buffer.messages.map((m) => m.id), ['b', 'd']);
    buffer.clear();
    expect(buffer.messages, isEmpty);
    expect(buffer.indexedMessageCount, 0);
  });
  test('10,000 messages and replay keep timeline and index bounded', () {
    final buffer = ChatMessageBuffer(maxMessages: 500);
    for (var i = 0; i < 10000; i++) {
      buffer.upsert(message('$i', i));
      expect(buffer.length, lessThanOrEqualTo(500));
      expect(buffer.indexedMessageCount, buffer.length);
    }
    expect(buffer.messages.first.id, '9500');
    for (var i = 0; i < 10000; i++) {
      expect(buffer.upsert(message('$i', i)), isFalse);
    }
    expect(buffer.length, 500);
    expect(buffer.messages.last.id, '9999');
  });
}
