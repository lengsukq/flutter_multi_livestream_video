import 'media_backend_transport.dart';

/// Unsupported-platform fallback.
///
/// Platforms without a compatible HTTP implementation fail loudly instead of
/// attempting a backend call with no transport.
MediaBackendTransport createDefaultMediaBackendTransport() =>
    UnsupportedMediaBackendTransport();

class UnsupportedMediaBackendTransport implements MediaBackendTransport {
  @override
  Future<MediaBackendTransportResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    String? body,
  }) async {
    throw const MediaBackendTransportException(
      'The media backend layer is available on iOS and Android only.',
      unsupportedPlatform: true,
    );
  }

  @override
  void close() {}
}
