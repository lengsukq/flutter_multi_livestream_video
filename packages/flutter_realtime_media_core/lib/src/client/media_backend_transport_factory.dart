import 'media_backend_transport.dart';
import 'media_backend_transport_stub.dart'
    if (dart.library.io) 'media_backend_transport_io.dart'
    if (dart.library.js_interop) 'media_backend_transport_web.dart'
    as implementation;

MediaBackendTransport createDefaultMediaBackendTransport() =>
    implementation.createDefaultMediaBackendTransport();
