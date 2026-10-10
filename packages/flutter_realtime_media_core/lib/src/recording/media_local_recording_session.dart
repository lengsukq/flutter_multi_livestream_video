import 'recording_options.dart';

/// Optional capability implemented by an actual media session or adapter.
///
/// This interface is independent of provider SDKs and Flutter widgets.
/// Implementations MUST capture and encode real media; returning a fabricated
/// file or synthetic recording id is a contract violation.
abstract interface class MediaLocalRecordingSession {
  /// Starts actual media capture. Completes after the encoder has started.
  Future<RecordingResult> startLocalRecording(RecordingOptions options);

  /// Finalizes the recording and returns a playable artifact.
  Future<RecordingResult> stopLocalRecording();

  /// Starts an already completed browser artifact download in a user gesture.
  void downloadLocalRecording(RecordingResult result);
}
