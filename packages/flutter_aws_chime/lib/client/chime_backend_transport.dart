class ChimeBackendTransportResponse {
  const ChimeBackendTransportResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;
}

class ChimeBackendTransportException implements Exception {
  const ChimeBackendTransportException(
    this.message, {
    this.cause,
    this.unsupportedPlatform = false,
  });

  final String message;
  final Object? cause;
  final bool unsupportedPlatform;

  @override
  String toString() => 'ChimeBackendTransportException: $message';
}

/// Injectable transport used by the optional backend convenience layer.
///
/// Applications normally use the platform default. Supplying a transport is
/// useful for tests or applications with an existing networking stack.
abstract interface class ChimeBackendTransport {
  Future<ChimeBackendTransportResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    String? body,
  });

  void close();
}
