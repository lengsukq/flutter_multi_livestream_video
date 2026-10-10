import 'recording_options.dart';

/// Optional transport for a real provider cloud recorder.
///
/// The SDK passes neutral parameters, while the backend signs provider API
/// requests and protects storage credentials. This is UI and provider-neutral.
abstract interface class MediaCloudRecordingSession {
  Future<RecordingResult> startCloudRecording(RecordingOptions options);
  Future<RecordingResult> stopCloudRecording();
  Future<RecordingResult> queryCloudRecording();
  Future<Uri> cloudRecordingDownloadUrl();

  /// Releases client HTTP connections. Does not itself delete cloud artifacts.
  void dispose();
}
