import 'media_management_capability.dart';

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
    this.canBlurBackground = false,
    this.canReplaceBackgroundImage = false,
    this.canSwitchCamera = false,
    this.canScreenShare = false,
    this.canSendData = false,
    this.canReceiveData = false,
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
    this.management,
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
        canReceiveData: true,
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
        canReceiveData: true,
        canSubscribeVideo: true,
        canEnumerateAudioDevices: true,
      );

  /// Broadcast viewer: subscribe and chat only, no media publishing.
  const MediaCapabilities.broadcastViewer({
    bool canSendData = true,
    bool canReceiveData = true,
  }) : this(
         canSubscribeVideo: true,
         canSendData: canSendData,
         canReceiveData: canReceiveData,
       );

  final bool canPublishAudio;
  final bool canPublishVideo;
  final bool canBlurBackground;
  final bool canReplaceBackgroundImage;
  final bool canSwitchCamera;
  final bool canScreenShare;
  final bool canSendData;
  final bool canReceiveData;
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
  final MediaManagementCapabilities? management;

  MediaManagementCapabilities get managementCapabilities =>
      management ??
      MediaManagementCapabilities(
        listParticipants: canListParticipants
            ? const ManagementCapability.backend()
            : const ManagementCapability.unsupported(),
        removeParticipant: canRemoveParticipants
            ? const ManagementCapability.backend()
            : const ManagementCapability.unsupported(),
        closeRoom: canCloseRoom
            ? const ManagementCapability.backend()
            : const ManagementCapability.unsupported(),
      );

  /// Provider limit on simultaneous video subscriptions, when it exposes one.
  final int? maxVideoSubscriptions;

  MediaCapabilities copyWith({
    bool? canPublishAudio,
    bool? canPublishVideo,
    bool? canBlurBackground,
    bool? canReplaceBackgroundImage,
    bool? canSwitchCamera,
    bool? canScreenShare,
    bool? canSendData,
    bool? canReceiveData,
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
    MediaManagementCapabilities? management,
    int? maxVideoSubscriptions,
  }) => MediaCapabilities(
    canPublishAudio: canPublishAudio ?? this.canPublishAudio,
    canPublishVideo: canPublishVideo ?? this.canPublishVideo,
    canBlurBackground: canBlurBackground ?? this.canBlurBackground,
    canReplaceBackgroundImage:
        canReplaceBackgroundImage ?? this.canReplaceBackgroundImage,
    canSwitchCamera: canSwitchCamera ?? this.canSwitchCamera,
    canScreenShare: canScreenShare ?? this.canScreenShare,
    canSendData: canSendData ?? this.canSendData,
    canReceiveData: canReceiveData ?? this.canReceiveData,
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
    management: management ?? this.management,
    maxVideoSubscriptions: maxVideoSubscriptions ?? this.maxVideoSubscriptions,
  );

  @override
  String toString() =>
      'MediaCapabilities(audio: $canPublishAudio, video: $canPublishVideo, '
      'backgroundBlur: $canBlurBackground, '
      'switchCamera: $canSwitchCamera, screenShare: $canScreenShare, '
      'dataSend: $canSendData, dataReceive: $canReceiveData, '
      'subscribeVideo: $canSubscribeVideo, '
      'networkStats: $canReportNetworkStats)';
}
