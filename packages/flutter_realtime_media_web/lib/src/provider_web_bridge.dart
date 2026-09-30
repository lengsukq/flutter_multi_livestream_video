import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

typedef ProviderWebEventHandler =
    void Function(String sessionId, Map<String, dynamic> event);

@JS('globalThis')
external JSObject get _globalThis;

/// Typed Dart access to the locally bundled provider bridge in `web/`.
class ProviderWebBridge {
  ProviderWebBridge._();

  static final Map<String, ProviderWebEventHandler> _handlers = {};
  static bool _listenerInstalled = false;

  static void registerHandler(
    String sessionId,
    ProviderWebEventHandler handler,
  ) {
    _handlers[sessionId] = handler;
    _installListener();
  }

  static Future<void> createLocalPreview({
    required String providerId,
    required String previewId,
    required Map<String, Object?> settings,
  }) async {
    try {
      await _bridge
          .callMethod<JSPromise<JSAny?>>(
            'createLocalPreview'.toJS,
            providerId.toJS,
            previewId.toJS,
            jsonEncode(settings).toJS,
          )
          .toDart;
    } catch (error) {
      throw _mapError(
        providerId,
        'Unable to initialize the SDK local video preview.',
        error,
      );
    }
  }

  static void unregisterHandler(String sessionId) {
    _handlers.remove(sessionId);
  }

  static void _installListener() {
    if (_listenerInstalled) return;
    final callback = ((JSString sessionId, JSString payload) {
      final handler = _handlers[sessionId.toDart];
      if (handler == null) return;
      try {
        final decoded = jsonDecode(payload.toDart);
        if (decoded is Map<String, dynamic>) {
          handler(sessionId.toDart, decoded);
        }
      } catch (_) {
        // Malformed vendor events must not break the browser event loop.
      }
    }).toJS;
    _globalThis['__flutterMediaProviderOnEvent'] = callback;
    _listenerInstalled = true;
  }

  static JSObject get _bridge {
    if (!_globalThis.has('MediaProviderBridge')) {
      throw const MediaError(
        code: MediaErrorCode.unsupportedPlatform,
        message:
            'The locally bundled browser media SDK bridge has not been loaded.',
        details: {'reason': 'web-sdk-unavailable'},
      );
    }
    return _globalThis['MediaProviderBridge'] as JSObject;
  }

  static Future<void> create({
    required String providerId,
    required String sessionId,
    required Map<String, Object?> joinPayload,
  }) async {
    _installListener();
    try {
      await _bridge
          .callMethod<JSPromise<JSAny?>>(
            'create'.toJS,
            providerId.toJS,
            sessionId.toJS,
            jsonEncode(joinPayload).toJS,
          )
          .toDart;
    } catch (error) {
      throw _mapError(
        providerId,
        'Unable to initialize the browser SDK.',
        error,
      );
    }
  }

  static Future<void> join(String providerId, String sessionId) async =>
      _command(providerId, sessionId, 'join');

  static Future<String> command(
    String providerId,
    String sessionId,
    String command, [
    Map<String, Object?> arguments = const {},
  ]) => _command(providerId, sessionId, command, arguments);

  static Future<void> leave(String providerId, String sessionId) async =>
      _command(providerId, sessionId, 'leave');

  static Future<void> dispose(String providerId, String sessionId) async {
    try {
      await _bridge
          .callMethod<JSPromise<JSAny?>>(
            'dispose'.toJS,
            providerId.toJS,
            sessionId.toJS,
          )
          .toDart;
    } catch (_) {
      // Dispose is best-effort after leave and remains safe on partial joins.
    } finally {
      unregisterHandler(sessionId);
    }
  }

  static Future<List<Map<String, Object?>>> listDevices(
    String providerId,
    String sessionId,
  ) async {
    final result = await _command(providerId, sessionId, 'listDevices');
    final decoded = jsonDecode(result);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .toList(growable: false);
  }

  static Future<void> selectDevice(
    String providerId,
    String sessionId,
    Map<String, Object?> device,
  ) => _command(providerId, sessionId, 'selectDevice', device);

  static Future<void> attachVideo({
    required String providerId,
    required String sessionId,
    required String trackId,
    required String elementId,
  }) async {
    await _bridge
        .callMethod<JSPromise<JSAny?>>(
          'attachVideo'.toJS,
          providerId.toJS,
          sessionId.toJS,
          trackId.toJS,
          elementId.toJS,
        )
        .toDart;
  }

  static void detachVideo({
    required String providerId,
    required String sessionId,
    required String trackId,
    required String elementId,
  }) {
    try {
      _bridge.callMethod<JSAny?>(
        'detachVideo'.toJS,
        providerId.toJS,
        sessionId.toJS,
        trackId.toJS,
        elementId.toJS,
      );
    } catch (_) {}
  }

  static Future<String> _command(
    String providerId,
    String sessionId,
    String command, [
    Map<String, Object?> arguments = const {},
  ]) async {
    try {
      final response = await _bridge
          .callMethod<JSPromise<JSString>>(
            'command'.toJS,
            providerId.toJS,
            sessionId.toJS,
            command.toJS,
            jsonEncode(arguments).toJS,
          )
          .toDart;
      return response.toDart;
    } catch (error) {
      throw _mapError(
        providerId,
        'Browser media operation "$command" failed.',
        error,
      );
    }
  }

  static MediaError _mapError(
    String providerId,
    String fallback,
    Object error,
  ) {
    if (error is MediaError) return error.withProvider(providerId);
    final message = error.toString();
    final lower = message.toLowerCase();
    final code = lower.contains('permission') || lower.contains('notallowed')
        ? MediaErrorCode.permissionDenied
        : MediaErrorCode.nativeError;
    return MediaError(
      code: code,
      message: '$fallback $message',
      details: error,
      providerId: providerId,
    );
  }
}
