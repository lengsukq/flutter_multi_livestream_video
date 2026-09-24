# flutter_realtime_media_artc

Optional Alibaba Cloud ARTC adapter for
[`flutter_realtime_media_core`](../flutter_realtime_media_core). The adapter
keeps ARTC types, native dependencies, credentials, and platform rendering out
of Core. Apps that do not register ARTC do not use its native SDK.

## Install and register

```yaml
dependencies:
  flutter_realtime_media_core:
    path: ../flutter_realtime_media_core
  flutter_realtime_media_artc:
    path: ../flutter_realtime_media_artc
```

```dart
final client = MediaClient(
  backendUrl: backendUrl,
  registry: MediaRegistry([
    const ArtcSessionFactory(),
    // Register only the other adapters this app uses.
  ]),
);

final room = await client.createRoomAndJoin(
  role: MediaRole.host,
  nickname: 'Host',
);
```

The backend chooses a provider for each room. Business UI passes room intent
only and does not select ARTC.

## Platforms and native SDK

The package supports Android and iOS device builds. It wraps Alibaba Cloud's
native ARTC SDK 7.11.0 on both platforms. Android resolves
`com.aliyun.aio:AliVCSDK_ARTC:7.11.0` from Alibaba Cloud's Maven repositories;
iOS resolves the `AliVCSDK_ARTC` CocoaPod at 7.11.0. The iOS 7.11.0 pod
contains a device framework rather than an XCFramework, so iOS Simulator builds
cannot link it. Host apps keep the existing Android API 23 and iOS 15 minimums.
See Alibaba Cloud's [ARTC SDK integration guide](https://www.alibabacloud.com/help/en/live/artc-download-the-sdk).

For Android projects that use `dependencyResolutionManagement`, add both
Alibaba repositories to the repositories block in `settings.gradle`:

```groovy
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        maven { url 'https://maven.aliyun.com/repository/google' }
        maven { url 'https://maven.aliyun.com/repository/public' }
    }
}
```

The host iOS app must provide `NSCameraUsageDescription` and
`NSMicrophoneUsageDescription`. iOS prompts when a local track is enabled.
Android receives the camera and microphone permissions from the plugin
manifest; the adapter requests runtime access when a local track is enabled.

## Credentials and security

The backend returns a short-lived, server-generated `artc.authInfo` value and
its expiry. The AppKey and token-signing logic stay on the server. The adapter
renews through Core's optional credentials refresh route and rejoins the same
room as the same ARTC user.
Alibaba Cloud recommends server-side signing in its [token authentication guide](https://www.alibabacloud.com/help/en/ims/developer-reference/token-based-authentication).

ARTC's token authenticates the application, channel, user, and expiry. ARTC
does not encode the viewer role as a server-enforced publish grant: the native
SDK role is selected by the client. The viewer Dart surface has no publish
methods and the adapter joins it in viewer mode, but this is not protection
against a modified client. Do not represent it as a backend-enforced security
boundary.

## Roles and capabilities

| Core role | ARTC mode | Adapter surface |
| --- | --- | --- |
| `participant` | Communication | Publish and subscribe audio/video |
| `host` | Interactive live, streamer | Publish and subscribe audio/video |
| `viewer` | Interactive live, viewer | Subscribe only; no local publish API |

The demo backend locks a room to its creation mode: `participant` rooms use
communication mode, and `host`/`viewer` rooms use interactive live mode. It
rejects joins from the other mode. This mode lock and application authorization
do not prevent a modified client from changing its ARTC SDK role.

The adapter supports camera/microphone controls, front/back camera switching,
video rendering, participant events, and custom data messages for participants
and hosts. ARTC data messages require the sender to have an active audio or
video stream, so enable the microphone or camera before sending. Viewers can
receive data messages but cannot send them. Screen share and audio-device
enumeration are not advertised. Unsupported operations return a typed
`MediaError`.

## Backend response

The common fields are returned by the v1 backend contract, with an ARTC block:

```json
{
  "contractVersion": 1,
  "provider": "artc",
  "role": "host",
  "roomCode": "482913",
  "participantId": "u-person1",
  "displayName": "Host",
  "artc": {
    "appId": "public-app-id",
    "channelId": "media-482913",
    "userId": "u-person1",
    "authInfo": "<short-lived-base64-auth-info>",
    "expiresAtMs": 1790000000000
  }
}
```

`participantId` must equal `artc.userId`. `authInfo` is opaque to the adapter;
the backend generates it with the ARTC single-parameter token format. See
[`MEDIA_BACKEND_CONTRACT.md`](../../MEDIA_BACKEND_CONTRACT.md).
