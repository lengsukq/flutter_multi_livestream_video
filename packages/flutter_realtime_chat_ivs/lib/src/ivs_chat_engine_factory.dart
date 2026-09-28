import 'ivs_chat_engine.dart';
import 'ivs_chat_engine_native.dart'
    if (dart.library.js_interop) 'ivs_chat_engine_web.dart'
    as platform;

/// Builds the IVS Chat engine for the current platform.
///
/// Native platforms use the platform channel implementation. Web uses the
/// locally bundled Amazon IVS Chat Messaging JavaScript SDK.
Future<IvsChatEngine> createDefaultIvsChatEngine() =>
    platform.createPlatformIvsChatEngine();
