part of 'trtc_media_session.dart';

class _TrtcDataMessenger {
  _TrtcDataMessenger(this._session);
  final _TrtcSessionBase _session;
  String get providerId => _session.providerId;
  MediaCapabilities get capabilities => _session.capabilities;
  MediaRole get role => _session.role;
  MediaSessionState get state => _session.state;
  MediaSnapshot get snapshot => _session.snapshot;
  Duration get cleanupTimeout => _session.cleanupTimeout;

  int dataPayloadSizeBytes(String message, MediaSendOptions options) => utf8
      .encode(
        jsonEncode({'topic': options.topic.trim(), 'message': message.trim()}),
      )
      .length;

  void _messageReceived(String userId, int cmdId, String data) {
    if (cmdId != _customMessageCommandId) return;
    String message = data;
    String topic = 'chat';
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map) {
        message = decoded['message']?.toString() ?? data;
        topic = decoded['topic']?.toString() ?? topic;
      }
    } on FormatException {
      // Older TRTC senders may send a plain text payload.
    }
    final incoming = MediaMessage(
      participantId: userId,
      displayName:
          _session._mapper._findParticipant(userId)?.displayName ?? userId,
      message: message,
      topic: topic,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      providerId: providerId,
    );
    _session._setSnapshot(
      _session._snapshot.copyWith(
        messages: [..._session._snapshot.messages, incoming],
      ),
    );
    _session._eventController.add(MediaMessageReceived(incoming));
  }

  Future<void> _sendMessage(String message, {required String topic}) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidArgument,
        message: 'Message must not be empty.',
        providerId: providerId,
      );
    }
    if (!_session._capabilities.canSendData) {
      throw RealtimeException(
        code: RealtimeErrorCode.unsupportedFeature,
        message: 'TRTC viewers cannot send custom messages.',
        providerId: providerId,
      );
    }
    _session._requireConnected();
    final payload = jsonEncode({'topic': topic, 'message': trimmed});
    if (utf8.encode(payload).length > 1000) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidArgument,
        message: 'TRTC custom messages must be 1000 bytes or fewer.',
        providerId: providerId,
      );
    }
    try {
      final sent = _session._engine!.sendCustomCmdMsg(
        _customMessageCommandId,
        payload,
      );
      if (!sent) {
        throw RealtimeException(
          code: RealtimeErrorCode.providerError,
          message: 'TRTC did not accept the custom message.',
          providerId: providerId,
        );
      }
      final info = _session._joinInfo!;
      final outgoing = MediaMessage(
        participantId: info.userId,
        displayName: info.displayName,
        message: trimmed,
        topic: topic,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        providerId: providerId,
      );
      _session._setSnapshot(
        _session._snapshot.copyWith(
          messages: [..._session._snapshot.messages, outgoing],
        ),
      );
    } catch (error, stack) {
      throw _session._mapError(error, 'sendMessage', stack: stack);
    }
  }
}
