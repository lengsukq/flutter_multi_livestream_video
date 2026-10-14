part of 'agora_media_session.dart';

class AgoraInteractiveSession extends _AgoraMediaSession
    implements InteractiveMediaSession {
  AgoraInteractiveSession({super.engineFactory}) : super(MediaRole.participant);

  @override
  Future<void> setMuted(bool muted) => _publishing.setMutedInternal(muted);

  @override
  Future<void> toggleMute() => _publishing.toggleMuteInternal();

  @override
  Future<void> setVideoEnabled(bool enabled) =>
      _publishing.setVideoEnabledInternal(enabled);

  @override
  Future<void> setScreenShareEnabled(bool enabled) =>
      _publishing.setScreenShareEnabledInternal(enabled);

  @override
  Future<void> switchCamera(MediaCameraPosition position) =>
      _publishing.switchCameraInternal(position);

  @override
  Future<List<MediaAudioDevice>> listAudioDevices() =>
      _publishing.listAudioDevicesInternal();

  @override
  Future<void> selectAudioDevice(MediaAudioDevice device) =>
      _publishing.selectAudioDeviceInternal(device);
}
