import 'dart:typed_data';

import 'media_error.dart';

/// Provider-neutral local camera background effect.
enum MediaBackgroundEffectType { none, blur, replaceImage }

/// Provider-neutral blur strength. Adapters map this to the nearest native
/// value supported by their SDK.
enum MediaBackgroundBlurStrength { low, medium, high }

class MediaBackgroundEffect {
  const MediaBackgroundEffect.none()
    : type = MediaBackgroundEffectType.none,
      blurStrength = null,
      imageBytes = null;

  const MediaBackgroundEffect.blur({
    this.blurStrength = MediaBackgroundBlurStrength.medium,
  }) : type = MediaBackgroundEffectType.blur,
       imageBytes = null;

  /// Replaces the background with a PNG or JPEG image, cropped to fill the
  /// camera frame. The bytes are copied once and retained immutably; no image
  /// or camera data is fetched from a network by this API.
  MediaBackgroundEffect.replaceImage({required Uint8List imageBytes})
    : type = MediaBackgroundEffectType.replaceImage,
      blurStrength = null,
      imageBytes = _checkedImage(imageBytes);

  final MediaBackgroundEffectType type;
  final MediaBackgroundBlurStrength? blurStrength;
  final Uint8List? imageBytes;

  bool get enabled => type != MediaBackgroundEffectType.none;

  @override
  bool operator ==(Object other) =>
      other is MediaBackgroundEffect &&
      other.type == type &&
      other.blurStrength == blurStrength &&
      _sameBytes(other.imageBytes, imageBytes);

  @override
  int get hashCode => Object.hash(
    type,
    blurStrength,
    imageBytes == null ? null : Object.hashAll(imageBytes!),
  );

  /// JSON-safe control payload. Image bytes are transmitted only when the
  /// effect changes, never once per video frame.
  Map<String, Object?> toJson() => {
    'type': type.name,
    'blurStrength': blurStrength?.name,
    if (imageBytes != null) 'imageBytes': imageBytes!.toList(growable: false),
  };
}

Uint8List _checkedImage(Uint8List bytes) {
  if (bytes.length > 16 * 1024 * 1024) {
    throw const MediaError(
      code: MediaErrorCode.invalidArgument,
      message: 'The background image must be 16 MiB or smaller.',
    );
  }
  const png = [137, 80, 78, 71, 13, 10, 26, 10];
  final isPng =
      bytes.length >= png.length &&
      List.generate(png.length, (i) => bytes[i] == png[i]).every((v) => v);
  final isJpeg =
      bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff;
  if (!isPng && !isJpeg) {
    throw const MediaError(
      code: MediaErrorCode.invalidArgument,
      message: 'The background must contain a PNG or JPEG image.',
    );
  }
  return Uint8List.fromList(bytes).asUnmodifiableView();
}

bool _sameBytes(Uint8List? a, Uint8List? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class MediaBackgroundCapabilities {
  const MediaBackgroundCapabilities({
    this.canBlur = false,
    this.canReplaceImage = false,
  });

  const MediaBackgroundCapabilities.none()
    : canBlur = false,
      canReplaceImage = false;

  final bool canBlur;
  final bool canReplaceImage;

  bool get isSupported => canBlur || canReplaceImage;

  bool supports(MediaBackgroundEffect effect) => switch (effect.type) {
    MediaBackgroundEffectType.none => true,
    MediaBackgroundEffectType.blur => canBlur,
    MediaBackgroundEffectType.replaceImage => canReplaceImage,
  };
}
