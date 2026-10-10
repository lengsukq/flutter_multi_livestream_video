import 'dart:async';

import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

/// Concrete recording controller implementation for [RealtimeRoom].
///
/// Delegates capture to an actual recorder exposed by the media adapter.
/// Cloud descriptors do not execute vendor server-side recording APIs.
class RoomRecordingController implements MediaRecordingController {
  RoomRecordingController({
    required this.media,
    required this.providerId,
    this.localRecordingDriver,
    this.cloudRecordingSession,
    this.onFailure,
  });

  final MediaRoomSession media;
  final String providerId;
  final MediaLocalRecordingSession? localRecordingDriver;
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
  String? _currentLocalFilePath;
  MediaLocalRecordingSession? _activeRecorder;
  bool _cloudRecordingActive = false;
  StreamSubscription<String>? _interruptionSubscription;
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

  /// Current recording options if active.
  RecordingOptions? get currentOptions => _currentOptions;

  /// Current local file path if recording locally.
  String? get currentLocalFilePath => _currentLocalFilePath;

  @override
  Future<RecordingResult> startRecording([RecordingOptions? options]) async {
    if (_disposed || _disposing) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidState,
        message: 'Cannot start recording because the room has been disposed.',
        providerId: providerId,
      );
    }

    if (_status == RecordingStatus.recording ||
        _status == RecordingStatus.starting ||
        _status == RecordingStatus.stopping) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidState,
        message: 'A recording session is already in progress.',
        providerId: providerId,
      );
    }

    final opts = options ?? const RecordingOptions(mode: RecordingMode.local);
    if (opts.mode == RecordingMode.cloud) {
      final cloud = cloudRecordingSession;
      if (cloud == null || !providerId.toLowerCase().contains('livekit')) {
        throw RealtimeException(
          code: RealtimeErrorCode.unsupportedFeature,
          message:
              'Cloud recording V1 requires a LiveKit room and backend executor.',
          providerId: providerId,
        );
      }
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
    final session = media.session;
    final MediaLocalRecordingSession? recorder =
        localRecordingDriver ??
        (session is MediaLocalRecordingSession &&
                session.capabilities.canRecordLocal
            ? session as MediaLocalRecordingSession
            : null);
    if (recorder == null) {
      throw RealtimeException(
        code: RealtimeErrorCode.unsupportedFeature,
        message:
            'Real local recording is unavailable for this provider and platform.',
        providerId: providerId,
      );
    }
    _currentOptions = opts;
    _startCompleted = Completer<void>();
    _setStatus(RecordingStatus.starting);

    try {
      final started = await recorder.startLocalRecording(opts);
      if (_disposing) {
        // A system permission picker can resolve after room disposal begins.
        // Never leave the just-started native capture running behind the UI.
        try {
          await recorder.stopLocalRecording();
        } catch (_) {
          // The original disposal error remains authoritative.
        }
        throw RealtimeException(
          code: RealtimeErrorCode.invalidState,
          message: 'Room was disposed while recording permission was pending.',
          providerId: providerId,
        );
      }
      _activeRecorder = recorder;
      if (recorder is MediaRecordingInterruptionSource) {
        _interruptionSubscription =
            (recorder as MediaRecordingInterruptionSource)
                .recordingInterruptions
                .listen(_handleRecordingInterruption);
      }
      _currentLocalFilePath = started.localFilePath;
      _startDurationTicker();
      _setStatus(RecordingStatus.recording);
      return started;
    } catch (e, stack) {
      _cloudRecordingActive = false;
      await _interruptionSubscription?.cancel();
      _interruptionSubscription = null;
      _activeRecorder = null;
      _currentOptions = null;
      _currentLocalFilePath = null;
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

  void _handleRecordingInterruption(String reason) {
    if (_disposed || _status != RecordingStatus.recording) return;
    _stopDurationTicker();
    _currentOptions = null;
    _currentLocalFilePath = null;
    _activeRecorder = null;
    _setStatus(RecordingStatus.failed);
    onFailure?.call(
      RealtimeException(
        code: RealtimeErrorCode.invalidState,
        message: 'Local recording was interrupted by the platform: $reason',
        providerId: providerId,
      ),
    );
    unawaited(_interruptionSubscription?.cancel());
    _interruptionSubscription = null;
  }

  @override
  void downloadRecording(RecordingResult result) {
    if (result.mode != RecordingMode.local || result.downloadId == null) {
      throw RealtimeException(
        code: RealtimeErrorCode.unsupportedFeature,
        message: 'This recording has no browser download artifact.',
        providerId: providerId,
      );
    }
    final session = localRecordingDriver ?? media.session;
    if (session is! MediaLocalRecordingSession) {
      throw RealtimeException(
        code: RealtimeErrorCode.unsupportedFeature,
        message: 'Browser recording download is not supported here.',
        providerId: providerId,
      );
    }
    session.downloadLocalRecording(result);
  }

  @override
  Future<String> exportRecording(RecordingResult result) async {
    if (_disposed ||
        result.mode != RecordingMode.local ||
        result.localFilePath == null ||
        result.fileSizeBytes <= 0) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidState,
        message: 'A finalized native recording is required to export.',
        providerId: providerId,
      );
    }
    final candidate = localRecordingDriver ?? media.session;
    if (candidate is! MediaRecordingArtifactExporter) {
      throw RealtimeException(
        code: RealtimeErrorCode.unsupportedFeature,
        message: 'Recording file export is not available on this platform.',
        providerId: providerId,
      );
    }
    return candidate.exportRecording(result);
  }

  @override
  Future<RecordingResult?> stopRecording() async {
    if (_disposed || _status == RecordingStatus.idle) {
      return null;
    }
    if (_status != RecordingStatus.recording ||
        (_activeRecorder == null && !_cloudRecordingActive)) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidState,
        message: 'No running recording is ready to stop.',
        providerId: providerId,
      );
    }

    _setStatus(RecordingStatus.stopping);
    _stopCompleted = Completer<void>();
    _stopDurationTicker();

    try {
      if (_cloudRecordingActive) {
        final result = await cloudRecordingSession!.stopCloudRecording();
        _cloudRecordingActive = false;
        _setStatus(RecordingStatus.idle);
        _currentOptions = null;
        _duration = Duration.zero;
        return result; // Processing on server: not a completed file.
      }
      final result = await _activeRecorder!.stopLocalRecording();
      if (result.fileSizeBytes <= 0) {
        throw StateError('Recording produced no media bytes.');
      }
      await _interruptionSubscription?.cancel();
      _interruptionSubscription = null;
      _setStatus(RecordingStatus.idle);
      _currentOptions = null;
      _currentLocalFilePath = null;
      _activeRecorder = null;
      _duration = Duration.zero;

      return result;
    } catch (e, stack) {
      await _interruptionSubscription?.cancel();
      _interruptionSubscription = null;
      _activeRecorder = null;
      _currentOptions = null;
      _currentLocalFilePath = null;
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
    } finally {
      _stopCompleted?.complete();
      _stopCompleted = null;
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
  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _disposing = true;
    // Wait for an in-flight permission dialog / codec start to settle. The
    // start path notices _disposing and finalizes any capture it just opened.
    await _startCompleted?.future;
    if (_status == RecordingStatus.recording &&
        (_activeRecorder != null || _cloudRecordingActive)) {
      try {
        await stopRecording();
      } catch (_) {}
    }
    // If an app-initiated stop is already finalizing, do not tear down its
    // media session and event controllers underneath it.
    await _stopCompleted?.future;
    _disposed = true;
    cloudRecordingSession?.dispose();
    await _interruptionSubscription?.cancel();
    _interruptionSubscription = null;
    _stopDurationTicker();
    await _statusController.close();
    await _durationController.close();
  }
}
