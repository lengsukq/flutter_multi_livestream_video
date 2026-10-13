import 'package:flutter_realtime_foundation/flutter_realtime_foundation.dart';

/// Recording execution is handled by the configured cloud provider backend.
enum RecordingMode { cloud }

/// Layout mode for composited multi-party cloud recording.
enum RecordingLayout { grid, speaker, screenShare, custom }

/// Authoritative task state returned by the cloud control plane.
enum RecordingTaskState {
  idle,
  starting,
  recording,
  processing,
  completed,
  failed,
  unknown,
}

/// Local recording operation state.
enum RecordingStatus {
  idle,
  starting,
  recording,
  stopping,
  processing,
  completed,
  unknown,
  failed,
}

enum RecordingStreamType { both, audioOnly, videoOnly }

enum RecordingContainerFormat { mp4, aac, hls, mkv }

/// Preferred cloud encoding quality. Actual availability is provider-specific.
enum RecordingQualityPreset { hd720p30, fullHd1080p30 }

/// Cloud recording options; no media is captured or saved by the client.
class RecordingOptions {
  const RecordingOptions({
    this.mode = RecordingMode.cloud,
    this.layout = RecordingLayout.grid,
    this.streamType = RecordingStreamType.both,
    this.containerFormat = RecordingContainerFormat.mp4,
    this.qualityPreset = RecordingQualityPreset.hd720p30,
    this.rawProviderParams = const {},
  });

  factory RecordingOptions.cloud({
    RecordingLayout layout = RecordingLayout.grid,
    RecordingStreamType streamType = RecordingStreamType.both,
    RecordingContainerFormat containerFormat = RecordingContainerFormat.mp4,
    RecordingQualityPreset qualityPreset = RecordingQualityPreset.hd720p30,
    Map<String, dynamic> rawProviderParams = const {},
  }) => RecordingOptions(
    mode: RecordingMode.cloud,
    layout: layout,
    streamType: streamType,
    containerFormat: containerFormat,
    qualityPreset: qualityPreset,
    rawProviderParams: rawProviderParams,
  );

  final RecordingMode mode;
  final RecordingLayout layout;
  final RecordingStreamType streamType;
  final RecordingContainerFormat containerFormat;
  final RecordingQualityPreset qualityPreset;
  final Map<String, dynamic> rawProviderParams;

  RecordingOptions copyWith({
    RecordingMode? mode,
    RecordingLayout? layout,
    RecordingStreamType? streamType,
    RecordingContainerFormat? containerFormat,
    RecordingQualityPreset? qualityPreset,
    Map<String, dynamic>? rawProviderParams,
  }) => RecordingOptions(
    mode: mode ?? this.mode,
    layout: layout ?? this.layout,
    streamType: streamType ?? this.streamType,
    containerFormat: containerFormat ?? this.containerFormat,
    qualityPreset: qualityPreset ?? this.qualityPreset,
    rawProviderParams: rawProviderParams ?? this.rawProviderParams,
  );

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'layout': layout.name,
    'streamType': streamType.name,
    'containerFormat': containerFormat.name,
    'qualityPreset': qualityPreset.name,
    if (rawProviderParams.isNotEmpty) 'rawProviderParams': rawProviderParams,
  };
}

/// Backend recording task result. The backend may still be processing files.
class RecordingResult {
  RecordingResult({
    required this.mode,
    required this.taskState,
    this.fileName,
    this.mimeType,
    this.recordingId,
    this.duration = Duration.zero,
    this.fileSizeBytes = 0,
    Map<String, dynamic> metadata = const {},
  }) : metadata = freezeJson(metadata) as Map<String, dynamic>;

  final RecordingMode mode;
  final RecordingTaskState taskState;
  final String? fileName;
  final String? mimeType;
  final String? recordingId;
  final Duration duration;
  final int fileSizeBytes;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    if (recordingId != null) 'recordingId': recordingId,
    if (fileName != null) 'fileName': fileName,
    if (mimeType != null) 'mimeType': mimeType,
    'taskState': taskState.name,
    'durationSeconds': duration.inSeconds,
    'fileSizeBytes': fileSizeBytes,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };
}
