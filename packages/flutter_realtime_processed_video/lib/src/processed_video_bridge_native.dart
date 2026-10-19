import 'package:flutter/services.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

/// Controls a registered processed source without acquiring or processing video.
class ProcessedVideoBridge {
  static const _channel = MethodChannel(
    'flutter_realtime_processed_video/sources',
  );
  Future<T?> _invoke<T>(
    String operation, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      return await _channel.invokeMethod<T>(operation, arguments);
    } catch (error, stack) {
      Error.throwWithStackTrace(
        normalizeRealtimeException(
          error,
          domain: 'processedVideo',
          operation: operation,
          stackTrace: stack,
        ),
        stack,
      );
    }
  }

  Future<void> setEnabled(ProcessedVideoSource source, bool enabled) =>
      _invoke<void>('setEnabled', {'sourceId': source.id, 'enabled': enabled});
  Future<void> selectCamera(ProcessedVideoSource source, String? deviceId) =>
      _invoke<void>('selectCamera', {
        'sourceId': source.id,
        'deviceId': deviceId,
      });
  Future<List<ProcessedVideoCameraDevice>> listCameras() async {
    final values = await _invoke<List<Object?>>('listCameras') ?? [];
    try {
      return List.unmodifiable(
        values.map(
          (value) => ProcessedVideoCameraDevice.fromJson(
            Map<String, Object?>.from(value as Map<Object?, Object?>),
          ),
        ),
      );
    } catch (error, stack) {
      Error.throwWithStackTrace(
        normalizeRealtimeException(
          error,
          domain: 'processedVideo.decode',
          stackTrace: stack,
        ),
        stack,
      );
    }
  }
}
