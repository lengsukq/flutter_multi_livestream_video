import 'dart:async';

import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

/// Cloud-only recording lifecycle for an active realtime room.
///
/// Recording executes through the configured backend. SDK and Demo never
/// capture or persist the user's microphone, camera, or display on device.
class RoomRecordingController implements MediaRecordingController {
  RoomRecordingController({
    required this.media,
    required this.providerId,
    this.cloudRecordingSession,
    this.onFailure,
  });

  final MediaRoomSession media;
  final String providerId;
  final MediaCloudRecordingSession? cloudRecordingSession;
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
  bool _cloudRecordingActive = false;
  bool _disposed = false;
  bool _disposing = false;
  Completer<void>? _startCompleted;
  Completer<void>? _stopCompleted;
  Future<void>? _disposeFuture;

  @override
  RecordingStatus get status => _status;

  @override
  Stream<RecordingStatus> get statuses => _statusController.stream;

  @override
  Duration get duration => _duration;

  @override
  Stream<Duration> get durations => _durationController.stream;

  RecordingOptions? get currentOptions => _currentOptions;

  @override
  Future<RecordingResult> startRecording([RecordingOptions? options]) async {
    if (_disposed ||
        _disposing ||
        _status == RecordingStatus.recording ||
        _status == RecordingStatus.starting ||
        _status == RecordingStatus.stopping) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidState,
        message: 'Recording cannot start in the current room state.',
        providerId: providerId,
      );
    }
    final cloud = cloudRecordingSession;
    if (cloud == null) {
      throw RealtimeException(
        code: RealtimeErrorCode.unsupportedFeature,
        message: 'Cloud recording requires a configured backend executor.',
        providerId: providerId,
      );
    }

    final opts = options ?? RecordingOptions.cloud();
    _currentOptions = opts;
    _startCompleted = Completer<void>();
    _setStatus(RecordingStatus.starting);
    try {
      final result = await cloud.startCloudRecording(opts);
      if (_disposing) {
        try {
          await cloud.stopCloudRecording();
        } catch (_) {}
        throw RealtimeException(
          code: RealtimeErrorCode.invalidState,
          message: 'Room was disposed while cloud recording was starting.',
          providerId: providerId,
        );
      }
      _cloudRecordingActive = true;
      _startDurationTicker();
      _setStatus(RecordingStatus.recording);
      return result;
    } catch (error, stack) {
      _cloudRecordingActive = false;
      _currentOptions = null;
      _setStatus(RecordingStatus.failed);
      onFailure?.call(
        error is RealtimeException
            ? error
            : RealtimeException(
                code: RealtimeErrorCode.unknown,
                message: 'Unable to start cloud recording: $error',
                providerId: providerId,
                details: stack.toString(),
              ),
      );
      rethrow;
    } finally {
      _startCompleted?.complete();
      _startCompleted = null;
    }
  }

  @override
  Future<RecordingResult> queryCloudRecording() async {
    final cloud = cloudRecordingSession;
    if (cloud == null) {
      throw RealtimeException(
        code: RealtimeErrorCode.unsupportedFeature,
        message: 'Cloud recording backend is not configured.',
        providerId: providerId,
      );
    }
    return cloud.queryCloudRecording();
  }

  @override
  Future<Uri> cloudRecordingDownloadUrl() async {
    final cloud = cloudRecordingSession;
    if (cloud == null) {
      throw RealtimeException(
        code: RealtimeErrorCode.unsupportedFeature,
        message: 'Cloud recording backend is not configured.',
        providerId: providerId,
      );
    }
    return cloud.cloudRecordingDownloadUrl();
  }

  @override
  Future<RecordingResult?> stopRecording() async {
    if (_disposed || _status == RecordingStatus.idle) return null;
    if (_status != RecordingStatus.recording || !_cloudRecordingActive) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidState,
        message: 'No running cloud recording is ready to stop.',
        providerId: providerId,
      );
    }
    _setStatus(RecordingStatus.stopping);
    _stopCompleted = Completer<void>();
    _stopDurationTicker();
    try {
      final result = await cloudRecordingSession!.stopCloudRecording();
      _cloudRecordingActive = false;
      _currentOptions = null;
      _duration = Duration.zero;
      _setStatus(RecordingStatus.idle);
      return result; // Cloud processing may continue after recording stops.
    } catch (error, stack) {
      _cloudRecordingActive = false;
      _currentOptions = null;
      _setStatus(RecordingStatus.failed);
      onFailure?.call(
        error is RealtimeException
            ? error
            : RealtimeException(
                code: RealtimeErrorCode.unknown,
                message: 'Failed to stop cloud recording: $error',
                providerId: providerId,
                details: stack.toString(),
              ),
      );
      rethrow;
    } finally {
      _stopCompleted?.complete();
      _stopCompleted = null;
    }
  }

  @override
  CloudRecordingDescriptor describeCloudRecording([
    RecordingOptions? options,
  ]) => media.describeCloudRecording(
    options ?? _currentOptions ?? RecordingOptions.cloud(),
  );

  void _startDurationTicker() {
    _durationTimer?.cancel();
    _startedAt = DateTime.now();
    _duration = Duration.zero;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_startedAt == null) return;
      _duration = DateTime.now().difference(_startedAt!);
      if (!_durationController.isClosed) _durationController.add(_duration);
    });
  }

  void _stopDurationTicker() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _startedAt = null;
  }

  void _setStatus(RecordingStatus status) {
    _status = status;
    if (!_statusController.isClosed) _statusController.add(status);
  }

  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _disposing = true;
    await _startCompleted?.future;
    if (_status == RecordingStatus.recording && _cloudRecordingActive) {
      try {
        await stopRecording();
      } catch (_) {}
    }
    await _stopCompleted?.future;
    _disposed = true;
    cloudRecordingSession?.dispose();
    _stopDurationTicker();
    await _statusController.close();
    await _durationController.close();
  }
}
