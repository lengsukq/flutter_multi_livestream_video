import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'flutter_realtime_video_effects_platform_interface.dart';
import 'src/processed_video_source.dart';
import 'src/video_effects_failure.dart';
import 'src/video_effects_camera_device.dart';
import 'src/video_effects_source_config.dart';

class MethodChannelFlutterRealtimeVideoEffects
    extends FlutterRealtimeVideoEffectsPlatform {
  bool _errorHandlerRegistered = false;

  void _registerErrorHandler() {
    if (_errorHandlerRegistered) return;
    methodChannel.setMethodCallHandler((call) async {
      if (call.method == 'sourceError') {
        final args = Map<Object?, Object?>.from(call.arguments as Map);
        _failures.add(
          VideoEffectsFailure(
            sourceId: args['sourceId'].toString(),
            message: args['message']?.toString() ?? 'Video processing failed.',
          ),
        );
      }
    });
    _errorHandlerRegistered = true;
  }

  final _failures = StreamController<VideoEffectsFailure>.broadcast();
  @override
  Stream<VideoEffectsFailure> get failures => _failures.stream;

  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_realtime_video_effects');

  @override
  Future<bool> isSupported() async {
    _registerErrorHandler();
    return await methodChannel.invokeMethod<bool>('isSupported') ?? false;
  }

  @override
  Future<ProcessedVideoSource> createSource(
    VideoEffectsSourceConfig config,
  ) async {
    _registerErrorHandler();
    final value = await methodChannel.invokeMapMethod<String, Object?>(
      'createSource',
      config.toJson(),
    );
    if (value == null) {
      throw PlatformException(
        code: 'create_source_failed',
        message: 'The native video-effects bridge returned no source.',
      );
    }
    return ProcessedVideoSource.fromJson(value);
  }

  @override
  Future<void> setEffect(String sourceId, MediaBackgroundEffect effect) =>
      methodChannel.invokeMethod<void>('setEffect', {
        'sourceId': sourceId,
        'effect': _effectJson(effect),
      });

  @override
  Future<void> setEnabled(String sourceId, bool enabled) =>
      methodChannel.invokeMethod<void>('setEnabled', {
        'sourceId': sourceId,
        'enabled': enabled,
      });

  @override
  Future<void> selectCamera(String sourceId, String? deviceId) =>
      methodChannel.invokeMethod<void>('selectCamera', {
        'sourceId': sourceId,
        'deviceId': deviceId,
      });

  @override
  Future<List<VideoEffectsCameraDevice>> listCameras() async {
    final values =
        await methodChannel.invokeListMethod<Object?>('listCameras') ??
        const [];
    return values
        .whereType<Map>()
        .map(
          (value) => VideoEffectsCameraDevice.fromJson(
            value.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> disposeSource(String sourceId) =>
      methodChannel.invokeMethod<void>('disposeSource', {'sourceId': sourceId});
}

Map<String, Object?> _effectJson(MediaBackgroundEffect effect) =>
    effect.toJson();
