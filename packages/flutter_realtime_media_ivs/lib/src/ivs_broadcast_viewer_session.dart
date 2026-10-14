part of 'ivs_media_session.dart';

class IvsBroadcastViewerSession extends _IvsMediaSession
    implements BroadcastViewerSession {
  IvsBroadcastViewerSession({required super.engineFactory})
    : super(role: MediaRole.viewer);

  @override
  Future<void> sendMessage(String message, {String topic = 'chat'}) =>
      _unsupported('RTC data messaging; use a Chat Provider instead');
}
