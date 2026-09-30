import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import '../flutter_realtime_video_effects_platform_interface.dart';
import 'processed_video_source.dart';
import 'video_effects_failure.dart';
import 'video_effects_camera_device.dart';
import 'video_effects_source_config.dart';

class VideoEffectsBridge {
  VideoEffectsBridge({FlutterRealtimeVideoEffectsPlatform? platform})
    : _platform = platform ?? FlutterRealtimeVideoEffectsPlatform.instance;

  final FlutterRealtimeVideoEffectsPlatform _platform;

  Stream<VideoEffectsFailure> get failures => _platform.failures;

  Future<bool> isSupported() => _platform.isSupported();

  Future<ProcessedVideoSource> createSource({
    VideoEffectsSourceConfig config = const VideoEffectsSourceConfig(),
  }) {
    config.validate();
    return _platform.createSource(config);
  }

  Future<void> setEffect(
    ProcessedVideoSource source,
    MediaBackgroundEffect effect,
  ) => _platform.setEffect(source.id, effect);

  Future<void> setEnabled(ProcessedVideoSource source, bool enabled) =>
      _platform.setEnabled(source.id, enabled);

  Future<void> selectCamera(ProcessedVideoSource source, String? deviceId) =>
      _platform.selectCamera(source.id, deviceId);

  Future<List<VideoEffectsCameraDevice>> listCameras() =>
      _platform.listCameras();

  Future<void> disposeSource(ProcessedVideoSource source) =>
      _platform.disposeSource(source.id);
}
