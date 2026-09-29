import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core_web.dart';

import 'ivs_chat_engine.dart';
import 'ivs_chat_join_info.dart';

@JS('globalThis')
external JSObject get _globalThis;

Future<IvsChatEngine> createPlatformIvsChatEngine() async =>
    _WebIvsChatEngine();

class _WebIvsChatEngine implements IvsChatEngine {
  _WebIvsChatEngine()
    : _runtime = WebChatRuntime<IvsChatJoinInfo>(
        providerId: IvsChatJoinInfo.providerIdValue,
        driverFactory: _IvsChatWebDriver.new,
      );

  final WebChatRuntime<IvsChatJoinInfo> _runtime;

  @override
  Future<void> connect(
    IvsChatJoinInfo info,
    IvsChatEngineEvents events, {
    IvsChatTokenProvider? tokenProvider,
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

class _IvsChatWebDriver implements WebChatDriver<IvsChatJoinInfo> {
  static final Map<String, WebChatDriverEvents> _handlers = {};
  static final Map<String, WebChatTokenProvider<IvsChatJoinInfo>>
  _tokenProviders = {};
  static bool _callbacksInstalled = false;
  static int _nextSessionId = 0;

  _IvsChatWebDriver()
    : _sessionId =
          'ivs_chat_${DateTime.now().microsecondsSinceEpoch}_${_nextSessionId++}';

  final String _sessionId;
  bool _created = false;

  @override
  Future<void> connect(
    IvsChatJoinInfo info,
    WebChatDriverEvents events, {
    WebChatTokenProvider<IvsChatJoinInfo>? tokenProvider,
  }) async {
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
        IvsChatJoinInfo.providerIdValue,
        'Unable to connect to Amazon IVS Chat.',
        error,
      );
    }
  }

  @override
  Future<void> sendMessage(String message) =>
      _command('sendMessage', {'message': message});

  @override
  Future<void> deleteMessage(String messageId) =>
      _command('deleteMessage', {'messageId': messageId});

  @override
  Future<void> disconnectUser(String userId) =>
      _command('disconnectUser', {'userId': userId});

  @override
  Future<void> disconnect() async {
    if (!_created) return;
    await _command('disconnect', const {});
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
    }
  }

  Future<void> _command(String name, Map<String, Object?> arguments) async {
    if (!_created) {
      throw StateError('IVS Chat Web driver is not connected.');
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
    if (!_globalThis.has('IvsChatMessagingBridge')) {
      throw const ChatError(
        code: ChatErrorCode.unsupportedPlatform,
        message:
            'The local chat provider bridge has not been loaded. Follow the Web setup instructions.',
        providerId: IvsChatJoinInfo.providerIdValue,
        details: {'reason': 'web-sdk-unavailable'},
      );
    }
    return _globalThis['IvsChatMessagingBridge'] as JSObject;
  }

  static void _installCallbacks() {
    if (_callbacksInstalled) return;
    _globalThis['__flutterIvsChatOnEvent'] =
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
                      'Amazon IVS Chat reported an error.',
                );
            }
          } catch (_) {
            // Ignore malformed SDK events and keep the browser event loop alive.
          }
        }).toJS;
    _globalThis['__flutterIvsChatRequestToken'] = ((JSString sessionId) {
      final provider = _tokenProviders[sessionId.toDart];
      if (provider == null) {
        return Future<JSString>.error(
          StateError('No IVS Chat token refresh provider is configured.'),
        ).toJS;
      }
      return provider()
          .then((info) => jsonEncode(_tokenPayload(info)).toJS)
          .toJS;
    }).toJS;
    _callbacksInstalled = true;
  }

  static Map<String, Object?> _tokenPayload(IvsChatJoinInfo info) => {
    'token': info.token,
    'tokenExpirationTimeMs': info.tokenExpirationTimeMs,
    'sessionExpirationTimeMs': info.sessionExpirationTimeMs,
  };
}
