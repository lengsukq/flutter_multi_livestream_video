/// Runtime platforms understood by the high-level realtime SDK.
///
/// Applications should not need to branch on this value. It is public for
/// diagnostics, tests, and custom driver registration.
enum RealtimeRuntimePlatform {
  web,
  android,
  ios,
  macos,
  windows,
  linux,
  unknown,
}

typedef RealtimePlatformResolver = RealtimeRuntimePlatform Function();
