import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:dart_webrtc/dart_webrtc.dart';
import 'package:flutter_realtime_video_effects/flutter_realtime_video_effects.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:web/web.dart' as web;

@JS('RealtimeVideoEffectsBridge')
external JSObject get _bridge;
Future<lk.LocalVideoTrack> createProcessedLiveKitTrack(
  ProcessedVideoSource source,
) async {
  final track = _bridge
      .callMethod<web.MediaStreamTrack>('getTrack'.toJS, source.id.toJS)
      .clone();
  final stream = MediaStreamWeb(web.MediaStream([track].toJS), 'local');
  // Externally supplied tracks must not invoke camera capture.
  // ignore: invalid_use_of_internal_member
  return lk.LocalVideoTrack(
    lk.TrackSource.camera,
    stream,
    stream.getVideoTracks().single,
    const lk.CameraCaptureOptions(),
  );
}

Future<void> disposeProcessedLiveKitTrack(ProcessedVideoSource source) async {}
