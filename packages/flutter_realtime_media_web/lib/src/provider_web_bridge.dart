import 'dart:async';
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
      throw mapFailure(
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
      late final Map<String, dynamic> event;
      try {
        final decoded = jsonDecode(payload.toDart);
        if (decoded is! Map<String, dynamic>) {
          throw const RealtimeException(
            code: RealtimeErrorCode.invalidResponse,
            message: 'web.bridge.event.decode',
          );
        }
        event = decoded;
      } catch (error, stack) {
        event = {
          'type': 'error',
          'error': normalizeRealtimeException(
            error,
            domain: 'media.web',
            operation: 'bridge.event.decode',
            stackTrace: stack,
          ),
        };
      }
      handler(sessionId.toDart, event);
    }).toJS;
    _globalThis['__flutterMediaProviderOnEvent'] = callback;
    _listenerInstalled = true;
  }

  static JSObject get _bridge {
    if (!_globalThis.has('MediaProviderBridge')) {
      throw const RealtimeException(
        code: RealtimeErrorCode.unsupportedPlatform,
        message:
            'The locally bundled browser media SDK bridge has not been loaded.',
        details: {'reason': 'web-sdk-unavailable'},
      );
    }
    final bridge = _globalThis['MediaProviderBridge'] as JSObject;
    final version = bridge.getProperty<JSAny?>('bridgeVersion'.toJS)?.dartify();
    if (version != 1) {
      throw RealtimeException(
        code: RealtimeErrorCode.webSdkUnavailable,
        message: 'webBridge.versionMismatch',
        domain: 'media.web',
        operation: 'handshake',
        details: {'expectedVersion': 1, 'actualVersion': version},
        suggestedAction: 'reload-web-runtime',
      );
    }
    return bridge;
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
      throw mapFailure(
        providerId,
        'Unable to initialize the browser SDK.',
        error,
      );
    }
  }

  // Joining is a lifecycle operation. It cannot use bridge.command(), which
  // correctly rejects ordinary media commands before session.joined is true.
  static Future<void> join(
    String providerId,
    String sessionId, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    try {
      await _bridge
          .callMethod<JSPromise<JSAny?>>(
            'join'.toJS,
            providerId.toJS,
            sessionId.toJS,
          )
          .toDart
          .timeout(timeout);
    } catch (error, stack) {
      throw mapFailure(
        providerId,
        'media.web.join',
        error,
        operation: 'join',
        stackTrace: stack,
      );
    }
  }

  static Future<String> command(
    String providerId,
    String sessionId,
    String command, [
    Map<String, Object?> arguments = const {},
  ]) => _command(providerId, sessionId, command, arguments);

  static Future<void> leave(String providerId, String sessionId) async {
    try {
      await _bridge
          .callMethod<JSPromise<JSAny?>>(
            'leave'.toJS,
            providerId.toJS,
            sessionId.toJS,
          )
          .toDart;
    } catch (error) {
      throw mapFailure(providerId, 'Browser media leave failed.', error);
    }
  }

  static Future<void> dispose(String providerId, String sessionId) async {
    try {
      await _bridge
          .callMethod<JSPromise<JSAny?>>(
            'dispose'.toJS,
            providerId.toJS,
            sessionId.toJS,
          )
          .toDart;
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
        .whereType<Map<Object?, Object?>>()
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
    JSObject? element,
  }) async {
    try {
      await _bridge
          .callMethod<JSPromise<JSAny?>>(
            (element == null ? 'attachVideo' : 'attachVideoElement').toJS,
            providerId.toJS,
            sessionId.toJS,
            trackId.toJS,
            element ?? elementId.toJS,
          )
          .toDart;
    } catch (error, stack) {
      Error.throwWithStackTrace(
        normalizeRealtimeException(
          error,
          domain: 'media',
          operation: 'attachVideo',
          providerId: providerId,
          stackTrace: stack,
        ),
        stack,
      );
    }
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
      throw mapFailure(
        providerId,
        'Browser media operation "$command" failed.',
        error,
      );
    }
  }

  static RealtimeException mapFailure(
    String providerId,
    String fallback,
    Object error, {
    String? operation,
    StackTrace? stackTrace,
  }) {
    if (error is RealtimeException) return error.withProvider(providerId);
    final message = error.toString();
    final lower = message.toLowerCase();
    final code =
        error is TimeoutException ||
            lower.contains('timeout') ||
            lower.contains('timed out')
        ? RealtimeErrorCode.timeout
        : lower.contains('network') ||
              lower.contains('gateway_server') ||
              lower.contains('failed to fetch') ||
              lower.contains('connection_closed')
        ? RealtimeErrorCode.network
        : lower.contains('permission') || lower.contains('notallowed')
        ? RealtimeErrorCode.permissionDenied
        : RealtimeErrorCode.providerError;
    return normalizeRealtimeException(
      RealtimeException(
        code: code,
        message: fallback,
        details: error,
        cause: error,
        domain: 'media.web',
        operation: operation,
        stackTrace: stackTrace,
        providerId: providerId,
      ),
    );
  }
}
