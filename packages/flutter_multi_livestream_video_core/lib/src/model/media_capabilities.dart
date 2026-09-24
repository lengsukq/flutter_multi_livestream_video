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

  /// Provider limit on simultaneous video subscriptions, when it exposes one.
  final int? maxVideoSubscriptions;

  @override
  String toString() =>
      'MediaCapabilities(audio: $canPublishAudio, video: $canPublishVideo, '
      'switchCamera: $canSwitchCamera, screenShare: $canScreenShare, '
      'data: $canSendData, subscribeVideo: $canSubscribeVideo)';
}
