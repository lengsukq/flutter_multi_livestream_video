import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';

import 'ivs_chat_engine.dart';
import 'ivs_chat_join_info.dart';

@JS('globalThis')
external JSObject get _globalThis;

Future<IvsChatEngine> createPlatformIvsChatEngine() async =>
    _WebIvsChatEngine();

class _WebIvsChatEngine implements IvsChatEngine {
  static final Map<String, IvsChatEngineEvents> _handlers = {};
  static final Map<String, IvsChatTokenProvider> _tokenProviders = {};
  static bool _callbacksInstalled = false;
  static int _nextSessionId = 0;

  _WebIvsChatEngine()
    : _sessionId =
          'ivs_chat_${DateTime.now().microsecondsSinceEpoch}_${_nextSessionId++}';

  final String _sessionId;
  bool _disposed = false;

  @override
  Future<void> connect(
    IvsChatJoinInfo info,
    IvsChatEngineEvents events, {
    IvsChatTokenProvider? tokenProvider,
  }) async {
    if (_disposed) {
      throw const ChatError(
        code: ChatErrorCode.invalidState,
        message: 'IVS Chat engine is disposed.',
        providerId: IvsChatJoinInfo.providerIdValue,
      );
    }
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
      await _bridge
          .callMethod<JSPromise<JSAny?>>('connect'.toJS, _sessionId.toJS)
          .toDart;
    } catch (error) {
      throw _mapError('Unable to connect to Amazon IVS Chat.', error);
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
  Future<void> disconnect() => _command('disconnect', const {});

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    try {
      await _bridge
          .callMethod<JSPromise<JSAny?>>('dispose'.toJS, _sessionId.toJS)
          .toDart;
    } catch (_) {
      // A partially initialized Web SDK session can still be disposed safely.
    } finally {
      _handlers.remove(_sessionId);
      _tokenProviders.remove(_sessionId);
      _disposed = true;
    }
  }

  Future<void> _command(String name, Map<String, Object?> arguments) async {
    if (_disposed) {
      throw const ChatError(
        code: ChatErrorCode.invalidState,
        message: 'IVS Chat engine is disposed.',
        providerId: IvsChatJoinInfo.providerIdValue,
      );
    }
    try {
      await _bridge
          .callMethod<JSPromise<JSAny?>>(
            'command'.toJS,
            _sessionId.toJS,
            name.toJS,
            jsonEncode(arguments).toJS,
          )
          .toDart;
    } catch (error) {
      throw _mapError('Amazon IVS Chat operation "$name" failed.', error);
    }
  }

  static JSObject get _bridge {
    if (!_globalThis.has('IvsChatMessagingBridge')) {
      throw const ChatError(
        code: ChatErrorCode.unsupportedPlatform,
        message:
            'The locally bundled Amazon IVS Chat browser SDK has not been loaded.',
        providerId: IvsChatJoinInfo.providerIdValue,
      );
    }
    return _globalThis['IvsChatMessagingBridge'] as JSObject;
  }

  static void _installCallbacks() {
    if (_callbacksInstalled) return;
    _globalThis['__flutterIvsChatOnEvent'] =
        ((JSString sessionId, JSString type, JSString payload) {
          final handlers = _handlers[sessionId.toDart];
          if (handlers == null) return;
          try {
            final decoded = jsonDecode(payload.toDart);
            if (decoded is! Map) return;
            final event = Map<String, Object?>.from(decoded);
            switch (type.toDart) {
              case 'connecting':
                handlers.onConnecting?.call(event['reconnecting'] == true);
              case 'connected':
                handlers.onConnected?.call();
              case 'disconnected':
                handlers.onDisconnected?.call(
                  event['reason']?.toString() ?? 'unknown',
                );
              case 'message':
                handlers.onMessage?.call(event);
              case 'messageDeleted':
                final messageId = event['messageId']?.toString() ?? '';
                if (messageId.isNotEmpty) {
                  handlers.onMessageDeleted?.call(messageId);
                }
              case 'userDisconnected':
                final userId = event['userId']?.toString() ?? '';
                if (userId.isNotEmpty) {
                  handlers.onUserDisconnected?.call(userId);
                }
              case 'error':
                handlers.onError?.call(
                  (event['code'] as num?)?.toInt() ?? -1,
                  event['message']?.toString() ??
                      'Amazon IVS Chat reported an error.',
                );
            }
          } catch (_) {
            // Malformed SDK events must not break the browser event loop.
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

  ChatError _mapError(String fallback, Object error) {
    if (error is ChatError) return error;
    final message = error.toString();
    final lower = message.toLowerCase();
    final code = lower.contains('forbidden') || lower.contains('permission')
        ? ChatErrorCode.forbidden
        : lower.contains('unauthorized') || lower.contains('token')
        ? ChatErrorCode.unauthorized
        : ChatErrorCode.nativeError;
    return ChatError(
      code: code,
      message: '$fallback $message',
      providerId: IvsChatJoinInfo.providerIdValue,
      details: error,
    );
  }
}
