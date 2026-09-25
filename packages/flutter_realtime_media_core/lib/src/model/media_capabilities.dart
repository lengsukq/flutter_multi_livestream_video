/// Feature declaration for a session.
///
/// Adapters advertise what they actually implement instead of pretending every
/// provider is identical. Calling an operation that is not declared here must
/// fail with `MediaErrorCode.unsupportedFeature` rather than silently doing
/// nothing.
class MediaCapabilities {
  const MediaCapabilities({
    this.canPublishAudio = false,
    this.canPublishVideo = false,
    this.canSwitchCamera = false,
    this.canScreenShare = false,
    this.canSendData = false,
    this.canSubscribeVideo = false,
    this.canEnumerateAudioDevices = false,
    this.canEnumerateMicrophones = false,
    this.canEnumerateCameras = false,
    this.canSelectMicrophone = false,
    this.canSelectCamera = false,
    this.canSelectAudioOutput = false,
    this.canReportNetworkStats = false,
    this.canTargetData = false,
    this.canSendUnreliableData = false,
    this.canSendUnorderedData = false,
    this.maxDataMessageBytes,
    this.canListParticipants = false,
    this.canRemoveParticipants = false,
    this.canCloseRoom = false,
    this.maxVideoSubscriptions,
  });

  /// A session with no media ability at all.
  const MediaCapabilities.none() : this();

  /// Symmetric meeting capability set: publish and subscribe audio and video.
  const MediaCapabilities.meeting()
    : this(
        canPublishAudio: true,
        canPublishVideo: true,
        canSwitchCamera: true,
        canSendData: true,
        canSubscribeVideo: true,
        canEnumerateAudioDevices: true,
      );

  /// Broadcast host: meeting abilities plus screen share.
  const MediaCapabilities.broadcastHost()
    : this(
        canPublishAudio: true,
        canPublishVideo: true,
        canSwitchCamera: true,
        canScreenShare: true,
        canSendData: true,
        canSubscribeVideo: true,
        canEnumerateAudioDevices: true,
      );

  /// Broadcast viewer: subscribe and chat only, no media publishing.
  const MediaCapabilities.broadcastViewer({bool canSendData = true})
    : this(canSubscribeVideo: true, canSendData: canSendData);

  final bool canPublishAudio;
  final bool canPublishVideo;
  final bool canSwitchCamera;
  final bool canScreenShare;
  final bool canSendData;
  final bool canSubscribeVideo;
  final bool canEnumerateAudioDevices;
  final bool canEnumerateMicrophones;
  final bool canEnumerateCameras;
  final bool canSelectMicrophone;
  final bool canSelectCamera;
  final bool canSelectAudioOutput;
  final bool canReportNetworkStats;
  final bool canTargetData;
  final bool canSendUnreliableData;
  final bool canSendUnorderedData;
  final int? maxDataMessageBytes;
  final bool canListParticipants;
  final bool canRemoveParticipants;
  final bool canCloseRoom;

  /// Provider limit on simultaneous video subscriptions, when it exposes one.
  final int? maxVideoSubscriptions;

  MediaCapabilities copyWith({
    bool? canPublishAudio,
    bool? canPublishVideo,
    bool? canSwitchCamera,
    bool? canScreenShare,
    bool? canSendData,
    bool? canSubscribeVideo,
    bool? canEnumerateAudioDevices,
    bool? canEnumerateMicrophones,
    bool? canEnumerateCameras,
    bool? canSelectMicrophone,
    bool? canSelectCamera,
    bool? canSelectAudioOutput,
    bool? canReportNetworkStats,
    bool? canTargetData,
    bool? canSendUnreliableData,
    bool? canSendUnorderedData,
    int? maxDataMessageBytes,
    bool? canListParticipants,
    bool? canRemoveParticipants,
    bool? canCloseRoom,
    int? maxVideoSubscriptions,
  }) => MediaCapabilities(
    canPublishAudio: canPublishAudio ?? this.canPublishAudio,
    canPublishVideo: canPublishVideo ?? this.canPublishVideo,
    canSwitchCamera: canSwitchCamera ?? this.canSwitchCamera,
    canScreenShare: canScreenShare ?? this.canScreenShare,
    canSendData: canSendData ?? this.canSendData,
    canSubscribeVideo: canSubscribeVideo ?? this.canSubscribeVideo,
    canEnumerateAudioDevices:
        canEnumerateAudioDevices ?? this.canEnumerateAudioDevices,
    canEnumerateMicrophones:
        canEnumerateMicrophones ?? this.canEnumerateMicrophones,
    canEnumerateCameras: canEnumerateCameras ?? this.canEnumerateCameras,
    canSelectMicrophone: canSelectMicrophone ?? this.canSelectMicrophone,
    canSelectCamera: canSelectCamera ?? this.canSelectCamera,
    canSelectAudioOutput: canSelectAudioOutput ?? this.canSelectAudioOutput,
    canReportNetworkStats: canReportNetworkStats ?? this.canReportNetworkStats,
    canTargetData: canTargetData ?? this.canTargetData,
    canSendUnreliableData: canSendUnreliableData ?? this.canSendUnreliableData,
    canSendUnorderedData: canSendUnorderedData ?? this.canSendUnorderedData,
    maxDataMessageBytes: maxDataMessageBytes ?? this.maxDataMessageBytes,
    canListParticipants: canListParticipants ?? this.canListParticipants,
    canRemoveParticipants: canRemoveParticipants ?? this.canRemoveParticipants,
    canCloseRoom: canCloseRoom ?? this.canCloseRoom,
    maxVideoSubscriptions: maxVideoSubscriptions ?? this.maxVideoSubscriptions,
  );

  @override
  String toString() =>
      'MediaCapabilities(audio: $canPublishAudio, video: $canPublishVideo, '
      'switchCamera: $canSwitchCamera, screenShare: $canScreenShare, '
      'data: $canSendData, subscribeVideo: $canSubscribeVideo, '
      'networkStats: $canReportNetworkStats)';
}
