import 'package:flutter_realtime_foundation/flutter_realtime_foundation.dart';
import 'package:test/test.dart';

void main() {
  test(
    'avatar references accept only bounded HTTP images without credentials',
    () {
      expect(
        RealtimeAvatarUrl.tryParse(' https://example.test/photo.png '),
        'https://example.test/photo.png',
      );
      expect(
        RealtimeAvatarUrl.tryParse('http://localhost:8080/avatar'),
        isNotNull,
      );
      for (final value in [
        null,
        '',
        ' ',
        'file:///tmp/avatar.png',
        'data:image/png;base64,abc',
        'javascript:alert(1)',
        'https://user:secret@example.test/avatar',
        'https://',
        'https://example.test/${'a' * 2048}',
      ]) {
        expect(RealtimeAvatarUrl.tryParse(value), isNull);
      }
    },
  );
}
