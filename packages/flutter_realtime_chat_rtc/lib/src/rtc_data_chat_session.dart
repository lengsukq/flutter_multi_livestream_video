import 'dart:async';
import 'dart:convert';

import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

const String rtcDataChatTopic = 'flutter-realtime-chat.v1';
const int _rtcDataChatEnvelopeVersion = 1;

/// A [ChatSession] backed by an already-connected media session's RTC data
/// channel.
///
/// This adapter is intentionally used only as a fallback when the backend did
/// not bind a dedicated product-chat provider. It never changes media publish
/// permissions and it never owns or disposes the media session.
class RtcDataChatSession implements ChatSession {
  factory RtcDataChatSession({
    required MediaRoomSession room,
    String? userId,
    String? displayName,
    int maxMessages = 200,
    String topic = rtcDataChatTopic,
  }) => RtcDataChatSession.forSession(
    session: room.session,
    roomCode: room.roomCode,
    participantId: room.participantId,
    userId: userId,
    displayName: displayName,
    maxMessages: maxMessages,
    topic: topic,
  );

  RtcDataChatSession.forSession({
    required MediaSession session,
    required this.roomCode,
    required String participantId,
    String? userId,
    String? displayName,
    this.maxMessages = 200,
    this.topic = rtcDataChatTopic,
  }) : _media = session,
       _participantId = participantId,
       _mediaProviderId = session.providerId,
       _userId = _normalizedIdentity(userId, participantId),
       _displayName = _normalizedDisplayName(
         displayName,
         session.snapshot.localParticipant?.displayName,
         participantId,
       ),
       role = _mapRole(session.role),
       _state = _mapState(session.state) {
    if (!canAttach(session)) {
      throw ChatError(
        code: ChatErrorCode.unsupportedFeature,
        message:
            'RTC chat fallback requires both send and receive data support.',
        providerId: 'rtc-data:${session.providerId}',
      );
    }
    if (maxMessages <= 0) {
      throw ArgumentError.value(maxMessages, 'maxMessages', 'must be positive');
    }
    _attach();
    _seedExistingMessages();
    _setState(_mapState(_media.state));
  }

  static bool canAttach(MediaSession session) =>
      session.supportsBidirectionalData &&
      (session is MediaDataMessenger || session is MediaAdvancedDataMessenger);

  static RtcDataChatSession? tryAttach({
    required MediaRoomSession room,
    String? userId,
    String? displayName,
    int maxMessages = 200,
    String topic = rtcDataChatTopic,
  }) {
    if (!canAttach(room.session)) return null;
    return RtcDataChatSession(
      room: room,
      userId: userId,
      displayName: displayName,
      maxMessages: maxMessages,
      topic: topic,
    );
  }

  void _seedExistingMessages() {
    for (final message in _media.snapshot.messages) {
      _ingestMediaMessage(message, emitEvent: false);
    }
  }

  final MediaSession _media;
  final String roomCode;
  final String _participantId;
  final String _mediaProviderId;
  final String _userId;
  final String _displayName;
  final int maxMessages;
  final String topic;
  final List<ChatMessage> _messages = <ChatMessage>[];
  final StreamController<ChatConnectionState> _states =
      StreamController<ChatConnectionState>.broadcast();
  final StreamController<List<ChatMessage>> _messageSnapshots =
      StreamController<List<ChatMessage>>.broadcast();
  final StreamController<ChatEvent> _events =
      StreamController<ChatEvent>.broadcast();

  StreamSubscription<MediaSessionState>? _stateSubscription;
  StreamSubscription<MediaMessage>? _messageSubscription;
  ChatConnectionState _state;
  bool _disposed = false;
  int _messageSequence = 0;
  int _lastTimelineTimestampMs = 0;

  @override
  String get providerId => 'rtc-data:$_mediaProviderId';

  @override
  final ChatRole role;

  @override
  ChatCapabilities get capabilities => ChatCapabilities(
    canSendMessage: !_disposed && _media.supportsBidirectionalData,
  );

  @override
  ChatConnectionState get state => _state;

  @override
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  @override
  Stream<ChatConnectionState> get states => _states.stream;

  @override
  Stream<List<ChatMessage>> get messageSnapshots => _messageSnapshots.stream;

  @override
  Stream<ChatEvent> get events => _events.stream;

  @override
  Future<void> connect(
    ChatJoinInfo joinInfo, {
    ChatCredentialProvider? credentialProvider,
  }) async {
    _ensureNotDisposed();
    if (joinInfo.providerId != providerId ||
        joinInfo.roomCode != roomCode ||
        joinInfo.participantId != _participantId ||
        joinInfo.role != role) {
      throw _error(
        ChatErrorCode.invalidJoinInfo,
        'RTC chat join information does not match the attached media room.',
      );
    }
    _attach();
    _seedExistingMessages();
    _setState(_mapState(_media.state));
  }

