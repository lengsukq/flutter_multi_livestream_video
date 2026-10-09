import 'dart:async';

import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';

import 'ivs_chat_engine.dart';
import 'ivs_chat_join_info.dart';

class IvsChatSession
    implements ChatSession, ChatSessionIdentity, ChatSystemMessaging {
  IvsChatSession({
    required this.role,
    required this.engineFactory,
    int maxMessages = 500,
  }) : _buffer = ChatMessageBuffer(maxMessages: maxMessages);

  int get maxMessages => _buffer.maxMessages;

  final IvsChatEngineFactory engineFactory;
  final ChatMessageBuffer _buffer;
  final StreamController<ChatConnectionState> _states =
      StreamController<ChatConnectionState>.broadcast();
  final StreamController<List<ChatMessage>> _snapshots =
      StreamController<List<ChatMessage>>.broadcast();
  final StreamController<ChatEvent> _events =
      StreamController<ChatEvent>.broadcast();
  final StreamController<String> _systemMessages =
      StreamController<String>.broadcast();
  @override
  Stream<String> get systemMessages => _systemMessages.stream;

  @override
  final ChatRole role;

  IvsChatEngine? _engine;
  IvsChatJoinInfo? _joinInfo;
  ChatCredentialProvider? _credentialProvider;
  ChatConnectionState _state = ChatConnectionState.disconnected;
  bool _disposed = false;
  bool _disconnectRequested = false;
  Future<void>? _connectFuture;
  Future<void>? _disposeFuture;
  Duration cleanupTimeout = const Duration(seconds: 10);

  @override
  String get providerId => IvsChatJoinInfo.providerIdValue;

  @override
  String get localParticipantId => _joinInfo?.participantId ?? '';

  @override
  String get localUserId => _joinInfo?.userId ?? '';

  @override
  String get localDisplayName => _joinInfo?.displayName ?? '';

  @override
  ChatCapabilities get capabilities {
    final info = _joinInfo;
    if (info == null) return const ChatCapabilities.none();
    return ChatCapabilities(
      canSendMessage: info.canSendMessage,
      canDeleteMessage: info.canDeleteMessage,
      canDisconnectUser: info.canDisconnectUser,
    );
  }

  void _ensureConnecting() {
    if (_disconnectRequested || _disposed) {
      throw _error(
        RealtimeErrorCode.cancelled,
        'The IVS Chat connection was cancelled.',
      );
    }
  }

  @override
  Future<void> sendSystemMessage(String payload) async {
    _requireConnected();
    if (!capabilities.canSendMessage) {
      throw _error(
        RealtimeErrorCode.forbidden,
        'Chat cannot send system hints.',
      );
    }
    await _engine!.sendMessage(ChatSystemMessageCodec.encode(payload));
  }

  @override
  ChatConnectionState get state => _state;

  @override
  List<ChatMessage> get messages => _buffer.messages;

  @override
  Stream<ChatConnectionState> get states => _states.stream;

  @override
  Stream<List<ChatMessage>> get messageSnapshots => _snapshots.stream;

  @override
  Stream<ChatEvent> get events => _events.stream;

  @override
  Future<void> connect(
    ChatJoinInfo joinInfo, {
    ChatCredentialProvider? credentialProvider,
  }) {
    if (_connectFuture != null) {
      return Future.error(
        _error(
          RealtimeErrorCode.invalidState,
          'An IVS Chat connect is already pending.',
        ),
      );
    }
    _disconnectRequested = false;
    late final Future<void> future;
    future = _connect(joinInfo, credentialProvider: credentialProvider)
        .whenComplete(() {
          if (identical(_connectFuture, future)) _connectFuture = null;
        });
    _connectFuture = future;
    return future;
  }

  Future<void> _connect(
    ChatJoinInfo joinInfo, {
    ChatCredentialProvider? credentialProvider,
  }) async {
    if (_disposed) {
      throw _error(RealtimeErrorCode.invalidState, 'Chat session is disposed.');
    }
    if (_state != ChatConnectionState.disconnected &&
        _state != ChatConnectionState.failed) {
      throw _error(
        RealtimeErrorCode.invalidState,
        'Chat session is already active.',
      );
    }
    if (joinInfo is! IvsChatJoinInfo ||
        joinInfo.providerId != providerId ||
        joinInfo.role != role) {
      throw _error(
        RealtimeErrorCode.invalidArgument,
        'IVS Chat credentials do not match this session.',
      );
    }

    _joinInfo = joinInfo;
    _credentialProvider = credentialProvider;
    _setState(ChatConnectionState.connecting);
    try {
      _engine ??= await engineFactory();
      _ensureConnecting();
      await _engine!.connect(
        joinInfo,
        _engineEvents(),
        tokenProvider: credentialProvider == null
            ? null
            : () => _refreshCredentials(joinInfo),
      );
      _ensureConnecting();
    } catch (error) {
      if (_disconnectRequested || _disposed) {
        if (_disposed) {
          await _engine?.dispose();
          _engine = null;
        } else {
          await _engine?.disconnect();
        }
        throw _error(
          RealtimeErrorCode.cancelled,
          'The IVS Chat connection was cancelled.',
        );
      }
      final mapped = _mapError(error, 'Unable to connect to Amazon IVS Chat.');
      _setState(ChatConnectionState.failed);
      _events.add(ChatFailureEvent(mapped));
      throw mapped;
    }
  }

  Future<IvsChatJoinInfo> _refreshCredentials(IvsChatJoinInfo current) async {
    final callback = _credentialProvider;
    if (callback == null) {
      throw _error(
        RealtimeErrorCode.invalidState,
        'No chat credential refresh callback is configured.',
      );
    }
    final refreshed = await callback();
    if (refreshed is! IvsChatJoinInfo ||
        refreshed.providerId != current.providerId ||
        refreshed.roomCode != current.roomCode ||
        refreshed.participantId != current.participantId ||
        refreshed.userId != current.userId ||
        refreshed.role != current.role ||
        refreshed.roomArn != current.roomArn) {
      throw _error(
        RealtimeErrorCode.invalidArgument,
        'Refreshed IVS Chat credentials changed the room or identity.',
      );
    }
    _joinInfo = refreshed;
    return refreshed;
  }

  IvsChatEngineEvents _engineEvents() => IvsChatEngineEvents(
    onConnecting: (reconnecting) => _setState(
      reconnecting
          ? ChatConnectionState.reconnecting
          : ChatConnectionState.connecting,
    ),
    onConnected: () => _setState(ChatConnectionState.connected),
    onDisconnected: (reason) {
      if (_disposed) return;
      _setState(
        reason == 'clientDisconnect'
            ? ChatConnectionState.disconnected
            : ChatConnectionState.failed,
      );
    },
    onMessage: _onMessage,
    onMessageDeleted: _onMessageDeleted,
    onUserDisconnected: (userId) {
      if (!_acceptNativeEvent) return;
      _events.add(ChatUserDisconnected(userId));
    },
    onError: (code, message) {
      if (!_acceptNativeEvent) return;
      _events.add(
        ChatFailureEvent(
          RealtimeException(
            code: switch (code) {
              401 => RealtimeErrorCode.unauthorized,
              403 => RealtimeErrorCode.forbidden,
              _ => RealtimeErrorCode.providerError,
            },
            message: message,
            providerId: providerId,
            details: {'nativeCode': code},
          ),
        ),
      );
    },
  );

  bool get _acceptNativeEvent =>
      !_disposed && !_disconnectRequested && !_events.isClosed;

  void _onMessage(Map<String, Object?> raw) {
    if (!_acceptNativeEvent) return;
    final system = ChatSystemMessageCodec.decode(
      raw['message']?.toString() ?? '',
    );
    if (system != null) {
      if (!_systemMessages.isClosed) _systemMessages.add(system);
      return;
    }
    final id = raw['id']?.toString().trim() ?? '';
    final userId = raw['userId']?.toString().trim() ?? '';
    final content = ChatSystemMessageCodec.decodeUserText(
      raw['message']?.toString() ?? '',
    );
    if (id.isEmpty || userId.isEmpty) return;

    final timestampMs =
        (raw['timestampMs'] as num?)?.toInt() ??
        int.tryParse(raw['timestampMs']?.toString() ?? '') ??
        DateTime.now().millisecondsSinceEpoch;
    final attributes = <String, String>{};
    final rawAttributes = raw['attributes'];
    if (rawAttributes is Map) {
      for (final entry in rawAttributes.entries) {
        attributes[entry.key.toString()] = entry.value.toString();
      }
    }
    final message = ChatMessage(
      id: id,
      userId: userId,
      displayName:
          raw['displayName']?.toString() ?? attributes['displayName'] ?? userId,
      message: content,
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMs),
      topic: 'chat',
      type: raw['type']?.toString() ?? 'message',
      providerId: providerId,
      attributes: Map.unmodifiable(attributes),
    );
    final isNew = _buffer.upsert(message);
    _emitMessages();
    if (isNew) _events.add(ChatMessageReceived(message));
  }

  void _onMessageDeleted(String messageId) {
    if (!_acceptNativeEvent) return;
    _buffer.remove(messageId);
    _emitMessages();
    _events.add(ChatMessageDeleted(messageId));
  }

  @override
  Future<void> sendMessage(String message) async {
    _requireConnected();
    if (!capabilities.canSendMessage) {
      throw _error(
        RealtimeErrorCode.forbidden,
        'Chat token cannot send messages.',
      );
    }
    final value = message.trim();
    if (value.isEmpty) {
      throw _error(
        RealtimeErrorCode.invalidArgument,
        'Message must not be empty.',
      );
    }
    await _engine!.sendMessage(ChatSystemMessageCodec.encodeUserText(value));
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    _requireConnected();
    if (!capabilities.canDeleteMessage) {
      throw _error(
        RealtimeErrorCode.forbidden,
        'Only a chat moderator can delete messages.',
      );
    }
    final value = messageId.trim();
    if (value.isEmpty) {
      throw _error(RealtimeErrorCode.invalidArgument, 'messageId is required.');
    }
    await _engine!.deleteMessage(value);
  }

  @override
  Future<void> disconnectUser(String userId) async {
    _requireConnected();
    if (!capabilities.canDisconnectUser) {
      throw _error(
        RealtimeErrorCode.forbidden,
        'Only a chat moderator can disconnect users.',
      );
    }
    final value = userId.trim();
    if (value.isEmpty) {
      throw _error(RealtimeErrorCode.invalidArgument, 'userId is required.');
    }
    await _engine!.disconnectUser(value);
  }

  @override
  Future<void> disconnect() async {
    if (_disposed) return;
    _disconnectRequested = true;
    if (_state == ChatConnectionState.disconnected) return;
    await _engine?.disconnect();
    _setState(ChatConnectionState.disconnected);
  }

  @override
  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    _disconnectRequested = true;
    final cleanup = Cleanup(timeout: cleanupTimeout);
    await cleanup.run('engine.disconnect', () async {
      await _engine?.disconnect();
    });
    await cleanup.run('engine.dispose', () async {
      await _engine?.dispose();
    });
    await cleanup.run('references', () async {
      _engine = null;
      _credentialProvider = null;
    });
    await cleanup.run('terminal', () async {
      _setState(ChatConnectionState.disposed);
    });
    await cleanup.run('states', () async {
      await _states.close();
    });
    await cleanup.run('snapshots', () async {
      await _snapshots.close();
    });
    await cleanup.run('events', () async {
      await _events.close();
    });
    await cleanup.run('systemMessages', () async {
      await _systemMessages.close();
    });
    cleanup.finish(domain: providerId);
  }

  void _setState(ChatConnectionState next) {
    if (_disconnectRequested &&
        next != ChatConnectionState.disconnected &&
        next != ChatConnectionState.disposed) {
      return;
    }
    if (_state == next) return;
    _state = next;
    if (!_states.isClosed) _states.add(next);
    if (!_events.isClosed) _events.add(ChatStateChanged(next));
  }

  void _emitMessages() {
    _snapshots.add(_buffer.messages);
  }

  void _requireConnected() {
    if (_state != ChatConnectionState.connected || _engine == null) {
      throw _error(
        RealtimeErrorCode.invalidState,
        'Chat operation requires a connected session.',
      );
    }
  }

  RealtimeException _mapError(Object error, String fallback) {
    if (error is RealtimeException) return error.withProvider(providerId);
    return RealtimeException(
      code: RealtimeErrorCode.unknown,
      message: error.toString().isEmpty ? fallback : error.toString(),
      providerId: providerId,
    );
  }

  RealtimeException _error(RealtimeErrorCode code, String message) =>
      RealtimeException(code: code, message: message, providerId: providerId);
}
