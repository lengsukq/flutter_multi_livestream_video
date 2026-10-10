import 'dart:async';

import 'cloud_recording_descriptor.dart';
import 'recording_options.dart';

/// Contract for controlling recording lifecycle (both local and cloud).
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
  /// For [RecordingMode.local], starts client-side file recording.
  /// For [RecordingMode.cloud], either delegates to backend or returns
  /// the execution result with task information.
  Future<RecordingResult> startRecording([RecordingOptions? options]);

  /// Stops the active recording session and finishes writing/sealing files.
  Future<RecordingResult?> stopRecording();

  /// Check server-side cloud recording status, including asynchronous
  /// finalization after StopEgress. Does not imply a file is ready.
  Future<RecordingResult> queryCloudRecording();

  /// A short-lived HTTPS URL available only after cloud recording completes.
  Future<Uri> cloudRecordingDownloadUrl();

  /// Initiates a browser download for an already completed local recording.
  /// Must be invoked synchronously from a user action on Web.
  /// Native platforms can use [RecordingResult.localFilePath] instead.
  void downloadRecording(RecordingResult result);

  /// Ask an installed native recorder to export a finished recording outside
  /// its sandbox. Requires a recorder implementing MediaRecordingArtifactExporter.
  Future<String> exportRecording(RecordingResult result);

  /// Generates a structured [CloudRecordingDescriptor] containing official
  /// vendor API endpoints, HTTP headers, and request body payloads for the
  /// active provider and room.
  CloudRecordingDescriptor describeCloudRecording([RecordingOptions? options]);
}
