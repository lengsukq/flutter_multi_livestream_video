part of 'artc_media_session.dart';

class ArtcBroadcastViewerSession extends _ArtcMediaSession
    implements BroadcastViewerSession {
  ArtcBroadcastViewerSession({required super.engineFactory})
    : super(role: MediaRole.viewer);

  @override
  Future<void> sendMessage(String message, {String topic = 'chat'}) =>
      _data._sendMessage(message, topic: topic);
}
