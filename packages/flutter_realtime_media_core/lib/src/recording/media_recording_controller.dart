import 'dart:async';

import 'cloud_recording_descriptor.dart';
import 'recording_options.dart';

/// Contract for controlling cloud recording lifecycle.
abstract interface class MediaRecordingController {
  /// Current status of the recording session.
  RecordingStatus get status;

  /// Emits status changes.
  Stream<RecordingStatus> get statuses;

  /// Current recorded duration.
  Duration get duration;

  /// Emits periodic duration ticks during recording.
  Stream<Duration> get durations;

  /// Starts recording with optional [options].
  ///
  /// Delegates to the configured backend recording executor.
  Future<RecordingResult> startRecording([RecordingOptions? options]);

  /// Stops the active cloud recording session; media processing may continue.
  Future<RecordingResult?> stopRecording();

  /// Check server-side cloud recording status, including asynchronous
  /// finalization after StopEgress. Does not imply a file is ready.
  Future<RecordingResult> queryCloudRecording();

  /// A short-lived HTTPS URL available only after cloud recording completes.
  Future<Uri> cloudRecordingDownloadUrl();

  /// Generates a structured [CloudRecordingDescriptor] containing official
  /// vendor API endpoints, HTTP headers, and request body payloads for the
  /// active provider and room.
  CloudRecordingDescriptor describeCloudRecording([RecordingOptions? options]);
}
