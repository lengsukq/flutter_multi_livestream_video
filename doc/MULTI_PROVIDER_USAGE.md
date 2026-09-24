# Multi-provider SDK usage

The repository now has three layers:

```text
Flutter application
       |
       v
flutter_realtime_media_core
       |
       +-- flutter_realtime_media_agora
       |
       +-- flutter_realtime_media_livekit
       |
       +-- flutter_realtime_media_chime
```

Core contains no provider SDK dependency. Applications register the adapters
they want and then use one `MediaClient` API.

## Register providers

```dart
final registry = MediaRegistry([
  const AgoraSessionFactory(),
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
does not choose LiveKit/Agora/Chime.

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

## Agora adapter

Agora participant and host sessions publish/subscribe audio and video, support
mute, camera enable/disable, front/back camera switching, RTC data messages,
participant/event mapping, and `AgoraTrackRenderer`. The adapter deliberately
advertises `canScreenShare=false` while screen sharing remains deferred.

`AgoraViewerSession` is subscribe-only at the Core API and Agora audience-role
layers. Viewer RTC data sending is disabled because Agora live-broadcast data
streams are host-oriented. The reference backend mints AccessToken2 with no
viewer audio/video/data publish privileges; hard server-side enforcement of
those fine-grained privileges also requires Agora co-host authentication to be
enabled for the project.

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

Set `AGORA_APP_ID` and `AGORA_APP_CERTIFICATE` on `demo-server` to enable
Agora. Open `http://127.0.0.1:3000/` and switch LiveKit / Agora / AWS Chime
directly in the existing server UI; the selection affects new rooms only. The Flutter app does
not receive this configuration.

For a simulator, use `http://127.0.0.1:3000`. For a physical phone, use the
Mac's LAN address with port `3000`.

The Flutter demo is the existing `example` app. It limits provider-specific
logic to adapter registration; the joined-room UI works against Core session,
snapshot, and renderer abstractions.

## Security

Provider API secrets never belong in Flutter. The Flutter app sends an optional
application bearer token to your backend and receives only short-lived join
credentials. LiveKit signing secrets, the Agora App Certificate, and AWS
credentials remain server-side.

The local scripts are development references, not production authentication,
authorization, persistence, rate limiting, or deployment templates.
