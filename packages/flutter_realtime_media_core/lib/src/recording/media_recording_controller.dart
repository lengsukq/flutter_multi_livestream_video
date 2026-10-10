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

  /// Generates a structured [CloudRecordingDescriptor] containing official
  /// vendor API endpoints, HTTP headers, and request body payloads for the
  /// active provider and room.
  CloudRecordingDescriptor describeCloudRecording([RecordingOptions? options]);
}
