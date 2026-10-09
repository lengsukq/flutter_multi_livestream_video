import 'bundled_web_script_stub.dart'
    if (dart.library.js_interop) 'bundled_web_script_web.dart'
    as platform;

Future<void> loadRealtimeBundledWebScript(String assetPath) =>
    platform.loadRealtimeBundledWebScript(assetPath);
