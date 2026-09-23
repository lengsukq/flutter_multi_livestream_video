# ChimeClient integration guide

`ChimeClient` is the optional high-level layer on top of
`ChimeMeetingSession`. It removes HTTP/JSON/heartbeat boilerplate from Flutter
applications while keeping the existing low-level `JoinInfo` API available.

This repository does not deploy a backend for you. The application owner runs
or deploys a backend in any language that implements
[`BACKEND_CONTRACT.md`](BACKEND_CONTRACT.md).

## High-level integration

```dart
final client = ChimeClient(
  backendUrl: 'https://api.example.com',
  tokenProvider: () async => authService.accessToken,
);

final room = await client.joinRoom(
  roomCode: '482913',
  nickname: 'Leo',
);

try {
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        body: ChimeMeetingView(
          session: room.session,
          title: 'Room ${room.roomCode}',
          onLeave: () => Navigator.of(context).pop(),
        ),
      ),
    ),
  );
} finally {
  await room.dispose();
  client.dispose();
}
```

Create-and-join uses the same lifecycle:

```dart
final room = await client.createRoomAndJoin(
  nickname: 'Leo',
  roomCode: '482913', // optional
);
```

Keep `ChimeClient` alive until every `ChimeRoomSession` created from it has
been disposed. The room session uses the client's backend transport for
heartbeat and best-effort leave notifications.

## Authentication

`tokenProvider` supplies an application token:

```dart
final client = ChimeClient(
  backendUrl: 'https://api.example.com',
  tokenProvider: () async => authService.accessToken,
);
```

The SDK sends it as `Authorization: Bearer <token>`. This token is not an AWS
access key and is not the Chime attendee `JoinToken`.

For a different authentication scheme, use `headersProvider`:

```dart
final client = ChimeClient(
  backendUrl: 'https://api.example.com',
  headersProvider: () async => {
    'X-Tenant': currentTenant.id,
    'X-App-Session': await sessionToken(),
  },
);
```

The SDK always writes its own JSON content headers and backend-contract version
header after custom headers are resolved.

## Backend errors vs media errors

Backend/control-plane failures use `ChimeBackendException`:

```dart
try {
  final room = await client.joinRoom(
    roomCode: '482913',
    nickname: 'Leo',
  );
} on ChimeBackendException catch (error) {
  switch (error.code) {
    case ChimeBackendErrorCode.roomNotFound:
      // Show a room-not-found message.
      break;
    default:
      // Handle other backend failures.
      break;
  }
}
```

Native Chime meeting/media failures continue to use `ChimeException`. This
keeps backend/API problems separate from microphone, camera, native SDK, and
media-session problems.

## Heartbeat and leave lifecycle

`ChimeRoomSession` starts heartbeat automatically. Failures are surfaced on a
broadcast stream and do not terminate healthy media:

```dart
final subscription = room.backendErrors.listen((error) {
  debugPrint('Backend presence warning: $error');
});
```

Calling `room.leave()` leaves the Chime media session and sends the backend
leave notification. If UI code calls `room.session.leave()` directly (for
example through `ChimeMeetingView`), `ChimeRoomSession` observes the terminal
meeting state and sends the same best-effort notification.

`room.dispose()` is idempotent and waits for in-flight heartbeat/leave cleanup
before completing, so the owning `ChimeClient` can then close its transport
safely.

## Existing/custom backends

`ChimeClient` is optional. Existing applications can keep their own networking
and pass the response directly:

```dart
final response = await myApi.fetchChimeJoinInfo();
final session = ChimeMeetingSession();

await session.join(JoinInfo.fromJson(response));
```

This is the stable low-level API and remains independent of the standard
backend contract.

## Backend language

The backend does not use the Flutter package. It only implements the HTTP
contract and calls the AWS Chime control APIs. Typical choices include:

- Java / Spring Boot using AWS SDK for Java
- Python / FastAPI, Flask, or Django using boto3
- Node.js / Express or NestJS using AWS SDK for JavaScript
- Go or .NET using their AWS SDKs

All of them can serve the same Flutter client as long as they return the
contract's `meeting` and `attendee` payloads.

## Demo server

`demo-server/server.mjs` is a local/reference implementation of contract v1.
It includes room codes, heartbeat, idle cleanup, a dashboard, and an optional
`DEMO_BEARER_TOKEN` hook for exercising `tokenProvider`.

It intentionally remains a demo. Production persistence, authentication,
authorization, rate limits, deployment, monitoring, and infrastructure are the
application owner's responsibility.
