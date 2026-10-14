part of 'agora_media_session.dart';

class AgoraViewerSession extends _AgoraMediaSession
    implements BroadcastViewerSession {
  AgoraViewerSession({super.engineFactory}) : super(MediaRole.viewer);
}
