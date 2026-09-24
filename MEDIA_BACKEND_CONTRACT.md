# Media Backend Contract v1

This document defines the provider-neutral HTTP contract used by
`MediaClient` / `MediaBackendClient` in
[`flutter_realtime_media_core`](packages/flutter_realtime_media_core).
It is language-neutral: a backend may be implemented in Node.js, Java, Python,
Go, .NET, or any other stack.

It is a **superset of [`BACKEND_CONTRACT.md`](BACKEND_CONTRACT.md)** (the Chime
contract v1): the same room endpoints, while provider choice is owned by the
backend. Chime-only backends keep working unchanged — see
[Chime compatibility](#chime-compatibility).

The Flutter side never receives provider API keys or secrets. Creating rooms,
signing provider tokens, and holding long-lived credentials are backend
responsibilities.

## Versioning

The current contract version is `1`.

The SDK sends this request header on contract calls:

```http
X-Media-Backend-Contract: 1
```

Compatible servers should return the same header and may include:

```json
{ "contractVersion": 1 }
```

If a supplied version is unsupported, return HTTP `400` with the standard error
body below.

## Authentication

Authentication belongs to the application. When configured with a
`tokenProvider`, the SDK sends:

```http
Authorization: Bearer <application-token>
```

This is an application token, never a provider credential. Backends with a
different scheme can use `headersProvider` instead.

## Backend provider selection

| Field | Where | Meaning |
| --- | --- | --- |
| `role` | request body | `participant` (meeting), `host` (broadcast publisher), or `viewer` (broadcast subscriber). Optional; defaults to `participant`. |
| `provider` | response body | Provider selected by the backend and used to issue credentials. Optional only for legacy Chime responses; when absent the SDK assumes `chime`. |
| `role` | response body | Optional echo of the granted role; when absent the SDK keeps the requested role. |

Flutter never requests `livekit`, `chime`, or another provider. The backend may
choose based on deployment configuration, tenant, room policy, requested role,
capacity, cost, region, feature flags, or another server-side rule. Existing
room codes must keep resolving to the provider that owns that room.

If the server-selected provider is not configured, return
`provider-not-configured` (HTTP `503`).

## Endpoints

### `POST /rooms`

Create a room and an attendee/participant for the caller.

```json
{
  "nickname": "Host A",
  "roomCode": "482913",
  "role": "host"
}
```

`roomCode` is optional (the server may generate one). Success returns a
[join response](#join-response). Recommended errors: `bad-room-code` (`400`),
`room-exists` (`409`).

### `POST /rooms/{roomCode}/join`

Create an attendee/participant in an existing room.

```json
{ "userId": "Guest", "role": "viewer" }
```

Missing room returns `room-not-found` (`404`).

### `POST /rooms/{roomCode}/credentials/refresh` (optional)

Refresh short-lived credentials for an already admitted participant. Adapters
that support renewal call this endpoint; existing adapters and compatible
backends that do not use expiring credentials are unaffected.

```json
{ "participantId": "u-123", "role": "host" }
```

Success returns the standard [join response](#join-response). The backend must
keep `provider`, `roomCode`, `participantId`, and `role` identical to the
original session, and must authorize the caller as that application user. A
refresh response that changes any of those fields is rejected by Core. Return
`forbidden` (`403`) when the user is not authorized to refresh that participant.

### `POST /rooms/{roomCode}/heartbeat`

Best-effort presence signal, called once after joining and then every
heartbeat interval. Body may be empty. Example success:

```json
{ "contractVersion": 1, "ok": true, "roomCode": "482913" }
```

Heartbeat failures surface on `MediaRoomSession.backendErrors` and never
terminate healthy media.

### `POST /rooms/{roomCode}/leave`

Best-effort leave notification.

```json
{ "participantId": "host-a" }
```

Servers should accept `attendeeId` as an alias so Chime-era implementations and
the generic client can share one endpoint. Implementations must make this
endpoint safe to call more than once.

### `DELETE /rooms/{roomCode}`

Optional administrative operation exposed by `MediaBackendClient.closeRoom`.
Applications are not required to expose it to ordinary clients. For providers
that bill by attendance there is nothing to release; for providers that bill by
provisioned room (for example AWS Chime) this is the "stop future joins" call.

## Join response

Common fields:

```json
{
  "contractVersion": 1,
  "provider": "livekit",
  "role": "host",
  "roomCode": "482913",
  "participantId": "host-a"
}
```

`roomCode` is required (the SDK falls back to the requested code on join calls),
`participantId` is required by adapters. Additional fields are allowed and
ignored.

### LiveKit provider block

```json
{
  "contractVersion": 1,
  "provider": "livekit",
  "role": "host",
  "roomCode": "482913",
  "participantId": "host-a",
  "livekit": {
    "url": "ws://192.168.31.8:7880",
    "token": "<short-lived-access-token>",
    "identity": "host-a"
  }
}
```

| Field | Required | Meaning |
| --- | --- | --- |
| `livekit.url` | yes | Signaling URL: `ws://<lan-ip>:7880` for a local dev server, `wss://<project>.livekit.cloud` for LiveKit Cloud. |
| `livekit.token` | yes | Short-lived JWT access token minted by the backend. |
| `livekit.identity` | no | Participant identity; must match `participantId` when supplied. |

Token requirements:

- `roomJoin: true` and `room` scoped to the provider room mapped from the
  application room code (so a leaked token cannot join another room);
- `canPublish: true` for `host`/`participant`, **`canPublish: false` for
  `viewer`**;
- `canSubscribe: true` for every role;
- `canPublishData` for chat: `true` for host/participant, configurable for
  viewers;
- `ttl` short (minutes), not the SDK default of six hours.

### Agora provider block

```json
{
  "contractVersion": 1,
  "provider": "agora",
  "role": "host",
  "roomCode": "482913",
  "participantId": "123456789",
  "displayName": "Host A",
  "agora": {
    "appId": "<agora-app-id>",
    "channelName": "media-482913",
    "token": "<short-lived-access-token-2>",
    "uid": 123456789
  }
}
```

| Field | Required | Meaning |
| --- | --- | --- |
| `agora.appId` | yes | Public Agora App ID. The App Certificate is **never** returned to Flutter. |
| `agora.channelName` | yes | Provider channel mapped from the application room code. |
| `agora.token` | yes | Short-lived Agora AccessToken2 minted by the backend. |
| `agora.uid` | yes | Positive signed 32-bit Agora UID (`1..2147483647`). Its decimal string must equal `participantId`. |

The reference backend grants join/audio/video/data privileges to `participant`
and `host`. A `viewer` receives join permission but no publish-audio,
publish-video, or publish-data privilege, and the Flutter adapter joins as an
Agora audience client with all local publishing disabled.

Agora's fine-grained publish privileges are enforced by the service only when
the Agora project has the corresponding **co-host authentication** capability
enabled. Without it, the SDK still enforces the viewer role locally, but the
backend must not claim that a modified client is server-side prevented from
publishing. Production integrations that depend on this security boundary must
enable the Agora feature and verify it with a real-project E2E test.

The current Agora adapter intentionally reports `canSendData=false` for
`viewer`. Agora RTC data streams in live-broadcast mode are host-oriented;
viewer chat would require a separate safe messaging design (for example RTM)
before it can match the Core viewer contract without weakening publish roles.

### Tencent TRTC provider block

```json
{
  "contractVersion": 1,
  "provider": "trtc",
  "role": "host",
  "roomCode": "482913",
  "participantId": "u-123",
  "displayName": "Host A",
  "trtc": {
    "sdkAppId": 1400000000,
    "strRoomId": "media-482913",
    "userId": "u-123",
    "userSig": "<short-lived-user-sig>",
    "privateMapKey": "<room-scoped-permission-ticket>",
    "expiresAtMs": 1780000000000
  }
}
```

| Field | Required | Meaning |
| --- | --- | --- |
| `trtc.sdkAppId` | yes | Public TRTC SDKAppID. |
| `trtc.strRoomId` | yes | Provider room mapped from the application room code. The adapter uses string room IDs consistently. |
| `trtc.userId` | yes | TRTC identity; it must exactly equal `participantId`. |
| `trtc.userSig` | yes | Short-lived UserSig signed by the backend. |
| `trtc.privateMapKey` | yes | Room-scoped permissions signed by the backend. Enable TRTC advanced permission control for the SDKAppID so the service enforces this grant. |
| `trtc.expiresAtMs` | recommended | UserSig and PrivateMapKey expiry as Unix milliseconds. Core adapters renew before this time and re-enter with the same room and identity. |

The TRTC adapter uses the `videoCall` scene for `participant`, and the `live`
scene for `host` and `viewer`. A room's scene is fixed when the reference
backend creates it; a role from the other scene receives `unsupported-role`.
Publisher grants include room create/join and main-stream audio/video
send/receive permissions. Viewer grants include room create/join and audio/video
receive only; they must not include audio, video, or substream publish bits.
The Flutter viewer surface also has no publish controls and reports
`canSendData=false`. Participant/host custom messages are supported. Screen
sharing, viewer messages, and audio-device enumeration are not supported by
this adapter version.

The TRTC adapter implements the optional Core credential-refresh capability.
It renews credentials before `expiresAtMs` and rejoins the same room as the same
TRTC user. The backend must verify the caller's application identity and role
before signing replacement values. Long-lived `TRTC_SDK_SECRET_KEY` values
never belong in Flutter.

### Alibaba Cloud ARTC provider block

```json
{
  "contractVersion": 1,
  "provider": "artc",
  "role": "host",
  "roomCode": "482913",
  "participantId": "u-person1",
  "displayName": "Host A",
  "artc": {
    "appId": "<public-artc-app-id>",
    "channelId": "media-482913",
    "userId": "u-person1",
    "authInfo": "<short-lived-base64-auth-info>",
    "expiresAtMs": 1790000000000
  }
}
```

| Field | Required | Meaning |
| --- | --- | --- |
| `artc.appId` | yes | Public ARTC AppID. The AppKey is never returned to Flutter. |
| `artc.channelId` | yes | ARTC channel mapped from the application room code. |
| `artc.userId` | yes | ARTC user identity; it must equal `participantId`. |
| `artc.authInfo` | yes | Short-lived, Base64-encoded single-parameter token generated by the backend. |
| `artc.expiresAtMs` | yes | Token expiry as Unix milliseconds; Core refreshes before expiry and rejoins with the same identity. |

The backend maps `participant` to communication mode and `host`/`viewer` to
interactive live mode, then locks each room to that mode. It must keep the
provider, room, participant, and role bound during credential refresh. ARTC
tokens authenticate the app, channel, user, and expiry; they do not encode a
server-enforced viewer publishing grant. The Core viewer surface has no publish
methods and joins in viewer mode, but this does not prevent a modified client
from changing its SDK role. ARTC custom data messages require a publisher to
have an active audio or video stream; viewers can receive messages but cannot
send them through this adapter.

### Chime compatibility

A Chime-only backend may omit `provider`, `role`, and `participantId` and
return the original shape:

```json
{
  "contractVersion": 1,
  "roomCode": "482913",
  "meeting": {
    "MeetingId": "...",
    "ExternalMeetingId": "...",
    "MediaRegion": "ap-southeast-1",
    "MediaPlacement": {
      "AudioHostUrl": "...",
      "AudioFallbackUrl": "...",
      "SignalingUrl": "...",
      "TurnControlUrl": "..."
    }
  },
  "attendee": {
    "AttendeeId": "...",
    "ExternalUserId": "...",
    "JoinToken": "..."
  }
}
```

The SDK resolves a missing `provider` to `chime`. See
[`BACKEND_CONTRACT.md`](BACKEND_CONTRACT.md) for the full Chime field list; the
Chime adapter validates `attendee.AttendeeId` against `participantId` when the
common field is supplied. The current Chime adapter intentionally advertises
only `participant`; `host`/`viewer` are rejected until backend-enforced Chime
broadcast permissions are implemented.

## Local provider modes

The existing `demo-server` implements the reference multi-provider backend.
It remains the only application-backend process:

```bash
cd demo-server
npm start
```

The server listens on `http://127.0.0.1:3000` by default. Open its existing
dashboard at `/` to switch the provider used for **new rooms** between LiveKit,
Agora, and AWS Chime without restarting Flutter. Existing rooms remain bound to their
original provider. Join/heartbeat/leave/delete resolve only by room code.

For local LiveKit testing, run `bash scripts/livekit-dev.sh start`, then source
`eval "$(bash scripts/livekit-dev.sh env)"` before `npm start`. No second backend or
gateway process is required.

For Agora, set `AGORA_APP_ID` and `AGORA_APP_CERTIFICATE` on `demo-server`.
`AGORA_TOKEN_TTL_SECONDS` defaults to 600 seconds. The server uses AccessToken2
and never exposes the App Certificate. No Agora credential belongs in Flutter
or in `--dart-define` values.

The current Chime adapter guarantees `participant` rooms only. If the server UI
is switched to Chime and the client requests `host` or `viewer`, the reference
server returns a typed error instead of silently falling back to LiveKit.

## Error shape

```json
{
  "contractVersion": 1,
  "error": {
    "code": "room-not-found",
    "message": "The requested room was not found.",
    "details": {}
  }
}
```

`details` is optional. Clients also understand the older demo shape where
`error` is a plain string.

| Code | Suggested HTTP status | Flutter `MediaBackendErrorCode` |
| --- | ---: | --- |
| `unauthorized` | 401 | `unauthorized` |
| `forbidden` | 403 | `forbidden` |
| `room-not-found` | 404 | `roomNotFound` |
| `room-exists` | 409 | `roomConflict` |
| `bad-room-code` | 400 | `invalidRoomCode` |
| `unsupported-provider` | 400 | `unsupportedProvider` |
| `provider-not-configured` | 503 | `providerNotConfigured` |
| any other `4xx` | 400 | `invalidArgument` |
| any `5xx` | 500 | `serverError` |

Transport and timeout failures map to `network` and `timeout` respectively.

## Role and permission guarantees

Client-side roles are a convenience; **the backend is the security boundary**.

- `viewer` credentials must be issued without media publish permission. The
  LiveKit adapter additionally exposes no publish method on
  `BroadcastViewerSession`, but that alone does not protect the room.
- `host` credentials must be allowed to publish audio and video.
- The server should scope each token to the requested room, keep the TTL short,
  and log/reject attempts to join a room the role was not issued for.

## Provider notes

| Provider | Room lifetime | Billing notes |
| --- | --- | --- |
| LiveKit (self-hosted) | Auto-created on first join; empty rooms cost nothing | No per-minute charge; you pay for the host |
| LiveKit Cloud | Same | Metered in participant-minutes; the free Build tier has hard monthly caps |
| AWS Chime | Explicitly created and must be deleted after use | Attendee-minutes bill while someone is in the meeting; delete the meeting to stop future joins |

## Backend responsibilities

A production backend owns authentication, authorization, rate limiting, room
policy, persistence, provider credential configuration, and (for Chime) AWS IAM
setup. The existing `demo-server` is a development/reference implementation
only; it is not a production deployment template.
