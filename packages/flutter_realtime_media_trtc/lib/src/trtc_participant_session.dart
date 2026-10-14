part of 'trtc_media_session.dart';

class TrtcParticipantSession extends _TrtcInteractiveSession {
  TrtcParticipantSession({
    TrtcEngineFactory engineFactory = createNativeTrtcEngine,
  }) : super(MediaRole.participant, engineFactory);
}
