import 'provider_adapters_model.dart';
import 'provider_adapters_stub.dart'
    if (dart.library.io) 'provider_adapters_native.dart'
    if (dart.library.js_interop) 'provider_adapters_web.dart'
    as implementation;

export 'provider_adapters_model.dart';

ProviderAdapters createProviderAdapters() =>
    implementation.createProviderAdapters();
