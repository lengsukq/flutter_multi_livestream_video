import 'chime_backend_transport.dart';

ChimeBackendTransport createDefaultChimeBackendTransport() =>
    _UnsupportedBackendTransport();

class _UnsupportedBackendTransport implements ChimeBackendTransport {
  @override
  Future<ChimeBackendTransportResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    String? body,
  }) => throw const ChimeBackendTransportException(
    'The default Chime backend HTTP transport is available on iOS and Android only.',
    unsupportedPlatform: true,
  );

  @override
  void close() {}
}
