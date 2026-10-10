/// Mode of recording execution.
enum RecordingMode {
  /// Recorded directly on the client device and stored to local disk.
  local,

  /// Recorded on the cloud media provider infrastructure and saved to cloud storage.
  cloud,
}

/// Layout mode for composited multi-party recording.
enum RecordingLayout {
  /// Adaptive uniform grid layout (Best-Fit / Grid).
  grid,

  /// Active speaker highlighted with thumbnails for other participants.
  speaker,

  /// Priority on shared screen / whiteboard presentation.
  screenShare,

  /// Fully customized coordinate layout.
  custom,
}

/// Lifecycle status of the recording session.
enum RecordingStatus { idle, starting, recording, stopping, failed }

/// Stream content type to record.
enum RecordingStreamType { both, audioOnly, videoOnly }

/// Output container format.
enum RecordingContainerFormat { mp4, aac, hls, mkv }

/// Unified recording configuration with flexible parameter pass-through.
class RecordingOptions {
  /// Creates recording configuration.
  const RecordingOptions({
    this.mode = RecordingMode.local,
    this.localFilePath,
    this.layout = RecordingLayout.grid,
    this.streamType = RecordingStreamType.both,
    this.containerFormat = RecordingContainerFormat.mp4,
    this.rawProviderParams = const {},
  });

  /// Factory helper for client-side local recording.
  factory RecordingOptions.local({
    String? localFilePath,
    RecordingStreamType streamType = RecordingStreamType.both,
    RecordingContainerFormat containerFormat = RecordingContainerFormat.mp4,
    Map<String, dynamic> rawProviderParams = const {},
  }) => RecordingOptions(
    mode: RecordingMode.local,
    localFilePath: localFilePath,
    streamType: streamType,
    containerFormat: containerFormat,
    rawProviderParams: rawProviderParams,
  );

  /// Factory helper for cloud-side recording.
  factory RecordingOptions.cloud({
    RecordingLayout layout = RecordingLayout.grid,
    RecordingStreamType streamType = RecordingStreamType.both,
    RecordingContainerFormat containerFormat = RecordingContainerFormat.mp4,
    Map<String, dynamic> rawProviderParams = const {},
  }) => RecordingOptions(
    mode: RecordingMode.cloud,
    layout: layout,
    streamType: streamType,
    containerFormat: containerFormat,
    rawProviderParams: rawProviderParams,
  );

  /// The execution target of the recording.
  final RecordingMode mode;

  /// Custom destination file path on the client device (for [RecordingMode.local]).
  /// When null, the SDK generates a default file in the application sandbox.
  final String? localFilePath;

  /// Composited layout mode for multi-party meetings (for [RecordingMode.cloud]).
  final RecordingLayout layout;

  /// Audio/video stream selection.
  final RecordingStreamType streamType;

  /// File container format.
  final RecordingContainerFormat containerFormat;

  /// Provider-specific parameter pass-through without SDK constraints.
  /// Any raw key-value pairs here will be merged directly into the provider's
  /// API payload (e.g. Agora `storageConfig`, AWS Chime `ArtifactsConcatenationConfiguration`,
  /// Tencent TRTC `MixLayoutParams`, LiveKit `file_outputs`).
  final Map<String, dynamic> rawProviderParams;

  RecordingOptions copyWith({
    RecordingMode? mode,
    String? localFilePath,
    RecordingLayout? layout,
    RecordingStreamType? streamType,
    RecordingContainerFormat? containerFormat,
    Map<String, dynamic>? rawProviderParams,
  }) => RecordingOptions(
    mode: mode ?? this.mode,
    localFilePath: localFilePath ?? this.localFilePath,
    layout: layout ?? this.layout,
    streamType: streamType ?? this.streamType,
    containerFormat: containerFormat ?? this.containerFormat,
    rawProviderParams: rawProviderParams ?? this.rawProviderParams,
  );

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    if (localFilePath != null) 'localFilePath': localFilePath,
    'layout': layout.name,
    'streamType': streamType.name,
    'containerFormat': containerFormat.name,
    if (rawProviderParams.isNotEmpty) 'rawProviderParams': rawProviderParams,
  };
}

/// The result returned when recording starts or finishes.
class RecordingResult {
  const RecordingResult({
    required this.mode,
    this.localFilePath,
    this.recordingId,
    this.duration = Duration.zero,
    this.fileSizeBytes = 0,
    this.metadata = const {},
  });

  /// The recording mode.
  final RecordingMode mode;

  /// The absolute path where the local file was saved (for [RecordingMode.local]).
  final String? localFilePath;

  /// Provider cloud recording task id (for [RecordingMode.cloud]).
  final String? recordingId;

  /// Total recorded duration.
  final Duration duration;

  /// File size in bytes if available on disk.
  final int fileSizeBytes;

  /// Arbitrary extra metadata returned by provider or local recorder.
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    if (localFilePath != null) 'localFilePath': localFilePath,
    if (recordingId != null) 'recordingId': recordingId,
    'durationSeconds': duration.inSeconds,
    'fileSizeBytes': fileSizeBytes,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };
}
