import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../model/chat_error.dart';
import 'chat_backend_config.dart';

const chatBackendContractHeader = 'X-Realtime-Chat-Contract';
const chatBackendContractVersion = 1;

class ChatBackendJoinResponse {
  const ChatBackendJoinResponse({
    required this.providerId,
    required this.roomCode,
    required this.json,
  });

  final String providerId;
  final String roomCode;
  final Map<String, dynamic> json;
}

class ChatBackendClient {
  ChatBackendClient(this.config, {http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client(),
      _ownsHttpClient = httpClient == null;

  final ChatBackendConfig config;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  bool _disposed = false;

  Future<ChatBackendJoinResponse> issueToken({
    required String roomCode,
    required String participantId,
    String? participantCredential,
  }) async {
    final code = _required(roomCode, 'roomCode');
    final data = await _request(
      'POST',
      '/rooms/${Uri.encodeComponent(code)}/chat/token',
      body: {
        'participantId': _required(participantId, 'participantId'),
        if (participantCredential != null &&
            participantCredential.trim().isNotEmpty)
          'participantCredential': participantCredential.trim(),
      },
    );
    final providerId =
        data['chatProvider']?.toString().trim().toLowerCase() ??
        data['provider']?.toString().trim().toLowerCase() ??
        '';
    if (providerId.isEmpty) {
      throw const ChatError(
        code: ChatErrorCode.invalidJoinInfo,
        message: 'Backend chat response is missing chatProvider.',
      );
    }
    final returnedCode = data['roomCode']?.toString().trim() ?? '';
    return ChatBackendJoinResponse(
      providerId: providerId,
      roomCode: returnedCode.isEmpty ? code : returnedCode,
      json: data,
    );
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    if (_disposed) {
      throw const ChatError(
        code: ChatErrorCode.invalidState,
        message: 'The chat backend client has been disposed.',
      );
    }
    try {
      final request = http.Request(method, _uri(path));
      request.headers.addAll(await _headers());
      if (body != null) request.body = jsonEncode(body);
      final streamed = await _httpClient
          .send(request)
          .timeout(config.requestTimeout);
      final response = await http.Response.fromStream(streamed);
      final decoded = response.body.trim().isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _httpError(response.statusCode, decoded);
      }
      if (decoded is! Map) {
        throw const ChatError(
          code: ChatErrorCode.invalidJoinInfo,
          message: 'Chat backend returned a non-object JSON response.',
        );
      }
      final data = Map<String, dynamic>.from(decoded);
      final version = data['contractVersion'];
      if (version != null &&
          version.toString() != '$chatBackendContractVersion') {
        throw ChatError(
          code: ChatErrorCode.invalidJoinInfo,
          message: 'Unsupported chat contract version: $version.',
        );
      }
      return data;
    } on ChatError {
      rethrow;
    } on TimeoutException catch (error) {
      throw ChatError(
        code: ChatErrorCode.timeout,
        message: 'Chat backend request timed out.',
        details: error,
      );
    } on FormatException catch (error) {
      throw ChatError(
        code: ChatErrorCode.invalidJoinInfo,
        message: 'Chat backend returned invalid JSON.',
        details: error,
      );
    } catch (error) {
      throw ChatError(
        code: ChatErrorCode.network,
        message: 'Unable to complete chat backend request.',
        details: error,
      );
    }
  }

  Future<Map<String, String>> _headers() async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      chatBackendContractHeader: '$chatBackendContractVersion',
    };
    final custom = await config.headersProvider?.call();
    if (custom != null) headers.addAll(custom);
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

  ChatError _httpError(int statusCode, Object? body) {
    String? backendCode;
    String? message;
    Object? details;
    if (body is Map) {
      final error = body['error'];
      if (error is Map) {
        backendCode = error['code']?.toString();
        message = error['message']?.toString();
        details = error['details'];
      }
    }
    final code = switch (backendCode) {
      'unauthorized' => ChatErrorCode.unauthorized,
      'forbidden' => ChatErrorCode.forbidden,
      'room-not-found' => ChatErrorCode.roomNotFound,
      'unsupported-provider' => ChatErrorCode.providerNotRegistered,
      'provider-not-configured' => ChatErrorCode.providerNotConfigured,
      _ when statusCode == 400 => ChatErrorCode.invalidArgument,
      _ when statusCode == 401 => ChatErrorCode.unauthorized,
      _ when statusCode == 403 => ChatErrorCode.forbidden,
      _ when statusCode == 404 => ChatErrorCode.roomNotFound,
      _ when statusCode == 503 => ChatErrorCode.providerNotConfigured,
      _ when statusCode >= 500 => ChatErrorCode.serverError,
      _ => ChatErrorCode.unknown,
    };
    return ChatError(
      code: code,
      message: message ?? 'Chat backend request failed with HTTP $statusCode.',
      details: details ?? body,
    );
  }

  String _required(String value, String name) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ChatError(
        code: ChatErrorCode.invalidArgument,
        message: '$name must not be empty.',
      );
    }
    return normalized;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_ownsHttpClient) _httpClient.close();
  }
}
