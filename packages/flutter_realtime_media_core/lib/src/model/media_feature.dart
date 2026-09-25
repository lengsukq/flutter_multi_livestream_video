import 'media_capabilities.dart';

enum MediaFeature {
  publishAudio,
  publishVideo,
  switchCamera,
  screenShare,
  sendData,
  subscribeVideo,
  enumerateAudioDevices,
  enumerateMicrophones,
  enumerateCameras,
  selectMicrophone,
  selectCamera,
  selectAudioOutput,
  networkStats,
  targetedData,
  unreliableData,
  unorderedData,
  listParticipants,
  removeParticipants,
  closeRoom,
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
    MediaFeature.enumerateMicrophones => canEnumerateMicrophones,
    MediaFeature.enumerateCameras => canEnumerateCameras,
    MediaFeature.selectMicrophone => canSelectMicrophone,
    MediaFeature.selectCamera => canSelectCamera,
    MediaFeature.selectAudioOutput => canSelectAudioOutput,
    MediaFeature.networkStats => canReportNetworkStats,
    MediaFeature.targetedData => canTargetData,
    MediaFeature.unreliableData => canSendUnreliableData,
    MediaFeature.unorderedData => canSendUnorderedData,
    MediaFeature.listParticipants => canListParticipants,
    MediaFeature.removeParticipants => canRemoveParticipants,
    MediaFeature.closeRoom => canCloseRoom,
  };
}
