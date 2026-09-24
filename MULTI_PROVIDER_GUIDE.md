# Multi-provider Flutter media guide

Existing apps may continue using `flutter_aws_chime` directly. Apps that want
backend-controlled provider selection register the adapters they support and
use Core without choosing a provider per room.

## Package layout

```text
flutter_realtime_media_core
  ├─ flutter_realtime_media_livekit -> livekit_client
  └─ flutter_realtime_media_chime   -> flutter_aws_chime
```

Provider SDKs never become dependencies of Core.

## One Flutter API, multiple providers

```dart
final registry = MediaRegistry([
  const LiveKitSessionFactory(),
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

## Backend requirements

The backend language is not prescribed. Java Spring Boot, Python FastAPI,
Node.js, Go, .NET, Lambda, or another server only needs to implement:

```text
POST   /rooms
POST   /rooms/{roomCode}/join
POST   /rooms/{roomCode}/heartbeat
POST   /rooms/{roomCode}/leave
DELETE /rooms/{roomCode}
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

The public URL is `http://127.0.0.1:3000`. Open the existing dashboard and
switch new rooms between LiveKit and AWS Chime directly in the server UI.

The LiveKit server itself is managed by `bash scripts/livekit-dev.sh` and can remain
running between tests.

## Unified demo

`example` (the existing Chime Live app) exposes no provider selector. It registers both
adapters once, sends only the backend URL, room/user information and role, and
uses the provider returned by the backend to resolve the renderer/session.

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
