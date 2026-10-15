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
  RecordingTaskState _taskState = RecordingTaskState.idle;
  RecordingTaskState get taskState => _taskState;
  bool get _cloudRecordingActive =>
      _taskState == RecordingTaskState.recording ||
      _taskState == RecordingTaskState.starting;
  bool get _cloudStateUnknown => _taskState == RecordingTaskState.unknown;
  Duration cleanupTimeout = const Duration(seconds: 10);
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

  /// Whether this room has an injected cloud recording executor.
  bool get isConfigured => cloudRecordingSession != null;

  RecordingOptions? get currentOptions => _currentOptions;

  @override
  Future<RecordingResult> startRecording([RecordingOptions? options]) async {
    if (_disposed ||
        _disposing ||
        _cloudStateUnknown ||
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
        final cleanup = Cleanup(timeout: cleanupTimeout);
        await cleanup.run('recording.rollback', cloud.stopCloudRecording);
        cleanup.finish(
          domain: 'recording',
          cause: const RealtimeException(
            code: RealtimeErrorCode.cancelled,
            message: 'recording.start.cancelled',
          ),
        );
        throw RealtimeException(
          code: RealtimeErrorCode.invalidState,
          message: 'Room was disposed while cloud recording was starting.',
          providerId: providerId,
        );
      }
      _taskState = RecordingTaskState.recording;
      _startDurationTicker();
      _setStatus(RecordingStatus.recording);
      return result;
    } catch (error, stack) {
      final failure = normalizeRealtimeException(
        error,
        domain: 'recording',
        operation: 'start',
        providerId: providerId,
        stackTrace: stack,
      );
      final uncertain =
          failure.code == RealtimeErrorCode.timeout ||
          failure.code == RealtimeErrorCode.network ||
          failure.code == RealtimeErrorCode.cancelled ||
          failure.code == RealtimeErrorCode.cleanupFailed;
      _taskState = uncertain
          ? RecordingTaskState.unknown
          : RecordingTaskState.failed;
      if (!_cloudStateUnknown) _currentOptions = null;
      _setStatus(
        _cloudStateUnknown ? RecordingStatus.unknown : RecordingStatus.failed,
      );
      onFailure?.call(failure);
      Error.throwWithStackTrace(failure, stack);
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
    try {
      final result = await cloud.queryCloudRecording();
      _taskState = result.taskState;
      _setStatus(RecordingStatus.values.byName(_taskState.name));
      return result;
    } catch (error, stack) {
      Error.throwWithStackTrace(
        normalizeRealtimeException(
          error,
          domain: 'recording',
          operation: 'query',
          providerId: providerId,
          stackTrace: stack,
        ),
        stack,
      );
    }
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
    try {
      return await cloud.cloudRecordingDownloadUrl();
    } catch (error, stack) {
      Error.throwWithStackTrace(
        normalizeRealtimeException(
          error,
          domain: 'recording',
          operation: 'download',
          providerId: providerId,
          stackTrace: stack,
        ),
        stack,
      );
    }
  }

  @override
  Future<RecordingResult?> stopRecording() async {
    if (_disposed || _status == RecordingStatus.idle) return null;
    if (_cloudStateUnknown) await queryCloudRecording();
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
      _taskState = RecordingTaskState.processing;
      _currentOptions = null;
      _duration = Duration.zero;
      _taskState = result.taskState;
      _setStatus(RecordingStatus.values.byName(_taskState.name));
      return result; // Cloud processing may continue after recording stops.
    } catch (error, stack) {
      // A failed stop never proves the remote task stopped. Retain its options
      // and require an authoritative read before attempting another stop.
      _taskState = RecordingTaskState.unknown;
      _setStatus(RecordingStatus.unknown);
      final failure = normalizeRealtimeException(
        error,
        domain: 'recording',
        operation: 'stop',
        providerId: providerId,
        stackTrace: stack,
      );
      onFailure?.call(failure);
      Error.throwWithStackTrace(failure, stack);
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
    final cleanup = Cleanup(timeout: cleanupTimeout);
    await cleanup.run('recording.start', () async {
      await _startCompleted?.future;
    });
    await cleanup.run('recording.pendingStop', () async {
      await _stopCompleted?.future;
    });
    if (_cloudRecordingActive || _cloudStateUnknown) {
      await cleanup.run('recording.stop', () async {
        await stopRecording();
      });
    }
    _disposed = true;
    _stopDurationTicker();
    await cleanup.run('recording.session', () {
      cloudRecordingSession?.dispose();
    });
    await cleanup.run('recording.statuses', _statusController.close);
    await cleanup.run('recording.durations', _durationController.close);
    cleanup.finish(domain: 'recording');
  }
}
