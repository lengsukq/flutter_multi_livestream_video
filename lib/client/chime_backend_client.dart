import 'dart:async';
import 'dart:convert';

import '../models/chime_backend_exception.dart';
import '../models/join_info.model.dart';
import 'chime_backend_transport.dart';
import 'chime_backend_transport_factory.dart';
import 'chime_client_config.dart';

const int chimeBackendContractVersion = 1;
const String chimeBackendContractHeader = 'X-Chime-Backend-Contract';

class ChimeRoomJoinResponse {
  const ChimeRoomJoinResponse({
    required this.roomCode,
    required this.joinInfo,
  });

  final String roomCode;
  final JoinInfo joinInfo;
}

/// HTTP implementation of the language-neutral Chime backend contract.
///
/// A compatible backend may be written in Java, Python, Node.js, Go, .NET, or
/// any other stack. It only needs to implement the documented HTTP contract.
class ChimeBackendClient {
  ChimeBackendClient(
    this.config, {
    ChimeBackendTransport? transport,
  }) : _transport = transport ?? createDefaultChimeBackendTransport(),
       _ownsTransport = transport == null;

  final ChimeClientConfig config;
  final ChimeBackendTransport _transport;
  final bool _ownsTransport;
  bool _disposed = false;

  Future<ChimeRoomJoinResponse> createRoom({
    String? roomCode,
    required String nickname,
  }) async {
    final body = <String, Object?>{'nickname': _required(nickname, 'nickname')};
    final normalizedCode = roomCode?.trim();
    if (normalizedCode != null && normalizedCode.isNotEmpty) {
      body['roomCode'] = normalizedCode;
    }
    final data = await _post('/rooms', body);
    return _parseJoinResponse(data);
  }

  Future<ChimeRoomJoinResponse> joinRoom({
    required String roomCode,
    required String nickname,
  }) async {
    final code = _required(roomCode, 'roomCode');
    final data = await _post(
      '/rooms/${Uri.encodeComponent(code)}/join',
      {'userId': _required(nickname, 'nickname')},
    );
    return _parseJoinResponse(data, fallbackRoomCode: code);
  }

  Future<void> heartbeat(String roomCode) async {
    final code = _required(roomCode, 'roomCode');
    await _post('/rooms/${Uri.encodeComponent(code)}/heartbeat', const {});
  }

  Future<void> leave(String roomCode, {String? attendeeId}) async {
    final code = _required(roomCode, 'roomCode');
    await _post('/rooms/${Uri.encodeComponent(code)}/leave', {
      if (attendeeId != null && attendeeId.trim().isNotEmpty)
        'attendeeId': attendeeId.trim(),
    });
  }

