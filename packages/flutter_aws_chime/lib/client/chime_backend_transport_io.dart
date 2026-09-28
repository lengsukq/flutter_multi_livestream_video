import 'dart:convert';
import 'dart:io';

import 'chime_backend_transport.dart';

ChimeBackendTransport createDefaultChimeBackendTransport() =>
    IoChimeBackendTransport();

class IoChimeBackendTransport implements ChimeBackendTransport {
  IoChimeBackendTransport({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;

  @override
  Future<ChimeBackendTransportResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    String? body,
  }) async {
    try {
      final request = await _httpClient.openUrl(method, uri);
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
      if (body != null) request.write(body);
      final response = await request.close();
      return ChimeBackendTransportResponse(
        statusCode: response.statusCode,
        body: await utf8.decodeStream(response),
      );
    } on IOException catch (error) {
      throw ChimeBackendTransportException(
        'Unable to complete the backend HTTP request.',
        cause: error,
      );
    }
  }

  @override
  void close() => _httpClient.close(force: true);
}
