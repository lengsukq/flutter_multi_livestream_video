# Multi-provider media architecture

This repository keeps the existing `flutter_aws_chime` plugin compatible while
adding a provider-neutral media layer.

## Dependency direction

```text
application
    |
    v
flutter_realtime_media_core
    |
    +--> flutter_realtime_media_livekit --> livekit_client
    |
    +--> flutter_realtime_media_agora --> agora_rtc_engine
    |
    +--> flutter_realtime_media_trtc --> tencent_rtc_sdk
    |
    +--> flutter_realtime_media_chime --> flutter_aws_chime
```

The core package never imports a provider SDK. Adapter packages implement the
core `MediaSessionFactory` and `MediaSession` contracts and translate provider
tracks, events and failures into stable core models.

## Compatibility rules

1. Existing `flutter_aws_chime` APIs such as `ChimeMeetingSession`, `JoinInfo`
   and `ChimeClient` remain usable directly.
2. Chime is wrapped by an adapter; the stable Android/iOS native bridge is not
   rewritten for the generic API.
3. Provider-specific SDK types do not cross the core public API boundary.
4. A `viewer` is subscribe-only twice: the Dart viewer interface has no media
   publishing methods and its backend-issued provider credential must deny
   media publishing.
5. Heartbeat and leave-notification failures are backend-presence failures and
do not terminate otherwise healthy media.
6. TRTC and every other provider remain optional adapter dependencies; Core does
   not select a default provider, and each application registers only the
   providers it supports.
7. Demo servers and local LiveKit tooling are development/reference assets,
   not runtime dependencies of published Flutter packages.

## Core responsibilities

- roles, capabilities, state, snapshots, participants, tracks and messages
- media lifecycle and control interfaces
- provider registry and adapter SPI
- provider-neutral backend HTTP client and backend-presence wrapper

## Adapter responsibilities

- parse the provider block returned by `MEDIA_BACKEND_CONTRACT.md`
- create, connect and dispose the provider SDK session
- translate provider events, tracks, devices and failures to core types
- implement only the capabilities that the provider/session actually supports

## Application backend responsibilities

- authenticate the application user
- select the provider for newly created rooms
- persist or recover the room-code-to-provider mapping
- create or resolve rooms
- mint short-lived provider credentials with role-appropriate grants
- keep provider API keys and long-lived secrets out of Flutter
- implement the versioned HTTP contract in `MEDIA_BACKEND_CONTRACT.md`

The backend language is intentionally irrelevant. Node.js, Java, Python, Go,
.NET, serverless functions, or an existing monolith can all implement the same
HTTP contract. The Flutter SDK does not require the repository's Node scripts.

## Local provider routing

For development, the existing `demo-server` is the single backend entry point.
When testing LiveKit locally, start the local media server and export its
credentials into the same shell first:

```bash
bash scripts/livekit-dev.sh start
eval "$(bash scripts/livekit-dev.sh env)"
cd demo-server
npm start
```

For Agora, add `AGORA_APP_ID` and `AGORA_APP_CERTIFICATE` to the same
server environment. For TRTC, set `TRTC_SDK_APP_ID` and
`TRTC_SDK_SECRET_KEY`, then enable Advanced Permission Control in the Tencent
RTC project. Open `http://127.0.0.1:3000/` and select a provider for new rooms
in the reference server UI. Flutter never sends a provider; the backend returns
the selected provider and only the matching registered adapter is resolved.
Existing rooms keep their original room-to-provider binding, so switching the
UI affects only rooms created afterwards.

### Demo backend provider adapters

The reference `demo-server` mirrors the Flutter adapter architecture. Its HTTP
routes are provider-neutral and dispatch through a `ProviderRegistry`; each RTC
implementation lives under `demo-server/providers/`. A shared `RoomDirectory`
stores the room-code-to-provider binding and optional provider-native aliases.

Adding another demo provider should normally require only a new provider module
plus one registry registration. The room create/join/heartbeat/leave/close
routes and dashboard provider switcher must not gain a new provider-specific
branch. The dashboard consumes provider metadata returned by `/api/overview`.
