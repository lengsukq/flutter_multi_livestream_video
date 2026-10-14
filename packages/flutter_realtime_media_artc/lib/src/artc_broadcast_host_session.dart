part of 'artc_media_session.dart';

class ArtcBroadcastHostSession extends _ArtcMediaSession
    implements BroadcastHostSession {
  ArtcBroadcastHostSession({required super.engineFactory})
    : super(role: MediaRole.host);

  @override
  Future<void> setMuted(bool muted) => _publishing._setMuted(muted);

  @override
  Future<void> toggleMute() => setMuted(!snapshot.localMuted);

  @override
  Future<void> setVideoEnabled(bool enabled) =>
      _publishing._setVideoEnabled(enabled);

  @override
  Future<void> setScreenShareEnabled(bool enabled) =>
      _publishing._setScreenShareEnabled(enabled);

  @override
  Future<void> switchCamera(MediaCameraPosition position) =>
      _publishing._switchCamera(position);

  @override
  Future<List<MediaAudioDevice>> listAudioDevices() =>
      _publishing._listAudioDevices();

  @override
  Future<void> selectAudioDevice(MediaAudioDevice device) =>
      _publishing._selectAudioDevice(device);

  @override
  Future<void> sendMessage(String message, {String topic = 'chat'}) =>
      _data._sendMessage(message, topic: topic);
}
