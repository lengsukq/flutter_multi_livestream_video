import 'default_driver_catalog_stub.dart'
    if (dart.library.io) 'default_driver_catalog_native.dart'
    if (dart.library.js_interop) 'default_driver_catalog_web.dart'
    as implementation;

import 'provider_driver.dart';

/// Built-in provider/platform drivers shipped with flutter_realtime_sdk.
///
/// The selected implementation is compile-time safe for Web vs native while
/// the returned descriptors still perform runtime Android/iOS/Desktop
/// selection inside the SDK.
List<RealtimeProviderDriver> createDefaultRealtimeDrivers() =>
    implementation.createDefaultRealtimeDrivers();
