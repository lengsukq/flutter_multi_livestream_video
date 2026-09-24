# Multi-provider Flutter media guide

Existing apps may continue using `flutter_aws_chime` directly. Apps that want
backend-controlled provider selection register the adapters they support and
use Core without choosing a provider per room.

## Package layout

```text
flutter_realtime_media_core
  ├─ flutter_realtime_media_livekit -> livekit_client
  ├─ flutter_realtime_media_agora   -> agora_rtc_engine
  ├─ flutter_realtime_media_trtc    -> tencent_rtc_sdk
  └─ flutter_realtime_media_chime   -> flutter_aws_chime
```

Provider SDKs never become dependencies of Core.

## One Flutter API, multiple providers

```dart
final registry = MediaRegistry([
  const AgoraSessionFactory(),
  const LiveKitSessionFactory(),
  const TrtcSessionFactory(),
  ChimeSessionFactory(),
]);

final client = MediaClient(
  backendUrl: 'https://api.example.com',
  registry: registry,
  tokenProvider: () async => applicationToken,
);

final room = await client.createRoomAndJoin(
  role: MediaRole.participant,
  nickname: 'Leo',
);
```

The backend returns the actual provider with the join credentials. Core resolves
the matching adapter automatically. Business UI only needs room/user intent;
provider choice does not appear in create/join calls.

TRTC is an optional adapter package. Applications that do not use it do not add
`flutter_realtime_media_trtc` and do not download `tencent_rtc_sdk`; Core has no
Tencent dependency and no default provider. The reference demo registers TRTC
alongside its other adapters, while each application's backend remains the
source of provider selection for every room.

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
switch new rooms between LiveKit, Agora, AWS Chime, and Tencent TRTC directly in
the server UI. TRTC signing requires `TRTC_SDK_APP_ID` and
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
rendering. Screen sharing stays deferred. Viewer data sending is currently
disabled rather than implicitly promoting an Agora audience client to host.

The TRTC adapter maps `participant` to the video-call scene and `host`/`viewer`
to the live-streaming scene. The backend locks each room to the scene selected
when it is created. Viewers use the Core subscribe-only interface and receive a
PrivateMapKey without media-publish privileges. Participant/host custom messages
are supported; viewer messaging, screen share, and audio-device enumeration are
not part of this adapter's first release.

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