  @override
  Future<void> sendMessage(String message) async {
    _ensureConnected();
    final value = message.trim();
    if (value.isEmpty) {
      throw _error(ChatErrorCode.invalidArgument, 'Message must not be empty.');
    }

    final now = _nextTimelineTimestamp();
    final wireId =
        '$_participantId-${now.microsecondsSinceEpoch}-${_messageSequence++}';
    final id = _canonicalMessageId(_participantId, wireId);
    final envelope = <String, Object?>{
      'v': _rtcDataChatEnvelopeVersion,
      'type': 'chat',
      'id': wireId,
      'senderId': _userId,
      'participantId': _participantId,
      'displayName': _displayName,
      'message': value,
      'timestampMs': now.millisecondsSinceEpoch,
    };

    try {
      await _media.sendData(
        jsonEncode(envelope),
        options: MediaSendOptions(topic: topic),
      );
    } on MediaError catch (error) {
      final mapped = _fromMediaError(error);
      _events.add(ChatFailureEvent(mapped));
      throw mapped;
    }

    _upsert(
      ChatMessage(
        id: id,
        userId: _participantId,
        displayName: _displayName,
        message: value,
        timestamp: now,
        topic: topic,
        type: 'message',
        providerId: providerId,
        attributes: {
          'transport': 'rtc-data',
          'mediaProviderId': _mediaProviderId,
          'participantId': _participantId,
          'topic': topic,
          'local': 'true',
          if (_userId != _participantId) 'claimedUserId': _userId,
        },
      ),
    );
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    throw _error(
      ChatErrorCode.unsupportedFeature,
      'RTC chat fallback does not support deleting messages.',
    );
  }

  @override
  Future<void> disconnectUser(String userId) async {
    throw _error(
      ChatErrorCode.unsupportedFeature,
      'RTC chat fallback does not support disconnecting users.',
    );
  }

  @override
  Future<void> disconnect() async {
    if (_disposed) return;
    await _detach();
    _setState(ChatConnectionState.disconnected);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _detach();
    _setState(ChatConnectionState.disposed);
    await _states.close();
    await _messageSnapshots.close();
    await _events.close();
  }

  void _attach() {
    if (_disposed ||
        _stateSubscription != null ||
        _messageSubscription != null) {
      return;
    }
    _stateSubscription = _media.states.listen(
      (state) => _setState(_mapState(state)),
      onError: (Object error, StackTrace stackTrace) {
        if (_disposed) return;
        final mapped = _error(
          ChatErrorCode.unknown,
          'RTC media state stream failed: $error',
        );
        _events.add(ChatFailureEvent(mapped));
        _setState(ChatConnectionState.failed);
      },
    );
    _messageSubscription = _media.dataMessages.listen(
      (message) => _ingestMediaMessage(message),
      onError: (Object error, StackTrace stackTrace) {
        if (_disposed) return;
        _events.add(
          ChatFailureEvent(
            _error(ChatErrorCode.nativeError, 'RTC data stream failed: $error'),
          ),
        );
      },
    );
  }

  Future<void> _detach() async {
    await _stateSubscription?.cancel();
    await _messageSubscription?.cancel();
    _stateSubscription = null;
    _messageSubscription = null;
  }

  void _ingestMediaMessage(MediaMessage incoming, {bool emitEvent = true}) {
    if (_disposed || incoming.topic != topic) return;
    final raw = incoming.message.trim();
    if (raw.isEmpty) return;

    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return;
    }
    if (decoded is! Map) return;
    final json = decoded.map((key, value) => MapEntry(key.toString(), value));
    final version = _readInt(json['v']);
    if (version != _rtcDataChatEnvelopeVersion ||
        json['type']?.toString() != 'chat') {
      return;
    }

    final wireId = json['id']?.toString().trim() ?? '';
    final message = json['message']?.toString() ?? '';
    if (wireId.isEmpty || message.trim().isEmpty) return;

    final providerParticipantId = incoming.participantId.trim();
    final claimedParticipantId = json['participantId']?.toString().trim() ?? '';
    final participantId = providerParticipantId.isNotEmpty
        ? providerParticipantId
        : claimedParticipantId;
    if (participantId.isEmpty) return;

    final id = _canonicalMessageId(participantId, wireId);
    if (_messages.any((item) => item.id == id)) return;

    final claimedUserId = json['senderId']?.toString().trim() ?? '';
    final claimedDisplayName = json['displayName']?.toString().trim() ?? '';
    final providerDisplayName = incoming.displayName.trim();
    final displayName = providerDisplayName.isNotEmpty
        ? providerDisplayName
        : participantId;
    final claimedTimestampMs = _readInt(json['timestampMs']);
    final timestamp = _nextTimelineTimestamp();

