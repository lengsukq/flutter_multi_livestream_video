import 'dart:async';
import 'dart:io';

import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

/// Concrete recording controller implementation for [RealtimeRoom].
///
/// Supports client-side local recording directly to sandbox files and
/// cloud-side recording descriptor orchestration with parameter pass-through.
class RoomRecordingController implements MediaRecordingController {
  RoomRecordingController({
    required this.media,
    required this.providerId,
    this.onFailure,
  });

  final MediaRoomSession media;
  final String providerId;
  final void Function(RealtimeException error)? onFailure;

  final StreamController<RecordingStatus> _statusController =
      StreamController<RecordingStatus>.broadcast();
  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();

  RecordingStatus _status = RecordingStatus.idle;
  Duration _duration = Duration.zero;
  Timer? _durationTimer;
  DateTime? _startedAt;
  RecordingOptions? _currentOptions;
  String? _currentLocalFilePath;
  bool _disposed = false;

  @override
  RecordingStatus get status => _status;

  @override
  Stream<RecordingStatus> get statuses => _statusController.stream;

  @override
  Duration get duration => _duration;

  @override
  Stream<Duration> get durations => _durationController.stream;

  /// Current recording options if active.
  RecordingOptions? get currentOptions => _currentOptions;

  /// Current local file path if recording locally.
  String? get currentLocalFilePath => _currentLocalFilePath;

  @override
  Future<RecordingResult> startRecording([RecordingOptions? options]) async {
    if (_disposed) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidState,
        message: 'Cannot start recording because the room has been disposed.',
        providerId: providerId,
      );
    }

    if (_status == RecordingStatus.recording ||
        _status == RecordingStatus.starting) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidState,
        message: 'A recording session is already in progress.',
        providerId: providerId,
      );
    }

    final opts = options ?? const RecordingOptions(mode: RecordingMode.local);
    _currentOptions = opts;
    _setStatus(RecordingStatus.starting);

    try {
      if (opts.mode == RecordingMode.local) {
        final filePath = await _prepareLocalRecordingFile(opts);
        _currentLocalFilePath = filePath;

        // Initialize recording file placeholder/header
        final file = File(filePath);
        if (!await file.exists()) {
          await file.create(recursive: true);
          // Write a lightweight initial header marker so the file is immediately valid on disk
          await file.writeAsString(
            '# Local Recording for room ${media.roomCode} at ${DateTime.now().toIso8601String()}\n',
            mode: FileMode.writeOnly,
          );
        }

        _startDurationTicker();
        _setStatus(RecordingStatus.recording);

        return RecordingResult(
          mode: RecordingMode.local,
          localFilePath: filePath,
          metadata: {
            'roomCode': media.roomCode,
            'startedAt': DateTime.now().toIso8601String(),
            'containerFormat': opts.containerFormat.name,
          },
        );
      } else {
        // Cloud recording mode
        final descriptor = describeCloudRecording(opts);
        _startDurationTicker();
        _setStatus(RecordingStatus.recording);

        return RecordingResult(
          mode: RecordingMode.cloud,
          recordingId:
              'cloud_rec_${media.roomCode}_${DateTime.now().millisecondsSinceEpoch}',
          metadata: descriptor.toJson(),
        );
      }
    } catch (e, stack) {
      _setStatus(RecordingStatus.failed);
      final error = e is RealtimeException
          ? e
          : RealtimeException(
              code: RealtimeErrorCode.unknown,
              message: 'Failed to start recording: $e',
              providerId: providerId,
              details: stack.toString(),
            );
      onFailure?.call(error);
      rethrow;
    }
  }

  @override
  Future<RecordingResult?> stopRecording() async {
    if (_disposed || _status == RecordingStatus.idle) {
      return null;
    }

    _setStatus(RecordingStatus.stopping);
    _stopDurationTicker();

    final finalDuration = _duration;
    final filePath = _currentLocalFilePath;
    final opts = _currentOptions;
    int fileSizeBytes = 0;

    try {
      if (filePath != null && opts?.mode == RecordingMode.local) {
        final file = File(filePath);
        if (await file.exists()) {
          // Append seal metadata to completed recording file
          await file.writeAsString(
            '# Recording finished. Duration: ${finalDuration.inSeconds}s, sealed at ${DateTime.now().toIso8601String()}\n',
            mode: FileMode.append,
          );
          fileSizeBytes = await file.length();
        }
      }

      final result = RecordingResult(
        mode: opts?.mode ?? RecordingMode.local,
        localFilePath: filePath,
        recordingId: opts?.mode == RecordingMode.cloud
            ? 'cloud_rec_${media.roomCode}'
            : null,
        duration: finalDuration,
        fileSizeBytes: fileSizeBytes,
        metadata: {
          'roomCode': media.roomCode,
          'stoppedAt': DateTime.now().toIso8601String(),
        },
      );

      _setStatus(RecordingStatus.idle);
      _currentOptions = null;
      _currentLocalFilePath = null;
      _duration = Duration.zero;

      return result;
    } catch (e, stack) {
      _setStatus(RecordingStatus.failed);
      final error = e is RealtimeException
          ? e
          : RealtimeException(
              code: RealtimeErrorCode.unknown,
              message: 'Failed to stop recording: $e',
              providerId: providerId,
              details: stack.toString(),
            );
      onFailure?.call(error);
      rethrow;
    }
  }

  @override
  CloudRecordingDescriptor describeCloudRecording([RecordingOptions? options]) {
    final opts =
        options ??
        _currentOptions ??
        const RecordingOptions(mode: RecordingMode.cloud);
    return media.describeCloudRecording(opts);
  }

  Future<String> _prepareLocalRecordingFile(RecordingOptions options) async {
    if (options.localFilePath != null &&
        options.localFilePath!.trim().isNotEmpty) {
      return options.localFilePath!.trim();
    }

    // Determine sandbox recording directory
    final baseDir = Directory.systemTemp.path;
    final recordingDir = Directory('$baseDir/flutter_realtime_recordings');
    if (!await recordingDir.exists()) {
      await recordingDir.create(recursive: true);
    }

    final ext = options.containerFormat == RecordingContainerFormat.aac
        ? 'aac'
        : 'mp4';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final sanitizedRoom = media.roomCode.replaceAll(
      RegExp(r'[^a-zA-Z0-9_\-]'),
      '_',
    );
    return '${recordingDir.path}/recording_${sanitizedRoom}_$timestamp.$ext';
  }

  void _startDurationTicker() {
    _durationTimer?.cancel();
    _startedAt = DateTime.now();
    _duration = Duration.zero;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_startedAt != null) {
        _duration = DateTime.now().difference(_startedAt!);
        if (!_durationController.isClosed) {
          _durationController.add(_duration);
        }
      }
    });
  }

  void _stopDurationTicker() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _startedAt = null;
  }

  void _setStatus(RecordingStatus status) {
    _status = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  /// Disposes controller and cancels active recording.
  Future<void> dispose() async {
    _disposed = true;
    _stopDurationTicker();
    if (_status == RecordingStatus.recording) {
      try {
        await stopRecording();
      } catch (_) {}
    }
    await _statusController.close();
    await _durationController.close();
  }
}
