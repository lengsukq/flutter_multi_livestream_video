import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core_web.dart';

import 'agora_chat_engine.dart';
import 'agora_chat_join_info.dart';

@JS('globalThis')
external JSObject get _globalThis;

Future<AgoraChatEngine> createPlatformAgoraChatEngine() async =>
    _AgoraChatWebEngine();

class _AgoraChatWebEngine implements AgoraChatEngine {
  _AgoraChatWebEngine()
    : _runtime = WebChatRuntime<AgoraChatJoinInfo>(
        providerId: AgoraChatJoinInfo.providerIdValue,
        driverFactory: _AgoraChatWebDriver.new,
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

class _AgoraChatWebDriver implements WebChatDriver<AgoraChatJoinInfo> {
  static final Map<String, WebChatDriverEvents> _handlers = {};
  static final Map<String, WebChatTokenProvider<AgoraChatJoinInfo>>
  _tokenProviders = {};
  static bool _callbacksInstalled = false;
  static int _nextSessionId = 0;

  _AgoraChatWebDriver()
    : _sessionId =
          'agora_chat_${DateTime.now().microsecondsSinceEpoch}_${_nextSessionId++}';

  final String _sessionId;
  bool _created = false;

  @override
  Future<void> connect(
    AgoraChatJoinInfo info,
    WebChatDriverEvents events, {
    WebChatTokenProvider<AgoraChatJoinInfo>? tokenProvider,
  }) async {
    _info = info;
    _installCallbacks();
    _handlers[_sessionId] = events;
    if (tokenProvider != null) _tokenProviders[_sessionId] = tokenProvider;
    try {
      await _bridge
          .callMethod<JSPromise<JSAny?>>(
            'create'.toJS,
            _sessionId.toJS,
            jsonEncode(info.json).toJS,
          )
          .toDart;
      _created = true;
      await _bridge
          .callMethod<JSPromise<JSAny?>>('connect'.toJS, _sessionId.toJS)
          .toDart;
    } catch (error) {
      throw mapWebChatError(
        AgoraChatJoinInfo.providerIdValue,
        'Unable to connect to Agora Chat.',
        error,
      );
    }
  }

  @override
  Future<void> sendMessage(String message) {
    final info = _activeInfo;
    return _command('sendMessage', {
      'message': message,
      'userId': info.userId,
      'displayName': info.displayName,
      'participantId': info.participantId,
    });
  }

  AgoraChatJoinInfo get _activeInfo {
    final info = _info;
    if (!_created || info == null) {
      throw const ChatError(
        code: ChatErrorCode.invalidState,
        message: 'Agora Chat Web driver is not connected.',
        providerId: AgoraChatJoinInfo.providerIdValue,
      );
    }
    return info;
  }

  AgoraChatJoinInfo? _info;

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
    await _bridge
        .callMethod<JSPromise<JSAny?>>('disconnect'.toJS, _sessionId.toJS)
        .toDart;
  }

  @override
  Future<void> dispose() async {
    try {
      if (_created) {
        await _bridge
            .callMethod<JSPromise<JSAny?>>('dispose'.toJS, _sessionId.toJS)
            .toDart;
      }
    } finally {
      _handlers.remove(_sessionId);
      _tokenProviders.remove(_sessionId);
      _created = false;
      _info = null;
    }
  }

  Future<void> _command(String name, Map<String, Object?> arguments) async {
    if (!_created) {
      throw const ChatError(
        code: ChatErrorCode.invalidState,
        message: 'Agora Chat Web driver is not connected.',
        providerId: AgoraChatJoinInfo.providerIdValue,
      );
    }
    await _bridge
        .callMethod<JSPromise<JSAny?>>(
          'command'.toJS,
          _sessionId.toJS,
          name.toJS,
          jsonEncode(arguments).toJS,
        )
        .toDart;
  }

  static JSObject get _bridge {
    if (!_globalThis.has('AgoraChatBridge')) {
      throw const ChatError(
        code: ChatErrorCode.unsupportedPlatform,
        message:
            'The local chat provider bridge has not been loaded. Follow the Web setup instructions.',
        providerId: AgoraChatJoinInfo.providerIdValue,
        details: {'reason': 'web-sdk-unavailable'},
      );
    }
    return _globalThis['AgoraChatBridge'] as JSObject;
  }

  static void _installCallbacks() {
    if (_callbacksInstalled) return;
    _globalThis['__flutterAgoraChatOnEvent'] =
        ((JSString sessionId, JSString type, JSString payload) {
          final events = _handlers[sessionId.toDart];
          if (events == null) return;
          try {
            final decoded = jsonDecode(payload.toDart);
            if (decoded is! Map) return;
            final event = Map<String, Object?>.from(decoded);
            switch (type.toDart) {
              case 'connecting':
                events.onConnecting?.call(event['reconnecting'] == true);
              case 'connected':
                events.onConnected?.call();
              case 'disconnected':
                events.onDisconnected?.call(
                  event['reason']?.toString() ?? 'unknown',
                );
              case 'message':
                events.onMessage?.call(event);
              case 'messageDeleted':
                final messageId = event['messageId']?.toString() ?? '';
                if (messageId.isNotEmpty) {
                  events.onMessageDeleted?.call(messageId);
                }
              case 'userDisconnected':
                final userId = event['userId']?.toString() ?? '';
                if (userId.isNotEmpty) events.onUserDisconnected?.call(userId);
              case 'error':
                events.onError?.call(
                  (event['code'] as num?)?.toInt() ?? -1,
                  event['message']?.toString() ??
                      'Agora Chat reported an error.',
                );
            }
          } catch (_) {
            // Ignore malformed SDK events and keep the browser event loop alive.
          }
        }).toJS;
    _globalThis['__flutterAgoraChatRequestToken'] = ((JSString sessionId) {
      final provider = _tokenProviders[sessionId.toDart];
      if (provider == null) {
        return Future<JSString>.error(
          StateError('No Agora Chat token refresh provider is configured.'),
        ).toJS;
      }
      return provider()
          .then((info) => jsonEncode({'token': info.token}).toJS)
          .toJS;
    }).toJS;
    _callbacksInstalled = true;
  }
}
