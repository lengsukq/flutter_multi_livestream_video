import 'chime_backend_transport.dart';
import 'chime_backend_transport_stub.dart'
    if (dart.library.io) 'chime_backend_transport_io.dart'
    as implementation;

ChimeBackendTransport createDefaultChimeBackendTransport() =>
    implementation.createDefaultChimeBackendTransport();
