part of 'trtc_media_session.dart';

class TrtcViewerSession extends _TrtcSessionBase
    implements BroadcastViewerSession {
  TrtcViewerSession({TrtcEngineFactory engineFactory = createNativeTrtcEngine})
    : super(MediaRole.viewer, _viewerCapabilities, engineFactory);

  @override
  Future<void> sendMessage(String message, {String topic = 'chat'}) =>
      _data._sendMessage(message, topic: topic);
}
