part of 'trtc_media_session.dart';

abstract class _TrtcInteractiveSession extends _TrtcSessionBase
    implements InteractiveMediaSession {
  _TrtcInteractiveSession(MediaRole role, TrtcEngineFactory engineFactory)
    : super(role, _publisherCapabilities(role), engineFactory);
  @override
  Future<void> setMuted(bool muted) => _publishing.setMuted(muted);
  @override
  Future<void> toggleMute() => _publishing.toggleMute();
  @override
  Future<void> setVideoEnabled(bool enabled) =>
      _publishing.setVideoEnabled(enabled);
  @override
  Future<void> setScreenShareEnabled(bool enabled) =>
      _publishing.setScreenShareEnabled(enabled);
  @override
  Future<void> switchCamera(MediaCameraPosition position) =>
      _publishing.switchCamera(position);
  @override
  Future<List<MediaAudioDevice>> listAudioDevices() =>
      _publishing.listAudioDevices();
  @override
  Future<void> selectAudioDevice(MediaAudioDevice device) =>
      _publishing.selectAudioDevice(device);
  @override
  Future<void> sendMessage(String message, {String topic = 'chat'}) =>
      _data._sendMessage(message, topic: topic);
}
