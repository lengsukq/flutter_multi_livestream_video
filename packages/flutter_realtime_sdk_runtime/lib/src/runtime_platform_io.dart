import 'dart:io';

import 'runtime_platform_type.dart';

RealtimeRuntimePlatform currentRealtimeRuntimePlatform() {
  if (Platform.isAndroid) return RealtimeRuntimePlatform.android;
  if (Platform.isIOS) return RealtimeRuntimePlatform.ios;
  if (Platform.isMacOS) return RealtimeRuntimePlatform.macos;
  if (Platform.isWindows) return RealtimeRuntimePlatform.windows;
  if (Platform.isLinux) return RealtimeRuntimePlatform.linux;
  return RealtimeRuntimePlatform.unknown;
}
