import 'media_backend_transport.dart';

/// Web (and any other unsupported platform) fallback.
///
/// The generic SDK targets devices; browsers fail loudly instead of silently
/// attempting a backend call with no HTTP stack.
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
