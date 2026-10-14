part of 'trtc_media_session.dart';

class TrtcHostSession extends _TrtcInteractiveSession
    implements BroadcastHostSession {
  TrtcHostSession({TrtcEngineFactory engineFactory = createNativeTrtcEngine})
    : super(MediaRole.host, engineFactory);
}
