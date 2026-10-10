library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

/// App-level opt-in recorder registration:
///
/// Realtime(providers: ..., localRecordingDriverFactory: nativeRecordingDriverFor);
///
/// V1 records the explicitly authorized macOS display (available system audio)
/// or Android screen (video only). Neither extracts RTC raw vendor tracks.
MediaLocalRecordingSession? nativeRecordingDriverFor(MediaRoomSession room) {
  if (kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.macOS &&
          defaultTargetPlatform != TargetPlatform.android)) {
    return null;
  }
  return NativeDisplayRecordingDriver(roomCode: room.roomCode);
}

/// Native system display recording, intentionally independent of RTC vendors.
class NativeDisplayRecordingDriver
    implements
        MediaLocalRecordingSession,
        MediaRecordingArtifactExporter,
        MediaRecordingInterruptionSource {
  NativeDisplayRecordingDriver({required this.roomCode, MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('flutter_realtime_recorder_native');

  final String roomCode;
  final MethodChannel _channel;
  bool _active = false;
  static const EventChannel _interruptionsChannel = EventChannel(
    'flutter_realtime_recorder_native/events',
  );

  @override
  Stream<String> get recordingInterruptions => _interruptionsChannel
      .receiveBroadcastStream()
      .where((event) => event is Map && event['roomCode'] == roomCode)
      .map((event) {
        _active = false;
        return (event as Map)['reason']?.toString() ??
            'The platform stopped capturing media.';
      });

  @override
  Future<RecordingResult> startLocalRecording(RecordingOptions options) async {
    if (_active) {
      throw StateError('A native screen recording is already active.');
    }
    if (options.mode != RecordingMode.local ||
        options.streamType == RecordingStreamType.audioOnly ||
        options.containerFormat != RecordingContainerFormat.mp4 ||
        options.localFilePath != null) {
      throw UnsupportedError(
        'Native display recording requires local MP4 with video and '
        'an SDK-managed output path.',
      );
    }
    final reply = await _channel.invokeMapMethod<String, dynamic>('start', {
      'roomCode': roomCode,
      'withAudio': options.streamType == RecordingStreamType.both,
    });
    if (reply == null || reply['localFilePath'] is! String) {
      throw StateError('Native recorder returned no output file path.');
    }
    _active = true;
    return RecordingResult(
      mode: RecordingMode.local,
      localFilePath: reply['localFilePath'] as String,
      fileName: reply['fileName'] as String?,
      mimeType: 'video/mp4',
      metadata: {'captureMethod': 'native-display-capture'},
    );
  }

  @override
  Future<RecordingResult> stopLocalRecording() async {
    if (!_active) throw StateError('No native recording is active.');
    try {
      final reply = await _channel.invokeMapMethod<String, dynamic>('stop');
      if (reply == null || reply['fileSizeBytes'] is! num) {
        throw StateError('Native recorder returned no finalized media result.');
      }
      return RecordingResult(
        mode: RecordingMode.local,
        localFilePath: reply['localFilePath'] as String?,
        fileName: reply['fileName'] as String?,
        mimeType: 'video/mp4',
        fileSizeBytes: (reply['fileSizeBytes'] as num).toInt(),
        duration: Duration(
          milliseconds: (reply['durationMs'] as num? ?? 0).toInt(),
        ),
        metadata: {
          'captureMethod': 'native-display-capture',
          'hasVideo': reply['hasVideo'] == true,
          'hasAudio': reply['hasAudio'] == true,
        },
      );
    } finally {
      _active = false;
    }
  }

  @override
  void downloadLocalRecording(RecordingResult result) {
    throw UnsupportedError('Native recording returns a local file path.');
  }

  @override
  Future<String> exportRecording(RecordingResult result) async {
    final path = result.localFilePath;
    if (result.mode != RecordingMode.local ||
        path == null ||
        path.isEmpty ||
        result.fileSizeBytes <= 0) {
      throw ArgumentError('Only completed native recordings can be exported.');
    }
    final exported = await _channel.invokeMethod<String>('export', {
      'localFilePath': path,
    });
    if (exported == null || exported.isEmpty) {
      throw StateError(
        'The native recorder returned no exported file location.',
      );
    }
    return exported;
  }
}
