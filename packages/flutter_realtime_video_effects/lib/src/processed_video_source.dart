enum ProcessedVideoSourceKind { nativeFrameHub, mediaStreamTrack }

enum VideoEffectsPlatform { android, ios, macos, web, windows }

class ProcessedVideoSource {
  const ProcessedVideoSource({
    required this.id,
    required this.platform,
    required this.kind,
    required this.width,
    required this.height,
    required this.frameRate,
    this.previewTextureId,
    this.cameraDeviceId,
  });

  factory ProcessedVideoSource.fromJson(Map<String, Object?> json) {
    return ProcessedVideoSource(
      id: json['id']?.toString() ?? '',
      platform: VideoEffectsPlatform.values.byName(
        json['platform']?.toString() ?? 'android',
      ),
      kind: ProcessedVideoSourceKind.values.byName(
        json['kind']?.toString() ?? 'nativeFrameHub',
      ),
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
      frameRate: (json['frameRate'] as num?)?.toDouble() ?? 0,
      previewTextureId: (json['previewTextureId'] as num?)?.toInt(),
      cameraDeviceId: json['cameraDeviceId'] as String?,
    );
  }

  final String id;
  final VideoEffectsPlatform platform;
  final ProcessedVideoSourceKind kind;
  final int width;
  final int height;
  final double frameRate;
  final String? cameraDeviceId;

  /// Flutter texture id for native preview. Web renders by [id].
  final int? previewTextureId;

  double get aspectRatio => width > 0 && height > 0 ? width / height : 16 / 9;
}
