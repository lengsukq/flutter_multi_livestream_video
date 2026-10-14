import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'message profiles retain immutable image references and legacy initials',
    () {
      final source = <String, String>{'avatarUrl': 'https://avatar.test/a.png'};
      final message = ChatMessage(
        id: 'm',
        userId: 'u',
        message: 'hello',
        timestamp: DateTime(2026),
        attributes: source,
      );
      source.clear();
      expect(message.avatarUrl, 'https://avatar.test/a.png');
      expect(() => message.attributes.clear(), throwsUnsupportedError);
      expect(
        ChatMessage(
          id: 'm',
          userId: 'u',
          message: 'hello',
          timestamp: DateTime(2026),
        ).avatarUrl,
        isNull,
      );
      expect(
        ChatMessage(
          id: 'm',
          userId: 'u',
          message: 'hello',
          timestamp: DateTime(2026),
          avatarUrl: 'file:///private/a.png',
        ).avatarUrl,
        isNull,
      );
    },
  );
}