    _upsert(
      ChatMessage(
        id: id,
        userId: participantId,
        displayName: displayName,
        message: message,
        timestamp: timestamp,
        topic: incoming.topic,
        type: 'message',
        providerId: providerId,
        attributes: {
          ...incoming.metadata,
          'transport': 'rtc-data',
          'mediaProviderId': incoming.providerId.isEmpty
              ? _mediaProviderId
              : incoming.providerId,
          'participantId': participantId,
          'topic': incoming.topic,
          if (claimedParticipantId.isNotEmpty &&
              claimedParticipantId != participantId)
            'claimedParticipantId': claimedParticipantId,
          if (claimedUserId.isNotEmpty && claimedUserId != participantId)
            'claimedUserId': claimedUserId,
          if (claimedDisplayName.isNotEmpty &&
              claimedDisplayName != displayName)
            'claimedDisplayName': claimedDisplayName,
          if (claimedTimestampMs != null)
            'claimedTimestampMs': claimedTimestampMs.toString(),
        },
      ),
      emitEvent: emitEvent,
    );
  }

  void _upsert(ChatMessage message, {bool emitEvent = true}) {
    final existing = _messages.indexWhere((item) => item.id == message.id);
    final isNew = existing < 0;
    if (existing >= 0) {
      _messages[existing] = message;
    } else {
      _messages.add(message);
    }
    _messages.sort((a, b) {
      final byTime = a.timestamp.compareTo(b.timestamp);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
    if (_messages.length > maxMessages) {
      _messages.removeRange(0, _messages.length - maxMessages);
    }
    if (!_messageSnapshots.isClosed) {
      _messageSnapshots.add(List.unmodifiable(_messages));
    }
    if (emitEvent && isNew && !_events.isClosed) {
      _events.add(ChatMessageReceived(message));
    }
  }

  DateTime _nextTimelineTimestamp() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final next = now > _lastTimelineTimestampMs
        ? now
        : _lastTimelineTimestampMs + 1;
    _lastTimelineTimestampMs = next;
    return DateTime.fromMillisecondsSinceEpoch(next);
  }

  static String _canonicalMessageId(String participantId, String wireId) =>
      '$participantId:$wireId';

  void _setState(ChatConnectionState next) {
    if (_state == next) return;
    _state = next;
    if (!_states.isClosed) _states.add(next);
    if (!_events.isClosed) _events.add(ChatStateChanged(next));
  }

  void _ensureNotDisposed() {
    if (_disposed || _state == ChatConnectionState.disposed) {
      throw _error(ChatErrorCode.invalidState, 'Chat session is disposed.');
    }
  }

  void _ensureConnected() {
    _ensureNotDisposed();
    if (_state != ChatConnectionState.connected) {
      throw _error(
        ChatErrorCode.invalidState,
        'Chat operation requires a connected media session.',
      );
    }
  }

  ChatError _fromMediaError(MediaError error) => ChatError(
    code: switch (error.code) {
      MediaErrorCode.invalidArgument => ChatErrorCode.invalidArgument,
      MediaErrorCode.invalidState ||
      MediaErrorCode.sessionNotFound => ChatErrorCode.invalidState,
      MediaErrorCode.permissionDenied => ChatErrorCode.forbidden,
      MediaErrorCode.unsupportedPlatform => ChatErrorCode.unsupportedPlatform,
      MediaErrorCode.unsupportedFeature => ChatErrorCode.unsupportedFeature,
      MediaErrorCode.nativeError => ChatErrorCode.nativeError,
      _ => ChatErrorCode.unknown,
    },
    message: error.message,
    providerId: providerId,
    details: error,
  );

  ChatError _error(ChatErrorCode code, String message) =>
      ChatError(code: code, message: message, providerId: providerId);

  static ChatRole _mapRole(MediaRole role) => switch (role) {
    MediaRole.participant => ChatRole.participant,
    MediaRole.host => ChatRole.host,
    MediaRole.viewer => ChatRole.viewer,
  };

  static ChatConnectionState _mapState(MediaSessionState state) =>
      switch (state) {
        MediaSessionState.idle ||
        MediaSessionState.leaving ||
        MediaSessionState.ended => ChatConnectionState.disconnected,
        MediaSessionState.joining ||
        MediaSessionState.connecting => ChatConnectionState.connecting,
        MediaSessionState.connected => ChatConnectionState.connected,
        MediaSessionState.reconnecting => ChatConnectionState.reconnecting,
        MediaSessionState.failed => ChatConnectionState.failed,
        MediaSessionState.disposed => ChatConnectionState.disposed,
      };

  static int? _readInt(Object? value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

  static String _normalizedIdentity(String? value, String fallback) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? fallback : normalized;
  }

  static String _normalizedDisplayName(
    String? requested,
    String? localDisplayName,
    String fallback,
  ) {
    final preferred = requested?.trim() ?? '';
    if (preferred.isNotEmpty) return preferred;
    final local = localDisplayName?.trim() ?? '';
    return local.isEmpty ? fallback : local;
  }
}
