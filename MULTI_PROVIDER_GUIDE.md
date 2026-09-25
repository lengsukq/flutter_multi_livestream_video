# Multi-provider Flutter media guide

Existing apps may continue using `flutter_aws_chime` directly. Apps that want
backend-controlled provider selection register the adapters they support and
use Core without choosing a provider per room.

## Package layout

```text
flutter_realtime_media_core
  ├─ flutter_realtime_media_ui      -> ready-to-use provider-neutral UI
  ├─ flutter_realtime_media_livekit -> livekit_client
  ├─ flutter_realtime_media_agora   -> agora_rtc_engine
  ├─ flutter_realtime_media_trtc    -> tencent_rtc_sdk
  ├─ flutter_realtime_media_artc    -> native AliVCSDK_ARTC (Android/iOS)
  └─ flutter_realtime_media_chime   -> flutter_aws_chime
```

Provider SDKs never become dependencies of Core.

Core does not maintain a platform whitelist for registered adapters. If an app
registers an adapter, Core will attempt to use it on the current Flutter target
instead of rejecting the room up front. Provider/native SDKs remain responsible
for reporting genuinely unsupported targets, while feature-level differences
continue to be exposed through `MediaCapabilities`.

For optional functionality, application code should also stay provider-neutral:
query `MediaCapabilities` / `MediaFeature`, then use the shared device,
network-stat, advanced-data, recovery, or room-management APIs. The current
cross-provider matrix is documented in
[`SDK_CAPABILITY_MATRIX.md`](SDK_CAPABILITY_MATRIX.md). Unsupported optional behavior
returns a typed error rather than requiring `providerId` conditionals in the
business layer.

The reference backend also owns role assignment. New clients create either a
`meeting` or `broadcast` room and do not choose a role when joining:
`meeting` grants `participant` to everyone, while `broadcast` grants
`host` to the creator device and `viewer` to other devices.

## One Flutter API, multiple providers

```dart
final registry = MediaRegistry([
  const AgoraSessionFactory(),
  const LiveKitSessionFactory(),
  const TrtcSessionFactory(),
  const ArtcSessionFactory(),
  ChimeSessionFactory(),
]);

final client = MediaClient(
  backendUrl: 'https://api.example.com',
  registry: registry,
  tokenProvider: () async => applicationToken,
);

final room = await client.createRoomAndJoinIdentity(
  role: MediaRole.participant,
  identity: const MediaIdentity(
    userId: 'account-123',
    displayName: 'Leo',
    deviceId: 'install-abc',
  ),
);
```

The backend returns the actual provider with the join credentials. Core resolves
the matching adapter automatically. Business UI only needs room/user intent;
provider choice does not appear in create/join calls.

TRTC and ARTC are optional adapter packages. Applications that do not use them
do not add their packages or SDK dependencies; Core has no Tencent or Alibaba
dependency and no default provider. The reference demo registers both alongside
its other adapters, while each application's backend remains the source of
provider selection for every room. ARTC requires Alibaba Maven repositories in
Android dependency resolution and uses CocoaPods on iOS; its 7.11.0 iOS pod is
device-only and does not support simulator linking.

## Backend requirements

The backend language is not prescribed. Java Spring Boot, Python FastAPI,
Node.js, Go, .NET, Lambda, or another server only needs to implement:

```text
POST   /rooms
POST   /rooms/{roomCode}/join
POST   /rooms/{roomCode}/heartbeat
POST   /rooms/{roomCode}/leave
DELETE /rooms/{roomCode}
POST   /rooms/{roomCode}/credentials/refresh  (optional)
```

Long-lived provider credentials remain on that server. Flutter receives only
short-lived join credentials.

## Local backend modes

For Chime-only testing, the normal backend command is enough:

```bash
cd demo-server
npm start
```

For local LiveKit + Chime testing:

```bash
bash scripts/livekit-dev.sh start
eval "$(bash scripts/livekit-dev.sh env)"
cd demo-server
npm start
```

To enable Agora in the same server, also set `AGORA_APP_ID` and
`AGORA_APP_CERTIFICATE` (normally in the ignored `demo-server/.env`).

The public URL is `http://127.0.0.1:3000`. Open the existing dashboard and
switch new rooms between LiveKit, Agora, AWS Chime, Tencent TRTC, and Alibaba
ARTC directly in the server UI. TRTC signing requires `TRTC_SDK_APP_ID` and
`TRTC_SDK_SECRET_KEY` on the server; enable Advanced Permission Control in the
Tencent RTC project. The Flutter package receives short-lived UserSig and room
PrivateMapKey values only.

The LiveKit server itself is managed by `bash scripts/livekit-dev.sh` and can remain
running between tests.

## Unified demo

`example` exposes no provider selector. It registers the optional adapters once,
sends only the backend URL, room/user information and role, and
uses the provider returned by the backend to resolve the renderer/session.

Agora uses numeric UIDs so `participantId` is the decimal UID string. The
Agora adapter supports participant/host RTC media, viewer subscribe-only
media, RTC data messages for participant/host, and provider-neutral video
rendering on Android, iOS, and macOS. Front/back camera switching is available
on Android/iOS; macOS uses the current desktop camera. Screen sharing stays
deferred. Viewer data sending is currently
disabled rather than implicitly promoting an Agora audience client to host.

The TRTC adapter maps `participant` to the video-call scene and `host`/`viewer`
to the live-streaming scene. The backend locks each room to the scene selected
when it is created. Viewers use the Core subscribe-only interface and receive a
PrivateMapKey without media-publish privileges. Participant/host custom messages
are supported; viewer messaging, screen share, and audio-device enumeration are
not part of this adapter's first release.

The ARTC adapter maps `participant` to communication mode and `host`/`viewer`
to interactive live mode. The backend locks each room to its creation mode.
ARTC's viewer role is selected by the client SDK; its token authenticates the
application, channel, user, and expiry but does not enforce viewer publishing
rights server-side. The Core viewer surface exposes no publish methods, but
applications must not treat this as protection against a modified client.
Viewer custom messages are receive-only; screen share and audio-device
enumeration are not advertised by the first release.

```bash
cd example
flutter run --dart-define=MEDIA_BACKEND_URL=http://192.168.31.8:3000
```

For local application auth, `MEDIA_APP_TOKEN` may also be supplied as a Dart
define. Production applications should normally obtain app auth at runtime.

## Adding another provider

1. Create a separate adapter package depending on Core and the provider SDK.
2. Implement `MediaSessionFactory` and parse your provider response block.
3. Implement the narrowest session interface matching real capabilities.
4. Translate provider state/events/errors into Core models.
5. Add a `MediaTrackRenderer` when video is supported.
6. Add offline contract tests and an optional E2E path.
7. Add the provider to backend routing/admin configuration without changing
   business UI.

Do not claim a role or capability until both the client surface and backend
credential grants enforce it.
