import 'agora_chat_engine.dart';
import 'agora_chat_engine_native.dart'
    if (dart.library.js_interop) 'agora_chat_engine_web.dart'
    as platform;

/// Builds the native Agora Chat engine or its locally bundled Web SDK driver.
Future<AgoraChatEngine> createDefaultAgoraChatEngine() =>
    platform.createPlatformAgoraChatEngine();
