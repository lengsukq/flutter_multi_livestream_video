part of 'trtc_media_session.dart';

MediaCapabilities _publisherCapabilities(MediaRole role) => MediaCapabilities(
  canPublishAudio: true,
  canPublishVideo: true,
  canBlurBackground:
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.macOS),
  canReplaceBackgroundImage:
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.macOS),
  canEnumerateCameras:
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.macOS),
  canSelectCamera:
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.macOS),
  canSwitchCamera:
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS),
  canScreenShare:
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows),
  canSendData: true,
  canReceiveData: true,
  canSubscribeVideo: true,
  canReportNetworkStats: true,
  maxDataMessageBytes: 1024,
  canListParticipants: role == MediaRole.host,
  canCloseRoom: role == MediaRole.host,
);
const _viewerCapabilities = MediaCapabilities(
  canSubscribeVideo: true,
  canSendData: false,
  canReceiveData: true,
  canReportNetworkStats: true,
);
