import 'dart:async';
import 'dart:convert';

import '../model/media_role.dart';
import 'media_backend_config.dart';
import 'media_backend_error.dart';
import 'media_backend_transport.dart';
import 'media_backend_transport_factory.dart';

/// Contract version implemented by this client.
const int mediaBackendContractVersion = 1;

/// Request header carrying the contract version.
const String mediaBackendContractHeader = 'X-Media-Backend-Contract';

/// Provider id assumed when a backend response omits `provider`.
///
/// Chime backends written against the original v1 contract send `meeting` and
/// `attendee` without a provider field; treating those as `chime` keeps them
/// working unchanged.
const String defaultMediaProviderId = 'chime';

/// Raw join response returned by the backend.
///
/// The provider payload is kept as JSON so the matching adapter can parse it;
/// the core layer only interprets the fields every provider shares.
class MediaRoomJoinResponse {
  const MediaRoomJoinResponse({
    required this.roomCode,
    required this.providerId,
    required this.role,
    required this.json,
  });

  final String roomCode;
  final String providerId;
  final MediaRole role;

  /// Full decoded response body, passed to `MediaSessionFactory.parseJoinInfo`.
  final Map<String, dynamic> json;

  @override
  String toString() =>
      'MediaRoomJoinResponse($providerId, room: $roomCode, '
      'role: ${role.wireName})';
}

/// HTTP implementation of the provider-neutral backend contract.
///
/// See `MEDIA_BACKEND_CONTRACT.md`. A compatible backend may be written in any
/// stack; it only has to implement the documented HTTP endpoints.
class MediaBackendClient {
  MediaBackendClient(this.config, {MediaBackendTransport? transport})
    : _transport = transport ?? createDefaultMediaBackendTransport(),
      _ownsTransport = transport == null;

  final MediaBackendConfig config;
  final MediaBackendTransport _transport;
  final bool _ownsTransport;
  bool _disposed = false;

  /// Whether this client owns (and will close) its transport.
  bool get ownsTransport => _ownsTransport;

  Future<MediaRoomJoinResponse> createRoom({
    required MediaRole role,
    String? roomCode,
    required String nickname,
    String? deviceId,
  }) async {
    final body = <String, Object?>{
      'nickname': _required(nickname, 'nickname'),
      'role': role.wireName,
    };
    final normalizedDeviceId = deviceId?.trim();
    if (normalizedDeviceId != null && normalizedDeviceId.isNotEmpty) {
      body['deviceId'] = normalizedDeviceId;
    }
    final normalizedCode = roomCode?.trim();
    if (normalizedCode != null && normalizedCode.isNotEmpty) {
      body['roomCode'] = normalizedCode;
    }
    final data = await _post('/rooms', body);
    return _parseJoinResponse(data, role: role);
  }

  Future<MediaRoomJoinResponse> joinRoom({
    required MediaRole role,
    required String roomCode,
    required String nickname,
    String? deviceId,
  }) async {
    final code = _required(roomCode, 'roomCode');
    final data = await _post('/rooms/${Uri.encodeComponent(code)}/join', {
      'userId': _required(nickname, 'nickname'),
      'role': role.wireName,
      if (deviceId != null && deviceId.trim().isNotEmpty)
        'deviceId': deviceId.trim(),
    });
    return _parseJoinResponse(data, role: role, fallbackRoomCode: code);
  }

  /// Requests replacement provider credentials for an existing participant.
  ///
  /// The backend must preserve the room, provider, participant id, and role.
  Future<MediaRoomJoinResponse> refreshCredentials({
    required String roomCode,
    required String participantId,
    required MediaRole role,
  }) async {
    final code = _required(roomCode, 'roomCode');
    final data =
        await _post('/rooms/${Uri.encodeComponent(code)}/credentials/refresh', {
          'participantId': _required(participantId, 'participantId'),
          'role': role.wireName,
        });
    return _parseJoinResponse(data, role: role, fallbackRoomCode: code);
  }

  Future<void> heartbeat(String roomCode) async {
    final code = _required(roomCode, 'roomCode');
    await _post('/rooms/${Uri.encodeComponent(code)}/heartbeat', const {});
  }

