# Demo backend (keys stay here, never in Flutter)

## Run

```bash
cd demo-server
npm install
AWS_PROFILE=chime-demo node server.mjs
# or: PORT=3000 CHIME_MEDIA_REGION=ap-southeast-1 AWS_PROFILE=chime-demo npm start
```

Optional demo authentication:

```bash
DEMO_BEARER_TOKEN=my-local-token AWS_PROFILE=chime-demo node server.mjs
```

When `DEMO_BEARER_TOKEN` is set, `/rooms` endpoints require
`Authorization: Bearer <token>`. This is only a reference hook for exercising
`ChimeClient.tokenProvider`; it is not a production authentication system.

Health check:

```bash
curl http://localhost:3000/health
```

## Room flow used by the example app

The current example consumes the public `ChimeClient` API. Internally it uses
the language-neutral backend contract documented in
[`../BACKEND_CONTRACT.md`](../BACKEND_CONTRACT.md):

1. Host: `POST /rooms {"nickname":"host","roomCode":"482913"}`
2. Guest: `POST /rooms/482913/join {"userId":"guest"}`
3. SDK parses `meeting` + `attendee` into `JoinInfo` and starts `ChimeMeetingSession`.
4. SDK sends `POST /rooms/482913/heartbeat` while the room session is active.
5. SDK sends best-effort `POST /rooms/482913/leave` on leave/dispose.

Legacy `/meetings` and `/join` endpoints remain in the demo server for
compatibility, but new Flutter integrations should use the room contract.

## Env

| var | default | note |
|---|---|---|
| `AWS_PROFILE` | — | must be `chime-demo` (least-privilege IAM) |
| `AWS_REGION` | `us-east-1` | Chime control plane |
| `CHIME_MEDIA_REGION` | `ap-southeast-1` | media region near CN |
| `PORT` | `3000` | — |
| `DEMO_BEARER_TOKEN` | unset | optional bearer token for room API demos |

## Scope

This server is a local/reference implementation for running the example and
validating backend contract v1. It intentionally uses in-memory room state.
Restarting the process clears that directory.

It is **not** a production deployment template. Production authentication,
authorization, persistence, rate limiting, monitoring, AWS IAM configuration,
and infrastructure deployment are responsibilities of the application owner.
