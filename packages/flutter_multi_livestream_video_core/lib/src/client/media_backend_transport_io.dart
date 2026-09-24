import 'dart:convert';
import 'dart:io';

import 'media_backend_transport.dart';

MediaBackendTransport createDefaultMediaBackendTransport() =>
    IoMediaBackendTransport();

class IoMediaBackendTransport implements MediaBackendTransport {
  IoMediaBackendTransport({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;

  @override
  Future<MediaBackendTransportResponse> send({
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
      return MediaBackendTransportResponse(
        statusCode: response.statusCode,
        body: await utf8.decodeStream(response),
      );
    } on IOException catch (error) {
      throw MediaBackendTransportException(
        'Unable to complete the backend HTTP request.',
        cause: error,
      );
    }
  }

  @override
  void close() => _httpClient.close(force: true);
}
