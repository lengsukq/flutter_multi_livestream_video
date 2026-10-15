# Flutter Realtime SDK

**English** · [简体中文](README.zh-CN.md)

One Flutter package for provider-neutral meetings, live streams, chat, optional
UI, and classroom/live interaction presets. Media and product chat providers
can be selected independently through explicit runtime registration.

**Release: `@VERSION@` (preview).** Windows/Linux builds, physical-device vendor
calls, long-running sessions, and cross-vendor coexistence are not yet fully
verified. Platform registration does not imply every provider supports that
platform. See the [capability matrix](https://github.com/lengsukq/flutter_multi_livestream_video/blob/main/doc/SDK_CAPABILITY_MATRIX.zh-CN.md).

## Installation

Requires Flutter 3.47 or later and Dart 3.12 or later. The combined native
package requires Android API 28+, iOS 15+, and macOS 12+.

Add:

```yaml
dependencies:
  flutter_realtime_sdk: ^@VERSION@
```

All SDK APIs below use the same public import:

```dart
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';

final realtime = Realtime(
  backendUrl: 'https://your-backend.example',
  providers: [createLivekitProvider()],
  services: const RealtimeRoomServices(
    videoEffectsFactory: DefaultRealtimeVideoEffects.new,
  ),
  featurePlugins: const [ClassroomPreset(), LivePreset()],
);

final connection = await realtime.open(
  RealtimeRequest.join(
    type: RealtimeExperience.meeting,
    roomCode: '123456',
    user: const RealtimeUser(id: 'user-1', name: 'Alice'),
  ),
);
final room = connection.mediaRoom!;
// Optional UI: RealtimeRoomView(room: room).
// In the application's leave/logout flow: await connection.dispose();
```

### Built-in UI in dev.4

The Demo displays these SDK pages directly: `RealtimeRoomView` (selects the
meeting/live page from the room), `RealtimeMeetingPage`, `RealtimeLivePage`,
`RealtimeChatPage`, and `RealtimePreJoinPage`. Customize room presentation
with `RealtimeRoomViewConfig`; pre-join uses `RealtimePreJoinEnter` and starts
with the microphone and camera off. The host owns navigation and explicitly
disposes its connection when leaving.

This preview removes the older `MediaRoomView`, `MediaPreJoinPage`,
`RealtimeChatView`, `RealtimeComposableRoomTemplate`,
`RealtimeComposablePreJoinTemplate`, and `ChatDefaultPage` APIs.
Replace `MediaRoomViewConfig` with `RealtimeRoomViewConfig` when upgrading.
Reusable controls and Headless APIs remain available.

### Headless virtual backgrounds and camera publication

If your app offers background effects, enable `videoEffectsFactory` as above.
Use `room.setCameraEnabled` rather than calling
`room.media.session.setVideoEnabled` directly. The SDK synchronizes camera
publication with its processed-video source and serializes it with
`setBackgroundEffect`, even if the camera was initially off.

```dart
// Camera is off; the selected effect remains prepared, but not capturing.
await room.setBackgroundEffect(const MediaBackgroundEffect.blur());

// Starts the already attached processed source before publishing the camera.
await room.setCameraEnabled(true);

// Change effects and close the camera in any sequence.
await room.setBackgroundEffect(const MediaBackgroundEffect.none());
await room.setCameraEnabled(false);
```

Only call the effect operations when `room.backgroundCapabilities` reports
support. Blur/image replacement depends on the platform, provider, and host
camera permissions. If effects initialization fails, handle the exception and
do not silently publish unprocessed video as a fallback.

Provide a backend implementing the provisioning/control contracts, or use
`RealtimeSource.credentials(...)` with your own short-lived credential service.
The repository's Demo Server is a reference implementation. Never include
vendor secrets or cloud access keys in a client application. Classroom/live
presets require trusted backend state and permission enforcement.

## iOS setup

Use iOS 15+ and keep Flutter's Swift Package Manager support enabled (the
default in the required Flutter version). The combined plugin uses CocoaPods
for ARTC/Chime and its own bridges; some third-party plugins use SwiftPM.

IVS Broadcast 1.47.0 and IVS Chat 1.0.1 are fetched from AWS's official HTTPS
archives at `pod install` time and checked against the SHA-256 values in
`ios/vendor_frameworks.json`. Vendor binaries are **not** redistributed in
the Pub archive. The installer reuses compatible local SwiftPM archives;
a fresh installation needs access to the official AWS endpoints. A corrupt
archive fails installation instead of silently selecting another SDK version.

Set `platform :ios, '15.0'` in `ios/Podfile`. Add the following hook (or merge
its body into an existing `post_integrate` hook) to avoid Agora RTC/Chat both
embedding `aosl.framework`:

```ruby
post_integrate do |installer|
  require_relative '.symlinks/plugins/flutter_realtime_sdk/ios/podfile'
  FlutterRealtimeSdk::PodfileIntegration.deduplicate_agora_frameworks!(installer)
end
```

The helper removes only Chat's duplicate embed when RTC's SwiftPM product
is present, preserving other frameworks and the application's own hooks.
Actual Agora RTC/Chat coexistence still requires device testing.
ARTC's current framework is device-only; this combined package does not
support the iOS Simulator.

For controlled/offline builds, set `FLUTTER_REALTIME_SDK_IOS_OFFLINE=1`.
Optionally set `FLUTTER_REALTIME_SDK_IOS_ARCHIVE_CACHE` to a directory containing
the two official archives named `<sha256>.zip` using the manifest checksums.
Missing or mismatched archives fail without downloading when offline.

Add camera/microphone usage descriptions and the platform permissions required
by the chosen features. Screen sharing and other OS-specific capabilities
can require additional host configuration.

## Distribution limitations

- Every declared vendor dependency is resolved even if only one provider is
  registered; native size and build cost are not eliminated by Dart tree shaking.
- Web supports the normal JavaScript build; Wasm is not verified/supported by
  the current complete dependency set.
- Windows/Linux and physical-device/media acceptance remain pending.
- Build results do not establish real vendor interoperability or cloud cleanup.
- Third-party components retain their own licenses and service terms; the
  package's MIT license covers the project's own code.

[Source and documentation](https://github.com/lengsukq/flutter_multi_livestream_video) ·
[中文说明](README.zh-CN.md) ·
[Full Chinese integration guide](https://github.com/lengsukq/flutter_multi_livestream_video/blob/main/doc/APP_INTEGRATION_QUICKSTART.zh-CN.md)
