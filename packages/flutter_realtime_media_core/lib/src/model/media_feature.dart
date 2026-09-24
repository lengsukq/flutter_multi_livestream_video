import 'media_capabilities.dart';

enum MediaFeature {
  publishAudio,
  publishVideo,
  switchCamera,
  screenShare,
  sendData,
  subscribeVideo,
  enumerateAudioDevices,
}

extension MediaCapabilitiesFeatures on MediaCapabilities {
  bool supports(MediaFeature feature) => switch (feature) {
    MediaFeature.publishAudio => canPublishAudio,
    MediaFeature.publishVideo => canPublishVideo,
    MediaFeature.switchCamera => canSwitchCamera,
    MediaFeature.screenShare => canScreenShare,
    MediaFeature.sendData => canSendData,
    MediaFeature.subscribeVideo => canSubscribeVideo,
    MediaFeature.enumerateAudioDevices => canEnumerateAudioDevices,
  };
}
