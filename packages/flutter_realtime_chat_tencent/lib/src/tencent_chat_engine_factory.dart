import 'tencent_chat_engine.dart';
import 'tencent_chat_engine_native.dart'
    if (dart.library.js_interop) 'tencent_chat_engine_web.dart'
    as platform;

Future<TencentChatEngine> createDefaultTencentChatEngine() =>
    platform.createPlatformTencentChatEngine();
