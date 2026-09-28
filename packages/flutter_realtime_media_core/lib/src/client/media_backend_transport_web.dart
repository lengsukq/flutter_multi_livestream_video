import 'dart:convert';

import 'package:http/http.dart' as http;

import 'media_backend_transport.dart';

MediaBackendTransport createDefaultMediaBackendTransport() =>
    WebMediaBackendTransport();

/// Browser HTTP transport used by the backend convenience layer.
///
/// The browser enforces same-origin and CORS rules. Media backends used by a
/// web app must therefore allow the app's origin and be served over HTTPS when
/// the app is served over HTTPS.
class WebMediaBackendTransport implements MediaBackendTransport {
  WebMediaBackendTransport({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<MediaBackendTransportResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    String? body,
  }) async {
    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = body;
      final response = await _client.send(request);
      return MediaBackendTransportResponse(
        statusCode: response.statusCode,
        body: utf8.decode(await response.stream.toBytes()),
      );
    } catch (error) {
      throw MediaBackendTransportException(
        'Unable to complete the backend HTTP request from this browser.',
        cause: error,
      );
    }
  }

  @override
  void close() => _client.close();
}
