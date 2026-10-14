part of 'artc_media_session.dart';

class _ArtcDataMessenger {
  _ArtcDataMessenger(this._session);
  final _ArtcMediaSession _session;
  String get providerId => _session.providerId;
  MediaCapabilities get capabilities => _session.capabilities;
  MediaRole get role => _session.role;
  MediaSessionState get state => _session.state;
  MediaSnapshot get snapshot => _session.snapshot;
  Duration get cleanupTimeout => _session.cleanupTimeout;

  int dataPayloadSizeBytes(String message, MediaSendOptions options) => utf8
      .encode(
        jsonEncode({'message': message.trim(), 'topic': options.topic.trim()}),
      )
      .length;

  void _receiveMessage(String userId, String rawData) {
    if (rawData.isEmpty) return;
    var message = rawData;
    var topic = 'chat';
    try {
      final decoded = jsonDecode(rawData);
      if (decoded is Map) {
        message = decoded['message']?.toString() ?? rawData;
        topic = decoded['topic']?.toString() ?? 'chat';
      }
    } on FormatException {
      // Preserve raw messages sent by non-SDK clients.
    }
    final item = MediaMessage(
      participantId: userId,
      displayName:
          _session._mapper._participantById(userId)?.displayName ?? userId,
      message: message,
      topic: topic,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      providerId: providerId,
    );
    _appendMessage(item);
    _session._emit(MediaMessageReceived(item));
  }

  void _appendMessage(MediaMessage message) {
    _session._setSnapshot(
      _session._snapshot.copyWith(
        messages: [..._session._snapshot.messages, message],
      ),
    );
  }

  Future<void> _sendMessage(String message, {String topic = 'chat'}) async {
    _session._requireActive();
    _session._requireCapability(
      _session._capabilities.canSendData,
      'sending data messages',
    );
    if (_session._snapshot.localMuted &&
        !_session._snapshot.localVideoEnabled) {
      throw _session._error(
        RealtimeErrorCode.invalidState,
        'ARTC data messages require an active local audio or video stream. Enable the microphone or camera first.',
      );
    }
    final content = message.trim();
    final normalizedTopic = topic.trim();
    if (content.isEmpty || normalizedTopic.isEmpty) {
      throw _session._error(
        RealtimeErrorCode.invalidArgument,
        'ARTC messages and topics must not be empty.',
      );
    }
    final envelope = jsonEncode({'message': content, 'topic': normalizedTopic});
    if (utf8.encode(envelope).length > 1000) {
      throw _session._error(
        RealtimeErrorCode.invalidArgument,
        'ARTC data messages must be at most 1000 UTF-8 bytes.',
      );
    }
    await _session._engine!.sendMessage(content, normalizedTopic);
    final info = _session._joinInfo!;
    final item = MediaMessage(
      participantId: info.userId,
      displayName: info.displayName,
      message: content,
      topic: normalizedTopic,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      providerId: providerId,
    );
    _appendMessage(item);
  }
}
