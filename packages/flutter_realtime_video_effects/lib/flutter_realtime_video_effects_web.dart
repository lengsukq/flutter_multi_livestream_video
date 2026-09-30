import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:web/web.dart' as web;

import 'flutter_realtime_video_effects_platform_interface.dart';
import 'src/processed_video_source.dart';
import 'src/video_effects_failure.dart';
import 'src/video_effects_camera_device.dart';
import 'src/video_effects_source_config.dart';

@JS('globalThis')
external JSObject get _globalThis;

class FlutterRealtimeVideoEffectsWeb
    extends FlutterRealtimeVideoEffectsPlatform {
  FlutterRealtimeVideoEffectsWeb() {
    _globalThis.setProperty(
      '__flutterVideoEffectsOnError'.toJS,
      ((JSString sourceId, JSString message) {
        _failures.add(
          VideoEffectsFailure(
            sourceId: sourceId.toDart,
            message: message.toDart,
          ),
        );
      }).toJS,
    );
  }
  final _failures = StreamController<VideoEffectsFailure>.broadcast();
  @override
  Stream<VideoEffectsFailure> get failures => _failures.stream;

  static void registerWith(Object registrar) {
    FlutterRealtimeVideoEffectsPlatform.instance =
        FlutterRealtimeVideoEffectsWeb();
  }

  static int _nextSourceId = 0;

  JSObject get _bridge {
    if (!_globalThis.has('RealtimeVideoEffectsBridge')) {
      throw StateError(
        'RealtimeVideoEffectsBridge is unavailable. Load the video-effects '
        'Web runtime before creating a processed source.',
      );
    }
    return _globalThis['RealtimeVideoEffectsBridge'] as JSObject;
  }

  @override
  Future<bool> isSupported() async {
    try {
      if (!_globalThis.has('RealtimeVideoEffectsBridge')) return false;
      if (!_globalThis.has('SdkVideoEffectsVision')) return false;
      final canvas = _globalThis.getProperty<JSAny?>('HTMLCanvasElement'.toJS);
      if (canvas == null) return false;
      final prototype = (canvas as JSObject).getProperty<JSAny?>(
        'prototype'.toJS,
      );
      return prototype != null &&
          (prototype as JSObject).hasProperty('captureStream'.toJS).toDart;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<ProcessedVideoSource> createSource(
    VideoEffectsSourceConfig config,
  ) async {
    final sourceId =
        'effects_web_${DateTime.now().microsecondsSinceEpoch}_'
        '${_nextSourceId++}';
    final infoJs = await _bridge
        .callMethod<JSPromise<JSAny?>>(
          'createSource'.toJS,
          sourceId.toJS,
          jsonEncode({
            'cameraDeviceId': config.cameraDeviceId,
            'width': config.width,
            'height': config.height,
            'frameRate': config.frameRate,
            'effect': _effectJson(config.effect),
          }).toJS,
        )
        .toDart;
    final info = (infoJs?.dartify() as Map?) ?? const {};
    return ProcessedVideoSource(
      id: sourceId,
      platform: VideoEffectsPlatform.web,
      kind: ProcessedVideoSourceKind.mediaStreamTrack,
      width: (info['width'] as num?)?.toInt() ?? config.width,
      height: (info['height'] as num?)?.toInt() ?? config.height,
      frameRate:
          (info['frameRate'] as num?)?.toDouble() ??
          config.frameRate.toDouble(),
      cameraDeviceId: info['cameraDeviceId'] as String?,
    );
  }

  @override
  Future<void> setEffect(String sourceId, MediaBackgroundEffect effect) async {
    await _bridge
        .callMethod<JSPromise<JSAny?>>(
          'setEffect'.toJS,
          sourceId.toJS,
          jsonEncode(_effectJson(effect)).toJS,
        )
        .toDart;
  }

  @override
  Future<void> setEnabled(String sourceId, bool enabled) => _bridge
      .callMethod<JSPromise<JSAny?>>(
        'setEnabled'.toJS,
        sourceId.toJS,
        enabled.toJS,
      )
      .toDart
      .then((_) {});

  @override
  Future<void> selectCamera(String sourceId, String? deviceId) => _bridge
      .callMethod<JSPromise<JSAny?>>(
        'selectCamera'.toJS,
        sourceId.toJS,
        deviceId?.toJS,
      )
      .toDart
      .then((_) {});

  @override
  Future<List<VideoEffectsCameraDevice>> listCameras() async {
    final mediaDevices = web.window.navigator.mediaDevices;
    final devices = await mediaDevices.enumerateDevices().toDart;
    return devices.toDart
        .where((device) => device.kind == 'videoinput')
        .map(
          (device) => VideoEffectsCameraDevice(
            id: device.deviceId,
            label: device.label.isEmpty ? 'Camera' : device.label,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> disposeSource(String sourceId) async {
    _bridge.callMethod<JSAny?>('disposeSource'.toJS, sourceId.toJS);
  }
}

Map<String, Object?> _effectJson(MediaBackgroundEffect effect) =>
    effect.toJson();
