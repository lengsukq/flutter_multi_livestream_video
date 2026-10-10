import 'recording_options.dart';

/// Optional platform operation to save a finalized local recording outside
/// the application's private sandbox. No UI or vendor SDK dependency.
abstract interface class MediaRecordingArtifactExporter {
  /// User-visible exported path or content URI. May open a native save dialog.
  ///
  /// Implementations MUST validate that [result] belongs to their recording
  /// directory and points to a finalized readable video file.
  Future<String> exportRecording(RecordingResult result);
}
