import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:web/web.dart' as web;

@JS('RealtimeProcessedVideoBridge')
external JSObject get _bridge;

@JS('Promise.resolve')
external JSPromise<JSAny?> _resolved(JSAny? value);

/// Controls the registered browser source without using a native channel.
class ProcessedVideoBridge {
  Future<void> _invoke(String operation, String sourceId, JSAny? value) async {
    try {
      await _resolved(
        _bridge.callMethod<JSAny?>(operation.toJS, sourceId.toJS, value),
      ).toDart;
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
      _invoke('setEnabled', source.id, enabled.toJS);

  Future<void> selectCamera(ProcessedVideoSource source, String? deviceId) =>
      _invoke('selectCamera', source.id, deviceId?.toJS);

  Future<List<ProcessedVideoCameraDevice>> listCameras() async {
    try {
      final devices = await web.window.navigator.mediaDevices
          .enumerateDevices()
          .toDart;
      return List.unmodifiable([
        for (final device in devices.toDart)
          if (device.kind == 'videoinput')
            ProcessedVideoCameraDevice(
              id: device.deviceId,
              label: device.label.isEmpty ? 'Camera' : device.label,
            ),
      ]);
    } catch (error, stack) {
      Error.throwWithStackTrace(
        normalizeRealtimeException(
          error,
          domain: 'processedVideo',
          operation: 'listCameras',
          stackTrace: stack,
        ),
        stack,
      );
    }
  }
}
