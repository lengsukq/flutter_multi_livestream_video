import 'media_backend_transport.dart';
import 'media_backend_transport_stub.dart'
    if (dart.library.io) 'media_backend_transport_io.dart'
    as implementation;

MediaBackendTransport createDefaultMediaBackendTransport() =>
    implementation.createDefaultMediaBackendTransport();
