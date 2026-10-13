import 'package:flutter_realtime_foundation/flutter_realtime_foundation.dart';

enum ProcessedVideoSourceKind { nativeFrameHub, mediaStreamTrack }

enum ProcessedVideoPlatform { android, ios, macos, web, windows }

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
    final reader = JsonReader(json);
    final id = reader.required<String>('id');
    final width = reader.required<int>('width');
    final height = reader.required<int>('height');
    final rate = reader.required<num>('frameRate').toDouble();
    if (id.isEmpty || width <= 0 || height <= 0 || !rate.isFinite || rate <= 0) {
      throw const RealtimeException(code: RealtimeErrorCode.invalidResponse, message: 'processedVideo.source.geometry');
    }
    return ProcessedVideoSource(
      id: id, platform: reader.enumValue('platform', ProcessedVideoPlatform.values),
      kind: reader.enumValue('kind', ProcessedVideoSourceKind.values),
      width: width, height: height, frameRate: rate,
      previewTextureId: reader.optional<int>('previewTextureId'),
      cameraDeviceId: reader.optional<String>('cameraDeviceId'),
    );
  }

  final String id;
  final ProcessedVideoPlatform platform;
  final ProcessedVideoSourceKind kind;
  final int width;
  final int height;
  final double frameRate;
  final String? cameraDeviceId;

  /// Flutter texture id for native preview. Web renders by [id].
  final int? previewTextureId;

  double get aspectRatio => width > 0 && height > 0 ? width / height : 16 / 9;
}