  Future<void> leave(String roomCode, {String? participantId}) async {
    final code = _required(roomCode, 'roomCode');
    await _post('/rooms/${Uri.encodeComponent(code)}/leave', {
      if (participantId != null && participantId.trim().isNotEmpty)
        'participantId': participantId.trim(),
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

  Future<Map<String, dynamic>> _post(String path, Map<String, Object?> body) =>
      _request('POST', path, body: body);

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    if (_disposed) {
      throw const MediaBackendError(
        code: MediaBackendErrorCode.invalidArgument,
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
      } on MediaBackendError {
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
        throw MediaBackendError(
          code: MediaBackendErrorCode.invalidResponse,
          message: 'Backend returned a non-object JSON response.',
          statusCode: response.statusCode,
          details: decoded,
        );
      }
      final data = Map<String, dynamic>.from(decoded);
      _validateContractVersion(data);
      return data;
    } on MediaBackendError {
      rethrow;
    } on TimeoutException catch (error) {
      throw MediaBackendError(
        code: MediaBackendErrorCode.timeout,
        message: 'Backend request timed out.',
        details: error,
      );
    } on MediaBackendTransportException catch (error) {
      throw MediaBackendError(
        code: error.unsupportedPlatform
            ? MediaBackendErrorCode.unsupportedPlatform
            : MediaBackendErrorCode.network,
        message: error.message,
        details: error.cause,
      );
    } catch (error) {
      throw MediaBackendError(
        code: MediaBackendErrorCode.unknown,
        message: 'Unable to prepare or complete the backend request.',
        details: error,
      );
    }
  }

  Future<MediaBackendTransportResponse> _sendTransportRequest(
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
    headers[mediaBackendContractHeader] = '$mediaBackendContractVersion';
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
      throw MediaBackendError(
        code: MediaBackendErrorCode.invalidResponse,
        message: 'Backend returned invalid JSON.',
        details: error,
      );
    }
  }

  void _validateContractVersion(Map<String, dynamic> data) {
    final value = data['contractVersion'];
    if (value == null) return;
    final parsed = value is num
        ? value.toInt()
        : int.tryParse(value.toString());
    if (parsed != mediaBackendContractVersion) {
      throw MediaBackendError(
        code: MediaBackendErrorCode.invalidResponse,
        message:
            'Backend response uses unsupported contract version '
            '${value.toString()}.',
        details: value,
      );
    }
  }

  MediaRoomJoinResponse _parseJoinResponse(
    Map<String, dynamic> data, {
    required MediaRole role,
    String? fallbackRoomCode,
  }) {
    final roomCode = data['roomCode']?.toString().trim();
    final resolvedRoomCode = roomCode == null || roomCode.isEmpty
        ? fallbackRoomCode?.trim()
        : roomCode;
    if (resolvedRoomCode == null || resolvedRoomCode.isEmpty) {
      throw const MediaBackendError(
        code: MediaBackendErrorCode.invalidResponse,
        message: 'Backend response is missing roomCode.',
      );
    }
    final providerId = data['provider']?.toString().trim().toLowerCase() ?? '';
    final resolvedRole = MediaRole.tryParse(data['role']) ?? role;
    return MediaRoomJoinResponse(
      roomCode: resolvedRoomCode,
      providerId: providerId.isEmpty ? defaultMediaProviderId : providerId,
      role: resolvedRole,
      json: data,
    );
  }

  MediaBackendError _httpError(int statusCode, Object? body) {
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
      'unauthorized' => MediaBackendErrorCode.unauthorized,
      'forbidden' => MediaBackendErrorCode.forbidden,
      'room-not-found' => MediaBackendErrorCode.roomNotFound,
      'room-exists' => MediaBackendErrorCode.roomConflict,
      'bad-room-code' => MediaBackendErrorCode.invalidRoomCode,
      'unsupported-provider' => MediaBackendErrorCode.unsupportedProvider,
      'provider-not-configured' => MediaBackendErrorCode.providerNotConfigured,
      _ when statusCode == 400 => MediaBackendErrorCode.invalidArgument,
      _ when statusCode == 401 => MediaBackendErrorCode.unauthorized,
      _ when statusCode == 403 => MediaBackendErrorCode.forbidden,
      _ when statusCode == 404 => MediaBackendErrorCode.roomNotFound,
      _ when statusCode == 409 => MediaBackendErrorCode.roomConflict,
      _ when statusCode == 503 => MediaBackendErrorCode.providerNotConfigured,
      _ when statusCode >= 500 => MediaBackendErrorCode.serverError,
      _ => MediaBackendErrorCode.unknown,
    };
    return MediaBackendError(
      code: code,
      message: message ?? 'Backend request failed with HTTP $statusCode.',
      statusCode: statusCode,
      details: details ?? body,
    );
  }

  String _required(String value, String name) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw MediaBackendError(
        code: MediaBackendErrorCode.invalidArgument,
        message: '$name must not be empty.',
      );
    }
    return normalized;
  }
}
