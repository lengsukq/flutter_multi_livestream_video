# Chime Backend Contract v1

This document defines the optional HTTP contract used by `ChimeClient`. It is
language-neutral: a backend may be implemented in Java, Python, Node.js, Go,
.NET, or any other stack.

The Flutter package does **not** accept AWS access keys or secret keys. AWS
credentials stay on the application backend. The backend creates Chime meeting
and attendee resources, then returns short-lived join information to the app.
Media traffic connects from the native Chime SDK directly to Amazon Chime and
does not pass through this HTTP backend.

## Versioning

The current contract version is `1`.

The SDK sends this request header on contract calls:

```http
X-Chime-Backend-Contract: 1
```

Compatible servers should return the same header and may also include:

```json
{ "contractVersion": 1 }
```

Servers may accept requests without the version header for backward
compatibility. If a supplied version is unsupported, return HTTP `400` with
the standard error body below.

## Authentication

Authentication belongs to the application. When `ChimeClient` is configured
with a `tokenProvider`, it sends:

```http
Authorization: Bearer <application-token>
```

This is an application token, not an AWS credential and not the AWS Chime
`JoinToken`. Backends may use any authentication scheme by using
`headersProvider` instead.

## Join response

Create-and-join and join-room responses must contain `roomCode`, `meeting`, and
`attendee`. The `meeting` and `attendee` objects follow the AWS Chime SDK
response shape consumed by `JoinInfo.fromJson`:

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

Additional fields are allowed and ignored by the SDK.

## Endpoints

### `POST /rooms`

Create a room and create an attendee for the caller.

Request:

```json
{
  "nickname": "Leo",
  "roomCode": "482913"
}
```

`roomCode` is optional. A server may generate one. `nickname` is required by
the SDK convenience API. Success returns the join response above.

Recommended errors include `bad-room-code` (`400`) and `room-exists` (`409`).

### `POST /rooms/{roomCode}/join`

Create an attendee in an existing room.

Request:

```json
{ "userId": "Leo" }
```

Success returns the join response. A missing room should return
`room-not-found` with HTTP `404`.

### `POST /rooms/{roomCode}/heartbeat`

Best-effort presence signal used by `ChimeRoomSession`. The SDK calls this once
after joining and then at the configured heartbeat interval.

Request body may be empty JSON:

```json
{}
```

Example success:

```json
{ "contractVersion": 1, "ok": true, "roomCode": "482913" }
```

Heartbeat failure is reported on `ChimeRoomSession.backendErrors`; it does not
automatically terminate an otherwise healthy Chime media session.

### `POST /rooms/{roomCode}/leave`

Best-effort leave notification.

```json
{ "attendeeId": "..." }
```

The SDK may retry cleanup through normal lifecycle paths, so implementations
should make this endpoint safe to call more than once.

### `DELETE /rooms/{roomCode}`

Optional administrative operation exposed by `ChimeBackendClient.closeRoom`.
Applications are not required to expose this endpoint to ordinary clients.

## Error shape

Contract endpoints should use this form:

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

`details` is optional. `ChimeBackendClient` also understands the older demo
shape where `error` is a string, so existing demo integrations can migrate
gradually.

Common codes recognized by the Flutter SDK:

| Code | Suggested HTTP status | Flutter error |
| --- | ---: | --- |
| `unauthorized` | 401 | `unauthorized` |
| `forbidden` | 403 | `forbidden` |
| `room-not-found` | 404 | `roomNotFound` |
| `room-exists` | 409 | `roomConflict` |
| `bad-room-code` | 400 | `invalidRoomCode` |

Unknown `5xx` responses map to `serverError`; transport and timeout failures
map to `network` and `timeout` respectively.

## Backend responsibilities

A production backend is responsible for authentication, authorization,
rate-limiting, room policy, persistence if needed, and AWS IAM configuration.
Those concerns are intentionally outside this Flutter package.

The repository `demo-server` is only a reference implementation for running
the example and validating this contract. It is not a production deployment or
infrastructure template.
