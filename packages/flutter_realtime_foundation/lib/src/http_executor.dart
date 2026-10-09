import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'failure.dart';

typedef JsonTransport =
    Future<(int, String)> Function(
      Map<String, String> headers,
      String? body,
      Future<void> abort,
    );

/// One deadline covers credentials, transport, body streaming and JSON decoding.
class RealtimeHttpExecutor {
  RealtimeHttpExecutor({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;
  final http.Client _client;
  final bool _ownsClient;
  final Set<Completer<void>> _requests = {};
  bool _closed = false;

  Future<Map<String, dynamic>> request({
    required String method,
    required Uri uri,
    required Duration timeout,
    required String domain,
    FutureOr<Map<String, String>> Function()? headers,
    Map<String, Object?>? body,
    JsonTransport? transport,
  }) async {
    if (_closed) {
      throw const RealtimeException(
        code: RealtimeErrorCode.invalidState,
        message: 'HTTP executor is closed.',
      );
    }
    final abort = Completer<void>();
    _requests.add(abort);
    final operation = '$method ${uri.path}';
    try {
      return await (() async {
        final requestHeaders = await headers?.call() ?? {};
        if (abort.isCompleted || _closed) {
          throw const RealtimeException(
            code: RealtimeErrorCode.cancelled,
            message: 'Request cancelled.',
          );
        }
        final encoded = body == null ? null : jsonEncode(body);
        final (status, text) = transport == null
            ? await _send(method, uri, requestHeaders, encoded, abort.future)
            : await transport(requestHeaders, encoded, abort.future);
        if (abort.isCompleted || _closed) {
          throw const RealtimeException(
            code: RealtimeErrorCode.cancelled,
            message: 'Request cancelled.',
          );
        }
        Object? decoded;
        try {
          decoded = text.trim().isEmpty ? null : jsonDecode(text);
        } on FormatException {
          if (status >= 200 && status < 300) {
            throw RealtimeException(
              code: RealtimeErrorCode.invalidResponse,
              message: 'Backend returned invalid JSON.',
              domain: domain,
              operation: operation,
              statusCode: status,
            );
          }
        }
        if (status < 200 || status >= 300) {
          final rawError = decoded is Map ? decoded['error'] : null;
          final backendCode = rawError is Map ? rawError['code'] : rawError;
          final code = switch (backendCode) {
            'unauthorized' => RealtimeErrorCode.unauthorized,
            'forbidden' => RealtimeErrorCode.forbidden,
            'room-not-found' => RealtimeErrorCode.roomNotFound,
            'participant-not-found' => RealtimeErrorCode.participantNotFound,
            'room-exists' => RealtimeErrorCode.roomConflict,
            'bad-room-code' => RealtimeErrorCode.invalidArgument,
            'unsupported-provider' => RealtimeErrorCode.providerNotRegistered,
            'unsupported-feature' => RealtimeErrorCode.unsupportedFeature,
            'provider-not-configured' =>
              RealtimeErrorCode.providerNotConfigured,
            _ => switch (status) {
              400 => RealtimeErrorCode.invalidArgument,
              401 => RealtimeErrorCode.unauthorized,
              403 => RealtimeErrorCode.forbidden,
              404 => RealtimeErrorCode.roomNotFound,
              409 => RealtimeErrorCode.roomConflict,
              _ when status >= 500 => RealtimeErrorCode.serverError,
              _ => RealtimeErrorCode.unknown,
            },
          };
          throw RealtimeException(
            code: code,
            message: 'Backend request failed (HTTP $status).',
            domain: domain,
            operation: operation,
            statusCode: status,
            recoverable: code == RealtimeErrorCode.serverError,
            details: {
              'backendCode': backendCode is String ? backendCode : null,
            },
          );
        }
        if (decoded == null) return <String, dynamic>{};
        if (decoded is! Map<String, dynamic>) {
          throw RealtimeException(
            code: RealtimeErrorCode.invalidResponse,
            message: 'Backend returned a non-object JSON response.',
            domain: domain,
            operation: operation,
            statusCode: status,
          );
        }
        return decoded;
      })().timeout(
        timeout,
        onTimeout: () {
          if (!abort.isCompleted) abort.complete();
          throw RealtimeException(
            code: RealtimeErrorCode.timeout,
            message: 'Backend request timed out.',
            domain: domain,
            operation: operation,
            recoverable: true,
          );
        },
      );
    } on RealtimeException {
      rethrow;
    } catch (error, stack) {
      throw RealtimeException(
        code: abort.isCompleted
            ? RealtimeErrorCode.cancelled
            : RealtimeErrorCode.network,
        message: 'Unable to complete backend request.',
        domain: domain,
        operation: operation,
        cause: error,
        stackTrace: stack,
        recoverable: !abort.isCompleted,
      );
    } finally {
      _requests.remove(abort);
    }
  }

  Future<(int, String)> _send(
    String method,
    Uri uri,
    Map<String, String> headers,
    String? body,
    Future<void> abort,
  ) async {
    final request = http.AbortableRequest(method, uri, abortTrigger: abort)
      ..headers.addAll(headers);
    if (body != null) request.body = body;
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    return (response.statusCode, response.body);
  }

  void close() {
    if (_closed) return;
    _closed = true;
    for (final request in _requests) {
      if (!request.isCompleted) request.complete();
    }
    if (_ownsClient) _client.close();
  }
}
