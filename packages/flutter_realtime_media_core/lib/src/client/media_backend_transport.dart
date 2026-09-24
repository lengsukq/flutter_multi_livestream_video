class MediaBackendTransportResponse {
  const MediaBackendTransportResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;
}

class MediaBackendTransportException implements Exception {
  const MediaBackendTransportException(
    this.message, {
    this.cause,
    this.unsupportedPlatform = false,
  });

  final String message;
  final Object? cause;
  final bool unsupportedPlatform;

  @override
  String toString() => 'MediaBackendTransportException: $message';
}

/// Injectable transport used by the backend convenience layer.
///
/// Applications normally use the platform default. Supplying a transport is
/// useful for tests or for apps that already own a networking stack.
abstract interface class MediaBackendTransport {
  Future<MediaBackendTransportResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    String? body,
  });

  void close();
}
