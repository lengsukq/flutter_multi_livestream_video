import 'package:flutter/services.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'processed_video_source.dart';
import 'video_effects_bridge.dart';

/// Control-only binding. Native providers subscribe to the platform frame hub.
class NativeProcessedVideoSink {
  NativeProcessedVideoSink({
    required this.providerId,
    this.channelName = 'flutter_realtime_video_effects',
    this.attachMethod = 'attachProvider',
    this.detachMethod = 'detachProvider',
  });
  final String providerId;
  final String channelName;
  final String attachMethod;
  final String detachMethod;
  final String bindingId = 'sink_${DateTime.now().microsecondsSinceEpoch}';
  ProcessedVideoSource? source;
  bool supports(ProcessedVideoSource value) =>
      value.kind == ProcessedVideoSourceKind.nativeFrameHub &&
      (value.platform == VideoEffectsPlatform.android ||
          value.platform == VideoEffectsPlatform.macos);
  MethodChannel _channel(ProcessedVideoSource value) => MethodChannel(
    channelName == 'flutter_realtime_video_effects' &&
            value.platform == VideoEffectsPlatform.macos
        ? 'flutter_realtime_native_video/sinks'
        : channelName,
  );
  Future<void> attach(
    ProcessedVideoSource value, {
    Map<String, Object?> arguments = const {},
  }) async {
    if (!supports(value))
      throw MediaError(
        code: MediaErrorCode.unsupportedFeature,
        providerId: providerId,
        message: 'Unsupported processed-video source.',
      );
    await detach();
    await _channel(value).invokeMethod<void>(attachMethod, {
      'providerId': providerId,
      'bindingId': bindingId,
      'sourceId': value.id,
      ...arguments,
    });
    source = value;
  }

  Future<void> detach() async {
    if (source == null) return;
    try {
      await _channel(source!).invokeMethod<void>(detachMethod, {
        'providerId': providerId,
        'bindingId': bindingId,
        'sourceId': source!.id,
      });
    } finally {
      source = null;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    if (source != null) await VideoEffectsBridge().setEnabled(source!, enabled);
  }

  Future<void> selectCamera(String? deviceId) async {
    if (source != null)
      await VideoEffectsBridge().selectCamera(source!, deviceId);
  }
}