  Future<void> closeRoom(String roomCode) async {
    final code = _required(roomCode, 'roomCode');
    await _request('DELETE', '/rooms/${Uri.encodeComponent(code)}');
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_ownsTransport) _transport.close();
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, Object?> body,
  ) => _request('POST', path, body: body);

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    if (_disposed) {
      throw const ChimeBackendException(
        code: ChimeBackendErrorCode.invalidArgument,
        message: 'The backend client has been disposed.',
      );
    }

    try {
      final response = await _sendTransportRequest(
        method,
        path,
        body,
      ).timeout(config.requestTimeout);
      Object? decoded;
      try {
        decoded = _decode(response.body);
      } on ChimeBackendException {
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw _httpError(response.statusCode, response.body);
        }
        rethrow;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _httpError(response.statusCode, decoded);
      }
      if (decoded == null) return const {};
      if (decoded is! Map) {
        throw ChimeBackendException(
          code: ChimeBackendErrorCode.invalidResponse,
          message: 'Backend returned a non-object JSON response.',
          statusCode: response.statusCode,
          details: decoded,
        );
      }
      final data = Map<String, dynamic>.from(decoded);
      _validateContractVersion(data);
      return data;
    } on ChimeBackendException {
      rethrow;
    } on TimeoutException catch (error) {
      throw ChimeBackendException(
        code: ChimeBackendErrorCode.timeout,
        message: 'Backend request timed out.',
        details: error,
      );
    } on ChimeBackendTransportException catch (error) {
      throw ChimeBackendException(
        code: error.unsupportedPlatform
            ? ChimeBackendErrorCode.unsupportedPlatform
            : ChimeBackendErrorCode.network,
        message: error.message,
        details: error.cause,
      );
    } catch (error) {
      throw ChimeBackendException(
        code: ChimeBackendErrorCode.unknown,
        message: 'Unable to prepare or complete the Chime backend request.',
        details: error,
      );
    }
  }

  Future<ChimeBackendTransportResponse> _sendTransportRequest(
    String method,
    String path,
    Map<String, Object?>? body,
  ) async => _transport.send(
    method: method,
    uri: _uri(path),
    headers: await _headers(),
    body: body == null ? null : jsonEncode(body),
  );

  Future<Map<String, String>> _headers() async {
    final headers = <String, String>{};
    final custom = await config.headersProvider?.call();
    if (custom != null) headers.addAll(custom);
    headers['Accept'] = 'application/json';
    headers['Content-Type'] = 'application/json';
    headers[chimeBackendContractHeader] = '$chimeBackendContractVersion';
    final token = (await config.tokenProvider?.call())?.trim();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Uri _uri(String path) {
    final base = config.backendUrl.toString().replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$base$path');
  }

  Object? _decode(String body) {
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException catch (error) {
      throw ChimeBackendException(
        code: ChimeBackendErrorCode.invalidResponse,
        message: 'Backend returned invalid JSON.',
        details: error,
      );
    }
  }

  void _validateContractVersion(Map<String, dynamic> data) {
    final value = data['contractVersion'];
    if (value == null) return;
    final parsed = value is num ? value.toInt() : int.tryParse(value.toString());
    if (parsed != chimeBackendContractVersion) {
      throw ChimeBackendException(
        code: ChimeBackendErrorCode.invalidResponse,
        message:
            'Backend response uses unsupported contract version ${value.toString()}.',
        details: value,
      );
    }
  }

  ChimeRoomJoinResponse _parseJoinResponse(
    Map<String, dynamic> data, {
    String? fallbackRoomCode,
  }) {
    final roomCode = data['roomCode']?.toString().trim();
    try {
      final joinInfo = JoinInfo.fromJson(data);
      joinInfo.validate();
      final resolvedRoomCode = roomCode == null || roomCode.isEmpty
          ? fallbackRoomCode?.trim()
          : roomCode;
      if (resolvedRoomCode == null || resolvedRoomCode.isEmpty) {
        throw const FormatException('Backend response is missing roomCode.');
      }
      return ChimeRoomJoinResponse(
        roomCode: resolvedRoomCode,
        joinInfo: joinInfo,
      );
    } on FormatException catch (error) {
      throw ChimeBackendException(
        code: ChimeBackendErrorCode.invalidResponse,
        message: 'Backend response is missing Chime join information.',
        details: error.message,
      );
    }
  }

  ChimeBackendException _httpError(int statusCode, Object? body) {
    String? backendCode;
    String? message;
    Object? details;
    if (body is Map) {
      final error = body['error'];
      if (error is Map) {
        backendCode = error['code']?.toString();
        message = error['message']?.toString();
        details = error['details'];
      } else {
        backendCode = error?.toString();
        message = body['message']?.toString() ?? body['hint']?.toString();
        details = body;
      }
    }
    final code = switch (backendCode) {
      'unauthorized' => ChimeBackendErrorCode.unauthorized,
      'forbidden' => ChimeBackendErrorCode.forbidden,
      'room-not-found' => ChimeBackendErrorCode.roomNotFound,
      'room-exists' => ChimeBackendErrorCode.roomConflict,
      'bad-room-code' => ChimeBackendErrorCode.invalidRoomCode,
      _ when statusCode == 401 => ChimeBackendErrorCode.unauthorized,
      _ when statusCode == 403 => ChimeBackendErrorCode.forbidden,
      _ when statusCode == 404 => ChimeBackendErrorCode.roomNotFound,
      _ when statusCode == 409 => ChimeBackendErrorCode.roomConflict,
      _ when statusCode >= 500 => ChimeBackendErrorCode.serverError,
      _ => ChimeBackendErrorCode.unknown,
    };
    return ChimeBackendException(
      code: code,
      message: message ?? 'Backend request failed with HTTP $statusCode.',
      statusCode: statusCode,
      details: details ?? body,
    );
  }

  String _required(String value, String name) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ChimeBackendException(
        code: ChimeBackendErrorCode.invalidArgument,
        message: '$name must not be empty.',
      );
    }
    return normalized;
  }
}
