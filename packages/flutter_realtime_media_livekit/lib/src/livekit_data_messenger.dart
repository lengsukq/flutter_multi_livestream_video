part of 'livekit_media_session.dart';

class _LiveKitDataMessenger {
  _LiveKitDataMessenger(this._session);
  final LiveKitMediaSessionBase _session;
  String get providerId => _session.providerId;
  MediaCapabilities get capabilities => _session.capabilities;
  MediaRole get role => _session.role;
  MediaSessionState get state => _session.state;
  MediaSnapshot get snapshot => _session.snapshot;
  Duration get cleanupTimeout => _session.cleanupTimeout;

  Future<void> sendMessage(String message, {String topic = 'chat'}) =>
      sendDataMessage(message, options: MediaSendOptions(topic: topic));

  Future<void> sendDataMessage(
    String message, {
    MediaSendOptions options = const MediaSendOptions(),
  }) async {
    _session._ensureActive();
    if (!capabilities.canSendData) {
      throw RealtimeException(
        code: RealtimeErrorCode.unsupportedFeature,
        message: 'This LiveKit token does not allow sending data.',
        providerId: providerId,
      );
    }
    if (message.trim().isEmpty) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidArgument,
        message: 'Message must not be empty.',
        providerId: providerId,
      );
    }
    if (options.topic.trim().isEmpty) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidArgument,
        message: 'Message topic must not be empty.',
        providerId: providerId,
      );
    }
    try {
      await _session._requireLocalParticipant().publishData(
        utf8.encode(message),
        reliable: options.reliability == MediaDataReliability.reliable,
        destinationIdentities: options.targetParticipantIds.isEmpty
            ? null
            : options.targetParticipantIds,
        topic: options.topic,
      );
    } catch (error, stack) {
      throw _session._mapError(error, 'sendMessage', stackTrace: stack);
    }
  }
}
