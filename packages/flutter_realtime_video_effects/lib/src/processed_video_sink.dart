import 'processed_video_source.dart';

/// Provider adapters implement this interface.
///
/// The effects package owns capture and processing. A provider sink receives
/// only a source handle and keeps high-frequency frames on the platform side.
abstract interface class ProcessedVideoSink {
  bool supportsProcessedVideoSource(ProcessedVideoSource source);

  Future<void> attachProcessedVideoSource(ProcessedVideoSource source);

  Future<void> detachProcessedVideoSource();
}
