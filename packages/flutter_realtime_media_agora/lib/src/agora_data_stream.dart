part of 'agora_media_session.dart';

class _AgoraDataStream {
  _AgoraDataStream(this._session);
  final _AgoraMediaSession _session;
  String get providerId => _session.providerId;
  MediaCapabilities get capabilities => _session.capabilities;
  MediaRole get role => _session.role;
  MediaSessionState get state => _session.state;
  MediaSnapshot get snapshot => _session.snapshot;
  Duration get cleanupTimeout => _session.cleanupTimeout;

  int? _dataStreamId;
  Future<int>? _dataStreamFuture;
  final List<MediaMessage> _messages = [];
  int dataPayloadSizeBytes(String message, MediaSendOptions options) => utf8
      .encode(
        jsonEncode({
          'version': 1,
          'topic': options.topic.trim(),
          'message': message.trim(),
          'timestampMs': DateTime.now().millisecondsSinceEpoch,
        }),
      )
      .length;

  void _handleStreamMessage(int remoteUid, Uint8List data, int sentTs) {
    final text = utf8.decode(data, allowMalformed: true);
    String topic = 'data';
    String message = text;
    int timestampMs = sentTs > 0
        ? sentTs
        : DateTime.now().millisecondsSinceEpoch;
    final metadata = <String, String>{};
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        final mappedMessage = map['message']?.toString();
        if (mappedMessage != null) {
          message = mappedMessage;
          topic = map['topic']?.toString().trim().isNotEmpty == true
              ? map['topic'].toString().trim()
              : 'chat';
          if (topic == agoraScreenShareTopic) {
            final signal = decodeAgoraScreenShareSignal(data);
            if (signal != null) {
              _session._mapper._setRemoteScreenPublisher(remoteUid, signal);
            }
            return;
          }
          final ts = map['timestampMs'];
          if (ts is num) metadata['senderTimestampMs'] = ts.toInt().toString();
        }
      }
    } catch (_) {
      // Plain-text data from non-SDK Agora clients remains readable.
    }
    final participant = _session._mapper._participants[remoteUid.toString()];
    final mediaMessage = MediaMessage(
      participantId: remoteUid.toString(),
      displayName: participant?.displayName ?? remoteUid.toString(),
      message: message,
      topic: topic,
      timestampMs: timestampMs,
      providerId: providerId,
      metadata: metadata,
    );
    _messages.add(mediaMessage);
    _session._refreshSnapshot();
    _session._emit(MediaMessageReceived(mediaMessage));
  }

  Future<void> _announceScreenShareState(bool enabled) async {
    if (!_session._canPublish ||
        _session._engine == null ||
        _session._joinCancelled ||
        _session._disposed) {
      return;
    }
    try {
      final streamId = await _ensureDataStream();
      if (_session._disposed ||
          _session._joinCancelled ||
          _session._engine == null) {
        return;
      }
      final payload = encodeAgoraScreenShareSignal(
        enabled
            ? AgoraScreenShareSignal.started
            : AgoraScreenShareSignal.stopped,
      );
      await _session._requireEngine().sendStreamMessage(
        streamId: streamId,
        data: payload,
        length: payload.length,
      );
    } catch (error, stack) {
      if (_session._disposed || _session._joinCancelled) return;
      _session._reportFailure(
        _session._mapError(error, 'screenShare.announce', stack: stack),
      );
    }
  }

  Future<void> sendMessage(String message, {String topic = 'chat'}) async {
    _session._ensureActive();
    if (!capabilities.canSendData) {
      throw const RealtimeException(
        code: RealtimeErrorCode.unsupportedFeature,
        message:
            'Agora viewer data sending is disabled because RTC data streams '
            'are host-only in live broadcasting.',
        providerId: _agoraProviderId,
      );
    }
    final normalizedMessage = message.trim();
    final normalizedTopic = topic.trim();
    if (normalizedMessage.isEmpty) {
      throw const RealtimeException(
        code: RealtimeErrorCode.invalidArgument,
        message: 'Message must not be empty.',
        providerId: _agoraProviderId,
      );
    }
    if (normalizedTopic.isEmpty) {
      throw const RealtimeException(
        code: RealtimeErrorCode.invalidArgument,
        message: 'Message topic must not be empty.',
        providerId: _agoraProviderId,
      );
    }
    final streamId = await _ensureDataStream();
    final encoded = utf8.encode(
      jsonEncode({
        'version': 1,
        'topic': normalizedTopic,
        'message': normalizedMessage,
        'timestampMs': DateTime.now().millisecondsSinceEpoch,
      }),
    );
    if (encoded.length > 1024) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidArgument,
        message:
            'Agora RTC data-stream messages must be at most 1024 bytes; '
            'encoded payload is ${encoded.length} bytes.',
        providerId: providerId,
      );
    }
    try {
      final data = Uint8List.fromList(encoded);
      await _session._requireEngine().sendStreamMessage(
        streamId: streamId,
        data: data,
        length: data.length,
      );
    } catch (error, stack) {
      throw _session._mapError(error, 'sendMessage', stack: stack);
    }
  }

  Future<int> _ensureDataStream() async {
    final existing = _dataStreamId;
    if (existing != null) return existing;

    final inFlight = _dataStreamFuture;
    if (inFlight != null) return inFlight;

    final engine = _session._requireEngine();
    final future = engine
        .createDataStream(
          const agora.DataStreamConfig(syncWithAudio: false, ordered: true),
        )
        .timeout(const Duration(seconds: 5));
    _dataStreamFuture = future;
    try {
      final streamId = await future;
      _dataStreamId = streamId;
      return streamId;
    } catch (error, stack) {
      throw _session._mapError(error, 'dataStream.create', stack: stack);
    } finally {
      _dataStreamFuture = null;
    }
  }
}
