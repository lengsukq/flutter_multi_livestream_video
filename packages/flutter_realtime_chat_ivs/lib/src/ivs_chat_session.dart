import 'dart:async';

import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';

import 'ivs_chat_engine.dart';
import 'ivs_chat_join_info.dart';

class IvsChatSession implements ChatSession {
  IvsChatSession({required this.role, required this.engineFactory});

  final IvsChatEngineFactory engineFactory;
  final List<ChatMessage> _messages = [];
  final StreamController<ChatConnectionState> _states =
      StreamController<ChatConnectionState>.broadcast();
  final StreamController<List<ChatMessage>> _snapshots =
      StreamController<List<ChatMessage>>.broadcast();
  final StreamController<ChatEvent> _events =
      StreamController<ChatEvent>.broadcast();

  @override
  final ChatRole role;

  IvsChatEngine? _engine;
  IvsChatJoinInfo? _joinInfo;
  ChatCredentialProvider? _credentialProvider;
  ChatConnectionState _state = ChatConnectionState.disconnected;
  bool _disposed = false;

  @override
  String get providerId => IvsChatJoinInfo.providerIdValue;

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

  @override
  ChatConnectionState get state => _state;

  @override
  List<ChatMessage> get messages => List.unmodifiable(_messages);

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
  }) async {
    if (_disposed) {
      throw _error(ChatErrorCode.invalidState, 'Chat session is disposed.');
    }
    if (_state != ChatConnectionState.disconnected &&
        _state != ChatConnectionState.failed) {
      throw _error(
        ChatErrorCode.invalidState,
        'Chat session is already active.',
      );
    }
    if (joinInfo is! IvsChatJoinInfo ||
        joinInfo.providerId != providerId ||
        joinInfo.role != role) {
      throw _error(
        ChatErrorCode.invalidJoinInfo,
        'IVS Chat credentials do not match this session.',
      );
    }

    _joinInfo = joinInfo;
    _credentialProvider = credentialProvider;
    _setState(ChatConnectionState.connecting);
    try {
      _engine ??= await engineFactory();
      await _engine!.connect(
        joinInfo,
        _engineEvents(),
        tokenProvider: credentialProvider == null
            ? null
            : () => _refreshCredentials(joinInfo),
      );
    } catch (error) {
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
        ChatErrorCode.invalidState,
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
        ChatErrorCode.invalidJoinInfo,
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
      _events.add(ChatUserDisconnected(userId));
    },
    onError: (code, message) {
      _events.add(
        ChatFailureEvent(
          ChatError(
            code: code == 403
                ? ChatErrorCode.forbidden
                : ChatErrorCode.nativeError,
            message: message,
            providerId: providerId,
            details: {'nativeCode': code},
          ),
        ),
      );
    },
  );

  void _onMessage(Map<String, Object?> raw) {
    final id = raw['id']?.toString().trim() ?? '';
    final userId = raw['userId']?.toString().trim() ?? '';
    final content = raw['message']?.toString() ?? '';
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
    final index = _messages.indexWhere((item) => item.id == id);
    if (index >= 0) {
      _messages[index] = message;
    } else {
      _messages.add(message);
    }
    _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    _emitMessages();
    _events.add(ChatMessageReceived(message));
  }

  void _onMessageDeleted(String messageId) {
    _messages.removeWhere((message) => message.id == messageId);
    _emitMessages();
    _events.add(ChatMessageDeleted(messageId));
  }

  @override
  Future<void> sendMessage(String message) async {
    _requireConnected();
    if (!capabilities.canSendMessage) {
      throw _error(ChatErrorCode.forbidden, 'Chat token cannot send messages.');
    }
    final value = message.trim();
    if (value.isEmpty) {
      throw _error(ChatErrorCode.invalidArgument, 'Message must not be empty.');
    }
    await _engine!.sendMessage(value);
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    _requireConnected();
    if (!capabilities.canDeleteMessage) {
      throw _error(
        ChatErrorCode.forbidden,
        'Only a chat moderator can delete messages.',
      );
    }
    final value = messageId.trim();
    if (value.isEmpty) {
      throw _error(ChatErrorCode.invalidArgument, 'messageId is required.');
    }
    await _engine!.deleteMessage(value);
  }

  @override
  Future<void> disconnectUser(String userId) async {
    _requireConnected();
    if (!capabilities.canDisconnectUser) {
      throw _error(
        ChatErrorCode.forbidden,
        'Only a chat moderator can disconnect users.',
      );
    }
    final value = userId.trim();
    if (value.isEmpty) {
      throw _error(ChatErrorCode.invalidArgument, 'userId is required.');
    }
    await _engine!.disconnectUser(value);
  }

  @override
  Future<void> disconnect() async {
    if (_disposed || _state == ChatConnectionState.disconnected) return;
    await _engine?.disconnect();
    _setState(ChatConnectionState.disconnected);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    await disconnect();
    _disposed = true;
    await _engine?.dispose();
    _engine = null;
    _credentialProvider = null;
    _setState(ChatConnectionState.disposed);
    await _states.close();
    await _snapshots.close();
    await _events.close();
  }

  void _setState(ChatConnectionState next) {
    if (_state == next) return;
    _state = next;
    _states.add(next);
    _events.add(ChatStateChanged(next));
  }

  void _emitMessages() {
    _snapshots.add(List.unmodifiable(_messages));
  }

  void _requireConnected() {
    if (_state != ChatConnectionState.connected || _engine == null) {
      throw _error(
        ChatErrorCode.invalidState,
        'Chat operation requires a connected session.',
      );
    }
  }

  ChatError _mapError(Object error, String fallback) {
    if (error is ChatError) return error.withProvider(providerId);
    return ChatError(
      code: ChatErrorCode.unknown,
      message: error.toString().isEmpty ? fallback : error.toString(),
      providerId: providerId,
    );
  }

  ChatError _error(ChatErrorCode code, String message) =>
      ChatError(code: code, message: message, providerId: providerId);
}
