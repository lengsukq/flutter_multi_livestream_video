import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

void main() {
  Uint8List image() => Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0]);

  test('replacement retains an immutable copy and compares image content', () {
    final input = image();
    final effect = MediaBackgroundEffect.replaceImage(imageBytes: input);
    input[8] = 2;
    expect(effect.imageBytes![8], 0);
    expect(() => effect.imageBytes![8] = 2, throwsUnsupportedError);
    final same = MediaBackgroundEffect.replaceImage(imageBytes: image());
    expect(effect, same);
    expect(effect.hashCode, same.hashCode);
    expect(effect.toJson()['imageBytes'], image());
  });

  test('invalid image data is rejected before bridge invocation', () {
    for (final bytes in [
      Uint8List(0),
      Uint8List.fromList([1, 2, 3]),
    ]) {
      expect(
        () => MediaBackgroundEffect.replaceImage(imageBytes: bytes),
        throwsA(
          isA<MediaError>().having(
            (e) => e.code,
            'code',
            MediaErrorCode.invalidArgument,
          ),
        ),
      );
    }
  });

  test('oversized image data is rejected before a control channel copy', () {
    final bytes = Uint8List(16 * 1024 * 1024 + 1);
    bytes.setRange(0, 8, [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(
      () => MediaBackgroundEffect.replaceImage(imageBytes: bytes),
      throwsA(
        isA<MediaError>().having(
          (e) => e.code,
          'code',
          MediaErrorCode.invalidArgument,
        ),
      ),
    );
  });

  test('blur and image replacement capabilities are independent', () {
    const caps = MediaBackgroundCapabilities(canBlur: true);
    expect(caps.supports(const MediaBackgroundEffect.none()), isTrue);
    expect(caps.supports(const MediaBackgroundEffect.blur()), isTrue);
    expect(
      caps.supports(MediaBackgroundEffect.replaceImage(imageBytes: image())),
      isFalse,
    );
    const media = MediaCapabilities(canReplaceBackgroundImage: true);
    expect(media.supports(MediaFeature.backgroundImageReplacement), isTrue);
    expect(media.copyWith().canReplaceBackgroundImage, isTrue);
  });
}
