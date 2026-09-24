# Multi-provider SDK usage

The repository now has three layers:

```text
Flutter application
       |
       v
flutter_multi_livestream_video_core
       |
       +-- flutter_multi_livestream_video_livekit
       |
       +-- flutter_multi_livestream_video_chime
```

Core contains no provider SDK dependency. Applications register the adapters
they want and then use one `MediaClient` API.

## Register providers

```dart
final registry = MediaRegistry([
  const LiveKitSessionFactory(),
  ChimeSessionFactory(),
]);

final client = MediaClient(
  backendUrl: 'https://api.example.com',
  registry: registry,
  tokenProvider: () async => appAccessToken,
);
```

Create a room without choosing a provider:

```dart
final room = await client.createRoomAndJoin(
  nickname: 'Host',
  role: MediaRole.host,
);
```

Join by room code:

```dart
final room = await client.joinRoom(
  roomCode: code,
  nickname: 'Viewer',
  role: MediaRole.viewer,
);
```

The backend returns `provider` in the join response. `MediaClient` uses that
value internally to resolve the registered adapter; application business logic
does not choose LiveKit/Chime.

Chime currently advertises `MediaRole.participant` only. Existing Chime
meeting credentials are symmetric, so the adapter does not claim secure
subscribe-only viewer semantics that the backend cannot enforce yet.

## LiveKit adapter

Interactive/host sessions support microphone control, camera enable/disable,
front/back switching, screen share, audio-output selection when available,
reliable data messages, and provider-neutral participant/track/event streams.

`LiveKitViewerSession` implements `BroadcastViewerSession`, not
`InteractiveMediaSession`. The backend also must issue viewer credentials with
`canPublish: false`.

Render LiveKit tracks using `LiveKitTrackRenderer` with Core `MediaTrackView`.

## Chime adapter

The Chime adapter wraps the existing `flutter_aws_chime` implementation rather
than replacing its Android/iOS bridge. It maps microphone/camera controls,
audio devices, messages, attendees, video tiles, received content share,
speaking state, and Chime errors into Core types.

Outgoing Chime screen share remains `unsupportedFeature`, matching the existing
plugin. Existing `ChimeClient`, `ChimeMeetingSession`, `JoinInfo`, and
`ChimeMeetingView` remain valid direct APIs.

## Unified local backend

`demo-server` is the only application backend entry point. For local LiveKit
testing, start the media server first and export its dev credentials:

```bash
bash scripts/livekit-dev.sh start
eval "$(bash scripts/livekit-dev.sh env)"
cd demo-server
npm start
```

Default ports:

- application backend/dashboard: `3000`;
- local LiveKit server: `7880`.

Open `http://127.0.0.1:3000/` and switch LiveKit / AWS Chime directly in the
existing server UI; the selection affects new rooms only. The Flutter app does
not receive this configuration.

For a simulator, use `http://127.0.0.1:3000`. For a physical phone, use the
Mac's LAN address with port `3000`.

The Flutter demo is the existing `example` Chime Live app. It limits provider-specific
logic to configuration; the joined-room UI works against Core session,
snapshot, and renderer abstractions.

## Security

Provider API secrets never belong in Flutter. The Flutter app sends an optional
application bearer token to your backend and receives only short-lived join
credentials. LiveKit signing secrets and AWS credentials remain server-side.

The local scripts are development references, not production authentication,
authorization, persistence, rate limiting, or deployment templates.
