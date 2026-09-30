import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_realtime_video_effects_method_channel.dart';
import 'src/processed_video_source.dart';
import 'src/video_effects_failure.dart';
import 'src/video_effects_camera_device.dart';
import 'src/video_effects_source_config.dart';

abstract class FlutterRealtimeVideoEffectsPlatform extends PlatformInterface {
  FlutterRealtimeVideoEffectsPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterRealtimeVideoEffectsPlatform _instance =
      MethodChannelFlutterRealtimeVideoEffects();

  static FlutterRealtimeVideoEffectsPlatform get instance => _instance;

  static set instance(FlutterRealtimeVideoEffectsPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Stream<VideoEffectsFailure> get failures => const Stream.empty();

  Future<bool> isSupported();

  Future<ProcessedVideoSource> createSource(VideoEffectsSourceConfig config);

  Future<void> setEffect(String sourceId, MediaBackgroundEffect effect);

  Future<void> setEnabled(String sourceId, bool enabled);

  Future<void> selectCamera(String sourceId, String? deviceId);

  Future<List<VideoEffectsCameraDevice>> listCameras();

  Future<void> disposeSource(String sourceId);
}
