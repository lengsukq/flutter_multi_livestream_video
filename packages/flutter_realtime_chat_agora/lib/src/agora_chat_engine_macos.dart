import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core_web.dart';

import 'agora_chat_engine.dart';
import 'agora_chat_join_info.dart';

Future<AgoraChatEngine> createMacOSAgoraChatEngine() async =>
    _AgoraChatMacOSEngine();

class _AgoraChatMacOSEngine implements AgoraChatEngine {
  _AgoraChatMacOSEngine()
    : _runtime = WebChatRuntime<AgoraChatJoinInfo>(
        providerId: AgoraChatJoinInfo.providerIdValue,
        driverFactory: _AgoraChatMacOSDriver.new,
      );

  final WebChatRuntime<AgoraChatJoinInfo> _runtime;

  @override
  Future<void> connect(
    AgoraChatJoinInfo info,
    AgoraChatEngineEvents events, {
    AgoraChatTokenProvider? tokenProvider,
  }) => _runtime.connect(
    info,
    WebChatDriverEvents(
      onConnecting: events.onConnecting,
      onConnected: events.onConnected,
      onDisconnected: events.onDisconnected,
      onMessage: events.onMessage,
      onMessageDeleted: events.onMessageDeleted,
      onUserDisconnected: events.onUserDisconnected,
      onError: events.onError,
    ),
    tokenProvider: tokenProvider,
  );

  @override
  Future<void> sendMessage(String message) => _runtime.sendMessage(message);

  @override
  Future<void> deleteMessage(String messageId) =>
      _runtime.deleteMessage(messageId);

  @override
  Future<void> disconnectUser(String userId) => _runtime.disconnectUser(userId);

  @override
  Future<void> disconnect() => _runtime.disconnect();

  @override
  Future<void> dispose() => _runtime.dispose();
}

class _AgoraChatMacOSDriver implements WebChatDriver<AgoraChatJoinInfo> {
  _AgoraChatMacOSDriver()
    : _sessionId =
          'agora_chat_${DateTime.now().microsecondsSinceEpoch}_${_nextId++}';

  static const MethodChannel _channel = MethodChannel(
    'flutter_realtime_chat_agora/macos',
  );
  static final Map<String, WebChatDriverEvents> _handlers = {};
  static final Map<String, WebChatTokenProvider<AgoraChatJoinInfo>>
  _tokenProviders = {};
  static int _nextId = 0;
  static bool _handlerInstalled = false;

  final String _sessionId;
  bool _created = false;
  AgoraChatJoinInfo? _info;

  @override
  Future<void> connect(
    AgoraChatJoinInfo info,
    WebChatDriverEvents events, {
    WebChatTokenProvider<AgoraChatJoinInfo>? tokenProvider,
  }) async {
    _installHandler();
    _info = info;
    _handlers[_sessionId] = events;
    if (tokenProvider != null) _tokenProviders[_sessionId] = tokenProvider;
    await _channel.invokeMethod<void>('create', {
      'sessionId': _sessionId,
      'joinInfo': info.json,
    });
    _created = true;
    await _channel.invokeMethod<void>('connect', {'sessionId': _sessionId});
  }

  @override
  Future<void> sendMessage(String message) async {
    final info = _info;
    if (!_created || info == null) {
      throw StateError('Agora Chat macOS driver is not connected.');
    }
    await _channel.invokeMethod<void>('command', {
      'sessionId': _sessionId,
      'command': 'sendMessage',
      'arguments': jsonEncode({
        'message': message,
        'userId': info.userId,
        'displayName': info.displayName,
        'participantId': info.participantId,
      }),
    });
  }

  @override
  Future<void> deleteMessage(String messageId) async => throw UnsupportedError(
    'Agora Chat moderator message deletion is not enabled by this adapter.',
  );

  @override
  Future<void> disconnectUser(String userId) async => throw UnsupportedError(
    'Agora Chat moderator user removal is not enabled by this adapter.',
  );

  @override
  Future<void> disconnect() async {
    if (!_created) return;
    await _channel.invokeMethod<void>('disconnect', {'sessionId': _sessionId});
  }

  @override
  Future<void> dispose() async {
    try {
      if (_created) {
        await _channel.invokeMethod<void>('dispose', {'sessionId': _sessionId});
      }
    } finally {
      _handlers.remove(_sessionId);
      _tokenProviders.remove(_sessionId);
      _created = false;
      _info = null;
    }
  }

  static void _installHandler() {
    if (_handlerInstalled) return;
    _channel.setMethodCallHandler(_handleNativeCall);
    _handlerInstalled = true;
  }

  static Future<Object?> _handleNativeCall(MethodCall call) async {
    final arguments = call.arguments;
    if (arguments is! Map) return null;
    final values = Map<String, Object?>.from(arguments);
    final sessionId = values['sessionId']?.toString() ?? '';
    switch (call.method) {
      case 'onEvent':
        _dispatchEvent(sessionId, values);
        return null;
      case 'requestToken':
        final provider = _tokenProviders[sessionId];
        if (provider == null) {
          throw PlatformException(
            code: 'token-refresh-unavailable',
            message: 'No Agora Chat token refresh provider is configured.',
          );
        }
        final refreshed = await provider();
        return {'token': refreshed.token};
      default:
        throw PlatformException(
          code: 'unimplemented',
          message: 'Unknown Agora Chat macOS callback: ${call.method}.',
        );
    }
  }

  static void _dispatchEvent(String sessionId, Map<String, Object?> values) {
    final events = _handlers[sessionId];
    if (events == null) return;
    final type = values['eventType']?.toString() ?? '';
    final rawPayload = values['payload'];
    Map<String, Object?> payload = const {};
    if (rawPayload is String && rawPayload.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPayload);
        if (decoded is Map) payload = Map<String, Object?>.from(decoded);
      } catch (_) {
        return;
      }
    } else if (rawPayload is Map) {
      payload = Map<String, Object?>.from(rawPayload);
    }

    switch (type) {
      case 'connecting':
        events.onConnecting?.call(payload['reconnecting'] == true);
      case 'connected':
        events.onConnected?.call();
      case 'disconnected':
        events.onDisconnected?.call(payload['reason']?.toString() ?? 'unknown');
      case 'message':
        events.onMessage?.call(payload);
      case 'messageDeleted':
        final messageId = payload['messageId']?.toString() ?? '';
        if (messageId.isNotEmpty) events.onMessageDeleted?.call(messageId);
      case 'userDisconnected':
        final userId = payload['userId']?.toString() ?? '';
        if (userId.isNotEmpty) events.onUserDisconnected?.call(userId);
      case 'error':
        events.onError?.call(
          (payload['code'] as num?)?.toInt() ?? -1,
          payload['message']?.toString() ?? 'Agora Chat reported an error.',
        );
    }
  }
}
