part of 'livekit_media_session.dart';

MediaCapabilities _capabilitiesForRole(MediaRole role) {
  final canSelectAudioInput =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows);
  final canSelectAudioOutput =
      !kIsWeb && defaultTargetPlatform != TargetPlatform.iOS;
  final isViewer = role == MediaRole.viewer;
  final isHost = role == MediaRole.host;
  return MediaCapabilities(
    canPublishAudio: !isViewer,
    canPublishVideo: !isViewer,
    canBlurBackground:
        !isViewer &&
        (kIsWeb ||
            defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.macOS),
    canReplaceBackgroundImage:
        !isViewer &&
        (kIsWeb ||
            defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.macOS),
    canSwitchCamera:
        !isViewer &&
        (kIsWeb ||
            defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS),
    // LiveKit's Flutter Web SDK does not support screen capture on mobile
    // browsers, even though desktop browsers support getDisplayMedia.
    canScreenShare: !isViewer && (!kIsWeb || !lk.lkPlatformIsWebMobile()),
    canSendData: true,
    canReceiveData: true,
    canSubscribeVideo: true,
    canEnumerateAudioDevices: true,
    canEnumerateMicrophones: !isViewer,
    canEnumerateCameras: !isViewer,
    canSelectMicrophone: !isViewer && (kIsWeb || canSelectAudioInput),
    canSelectCamera: !isViewer,
    canSelectAudioOutput: canSelectAudioOutput,
    canTargetData: true,
    canSendUnreliableData: true,
    canReportNetworkStats: true,
    maxDataMessageBytes: 15 * 1024,
    canListParticipants: isHost,
    canRemoveParticipants: isHost,
    canCloseRoom: isHost,
  );
}

MediaCapabilities _capabilitiesWithDataPermission(
  MediaCapabilities current,
  bool canSendData,
) => current.copyWith(canSendData: canSendData);
