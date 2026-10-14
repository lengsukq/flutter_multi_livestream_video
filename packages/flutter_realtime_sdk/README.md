# flutter_realtime_sdk

Lightweight, provider-neutral Flutter facade for meetings, live streams and standalone chat. **Providers and UI are opt-in**: depending on this package does not install Agora, LiveKit, AWS, Tencent, Alibaba or any room widgets automatically.

**First integration into your own app:** follow the
[Chinese end-to-end quickstart](https://github.com/lengsukq/flutter_multi_livestream_video/blob/main/doc/APP_INTEGRATION_QUICKSTART.zh-CN.md)
before choosing individual features. The guide covers local path dependencies,
backend/token setup, creator vs guest roles, Headless/UI, and platform checks.

> **Status:** development monorepo package, **not published on pub.dev yet**. `publish_to: none` and local dependencies are intentional until the [release checklist](https://github.com/lengsukq/flutter_multi_livestream_video/blob/main/doc/PUB_DEV_RELEASE_GUIDE.zh-CN.md) is completed.

## Requirements and installation

- Flutter ≥ **3.47**, Dart ≥ **3.12**; supported platforms depend on your chosen Provider and host configuration.
- Add this facade and **only** the Provider bundles you intend to use to the host `pubspec.yaml`.
- Before pub.dev publication, reference packages in a local monorepo checkout:

```yaml
dependencies:
  flutter_realtime_sdk:
    path: ../flutter_multi_livestream_video/packages/flutter_realtime_sdk
  flutter_realtime_provider_livekit:
    path: ../flutter_multi_livestream_video/packages/flutter_realtime_provider_livekit
```

These paths assume the host Flutter project and the SDK checkout are sibling folders. Replace them with the real relative paths in your workspace. A hosted `flutter pub add` example will be provided **only after the package exists on pub.dev**.

## Create, join and dispose

```dart
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_realtime_provider_livekit/flutter_realtime_provider_livekit.dart';

final realtime = Realtime(
  backendUrl: 'https://your-backend.example',
  providers: [createLivekitProvider()],
);

final connection = await realtime.open(
  RealtimeRequest.join(
    type: RealtimeExperience.meeting,
    roomCode: '123456',
    user: const RealtimeUser(id: 'user-1', name: 'Alice'),
  ),
);

final room = connection.mediaRoom!;
final subscription = room.states.listen((state) {
  // Update application-owned state / custom UI here.
});
// Keep BOTH connection and subscription alive while the user participates.
// In the host application's explicit leave/logout handler, run:
// await subscription.cancel();
// await connection.dispose();
```

- Use `RealtimeRequest.create(type: ..., user: ...)` for a new room.
- Use `RealtimeExperience.live` for a broadcast or `RealtimeExperience.chat` for standalone product chat. Chat connections use `connection.chatRoom`; meeting/live use `connection.mediaRoom`.
- For a host-owned credential service use `RealtimeSource.credentials(...)` rather than exposing long-lived vendor secrets. The provided Demo Server is a reference, **not required** if you implement compatible provisioning.
- `Realtime.preJoin(...)` and `createLocalPreview(...)` are available without mandatory SDK UI. Handle permissions and release local previews separately.

## Optional feature and UI packages

```dart
import 'package:flutter_realtime_classroom_preset/flutter_realtime_classroom_preset.dart';
import 'package:flutter_realtime_live_preset/flutter_realtime_live_preset.dart';

final realtime = Realtime(
  backendUrl: 'https://your-backend.example',
  providers: [createLivekitProvider()],
  featurePlugins: const [ClassroomPreset(), LivePreset()],
);
```

These presets require a trusted authoritative backend (or explicitly provided repositories). Classroom hands, Q&A and Live gift/like events are *not* automatically enabled by importing the facade. Gifts are a demonstration of non-payment interactions.

For optional ready-to-use widgets, **separately** add `flutter_realtime_sdk_ui` and compose `RealtimeRoomView(room: connection.mediaRoom!)`. To build all UI yourself, do **not** add `flutter_realtime_sdk_ui`.

## Provider registration

| Provider bundle | Factory |
| --- | --- |
| `flutter_realtime_provider_livekit` | `createLivekitProvider()` |
| `flutter_realtime_provider_agora` | `createAgoraProvider()` |
| `flutter_realtime_provider_trtc` | `createTrtcProvider()` |
| `flutter_realtime_provider_artc` | `createArtcProvider()` |
| `flutter_realtime_provider_aws` | `createAwsProvider()` |
| `flutter_realtime_provider_agora_chat` | `createAgoraChatProvider()` |
| `flutter_realtime_provider_ivs_chat` | `createIvsChatProvider()` |
| `flutter_realtime_provider_tencent_chat` | `createTencentChatProvider()` |

Backend-issued provider identifiers must resolve to a bundle registered by the host. AWS routes Meeting to Chime and Live to IVS. Check `MediaCapabilities`, `ChatCapabilities` and the platform matrix at runtime; do not infer features solely from the provider name.

## Security, recording and support

- App ID may be public where the vendor allows it; **App Certificate, Customer Secret, cloud access keys and user signing keys belong server-side only**.
- Cloud recording starts/stops in the trusted backend, not in this package; storage, MP4 conversion and billable recording lifecycle depend on the actual vendor. See [cloud recording](https://github.com/lengsukq/flutter_multi_livestream_video/blob/main/doc/CLOUD_RECORDING.md).
- Web media requires HTTPS or localhost for permissions; configure native camera/microphone permissions in the host app.
- [SDK integration (Chinese)](https://github.com/lengsukq/flutter_multi_livestream_video/blob/main/doc/SDK_RUNTIME_INTEGRATION.zh-CN.md) · [Platform capability matrix](https://github.com/lengsukq/flutter_multi_livestream_video/blob/main/doc/SDK_CAPABILITY_MATRIX.zh-CN.md) · [Full Demo](https://github.com/lengsukq/flutter_multi_livestream_video/tree/main/example).

Platform support in the capability matrix describes implemented drivers, **not an assurance of end-to-end real-device testing for every provider/platform combination**.
