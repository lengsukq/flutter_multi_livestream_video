import 'runtime_platform_stub.dart'
    if (dart.library.io) 'runtime_platform_io.dart'
    if (dart.library.js_interop) 'runtime_platform_web.dart'
    as implementation;

import 'runtime_platform_type.dart';

export 'runtime_platform_type.dart';

RealtimeRuntimePlatform resolveRealtimeRuntimePlatform() =>
    implementation.currentRealtimeRuntimePlatform();
