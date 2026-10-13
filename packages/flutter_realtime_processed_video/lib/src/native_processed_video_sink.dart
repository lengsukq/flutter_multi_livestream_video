import 'package:flutter/services.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'processed_video_bridge.dart';

/// Serializes provider bindings. Capture and processing remain source-owned.
class NativeProcessedVideoSink {
  NativeProcessedVideoSink({required this.providerId, String? channelName,
    this.attachMethod = 'attachProvider', this.detachMethod = 'detachProvider',
  }) : channelName = channelName ?? 'flutter_realtime_media_$providerId/processed_video';
  final String providerId;
  final String channelName;
  final String attachMethod;
  final String detachMethod;
  final String bindingId = 'sink_${DateTime.now().microsecondsSinceEpoch}';
  ProcessedVideoSource? _source;
  ProcessedVideoSource? get source => _source;
  RealtimeException? _lastFailure;
  RealtimeException? get lastFailure => _lastFailure;
  Future<void> _tail = Future<void>.value();
  Future<void>? _disposal;
  bool _closed = false;

  bool supports(ProcessedVideoSource value) => value.kind == ProcessedVideoSourceKind.nativeFrameHub &&
      (value.platform == ProcessedVideoPlatform.android || value.platform == ProcessedVideoPlatform.macos);
  Future<void> _invoke(String operation, Map<String, Object?> arguments) async {
    try { await MethodChannel(channelName).invokeMethod<void>(operation, arguments); }
    catch (error, stack) { Error.throwWithStackTrace(normalizeRealtimeException(error, domain: 'processedVideo.sink', operation: operation, providerId: providerId, stackTrace: stack), stack); }
  }
  Future<void> _enqueue(Future<void> Function() command) {
    final operation = _tail.then((_) => command());
    // Preserve the error for the caller and diagnostics while allowing a retry
    // to enter the queue after an earlier operation failed.
    _tail = operation.catchError((Object error) { _lastFailure = normalizeRealtimeException(error, domain: 'processedVideo.sink'); });
    return operation;
  }
  void _ensureOpen() {
    if (_closed) throw const RealtimeException(code: RealtimeErrorCode.invalidState, message: 'processedVideo.sink.closed');
  }
  Future<void> attach(ProcessedVideoSource value, {Map<String, Object?> arguments = const {}}) {
    _ensureOpen();
    final snapshot = Map<String, Object?>.unmodifiable(arguments);
    return _enqueue(() async {
      if (!supports(value)) throw RealtimeException(code: RealtimeErrorCode.unsupportedFeature, providerId: providerId, message: 'processedVideo.sink.source');
      await _detach();
      _source = value;
      try { await _invoke(attachMethod, {...snapshot, 'providerId': providerId, 'bindingId': bindingId, 'sourceId': value.id}); }
      catch (error, stack) {
        final rollback = Cleanup();
        await rollback.run('processedVideo.sink.rollback', _detach);
        rollback.finish(domain: 'processedVideo.sink', cause: error);
        Error.throwWithStackTrace(error, stack);
      }
    });
  }
  Future<void> detach() => _enqueue(_detach);
  Future<void> _detach() async {
    final source = _source;
    if (source == null) return;
    await _invoke(detachMethod, {'providerId': providerId, 'bindingId': bindingId, 'sourceId': source.id});
    _source = null;
  }
  Future<void> setEnabled(bool enabled) {
    _ensureOpen();
    return _enqueue(() async { final source = _source; if (source != null) await ProcessedVideoBridge().setEnabled(source, enabled); });
  }
  Future<void> selectCamera(String? deviceId) {
    _ensureOpen();
    return _enqueue(() async { final source = _source; if (source != null) await ProcessedVideoBridge().selectCamera(source, deviceId); });
  }
  Future<void> dispose() {
    _closed = true;
    return _disposal ??= _enqueue(_detach);
  }
}
