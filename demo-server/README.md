# Demo backend (keys stay here, never in Flutter)

`npm start` is the **single application-backend entry point** for the demo. It
serves the Flutter room API and the browser dashboard used to switch newly
created rooms between AWS Chime, LiveKit, and Agora at runtime.

## Run

```bash
cd demo-server
npm install
AWS_PROFILE=chime-demo npm start
# or: PORT=3000 CHIME_MEDIA_REGION=ap-southeast-1 AWS_PROFILE=chime-demo npm start
```

`npm start` loads an optional local `.env` file. Keep that file out of version
control; the repository ignore rule already excludes it.

Optional demo authentication:

```bash
DEMO_BEARER_TOKEN=my-local-token AWS_PROFILE=chime-demo npm start
```

When `DEMO_BEARER_TOKEN` is set, `/rooms` endpoints require
`Authorization: Bearer <token>`. This is only a reference hook for exercising
`MediaClient.tokenProvider`; it is not a production authentication system.

Health check:

```bash
curl http://localhost:3000/health
```

Dashboard:

```text
http://localhost:3000/
```

Switching the dashboard provider affects **new rooms only**. Existing room
codes stay bound to the provider that originally created them.

## Room flow used by the example app

The current `example/` app consumes the provider-neutral `MediaClient` API and
uses the language-neutral contract documented in
[`../MEDIA_BACKEND_CONTRACT.md`](../MEDIA_BACKEND_CONTRACT.md):

1. App: `POST /rooms {"nickname":"host","roomCode":"482913","role":"participant"}` — no provider field.
2. Server selects the current dashboard provider and returns `provider` plus provider-specific short-lived join data.
3. Guest: `POST /rooms/482913/join {"userId":"guest","role":"participant"}` — room code resolves the original provider.
4. Core resolves the matching adapter and starts the media session.
5. SDK sends heartbeat/leave through the same room contract.

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
| `LIVEKIT_URL` | unset | LiveKit Cloud/server WebSocket URL |
| `LIVEKIT_API_KEY` | unset | server-side LiveKit API key |
| `LIVEKIT_API_SECRET` | unset | server-side signing secret; keep it in the ignored `.env` |
| `LIVEKIT_TOKEN_TTL_SECONDS` | `600` | short-lived LiveKit token lifetime |
| `AGORA_APP_ID` | unset | public Agora App ID returned in Agora join payloads |
| `AGORA_APP_CERTIFICATE` | unset | server-only Agora signing secret; never return it to Flutter |
| `AGORA_TOKEN_TTL_SECONDS` | `600` | AccessToken2 lifetime in seconds, clamped to 60–86400 |

For local LiveKit Server testing:

```bash
bash ../scripts/livekit-dev.sh start
eval "$(bash ../scripts/livekit-dev.sh env)"
AWS_PROFILE=chime-demo npm start
```

For Agora testing, put the App ID and App Certificate in the ignored `.env`
or the server process environment:

```bash
AGORA_APP_ID=... AGORA_APP_CERTIFICATE=... npm start
```

The server signs Agora AccessToken2 credentials. `participant` and `host`
receive publish privileges; `viewer` is issued no audio/video/data publish
privileges and joins the Flutter SDK as an audience client. Agora only
server-enforces those fine-grained publish privileges when co-host
authentication is enabled for the Agora project, so production use must verify
that project capability before relying on it as a security boundary.

## Scope

This server is a local/reference implementation for running the example and
validating backend contract v1. It intentionally uses in-memory room state.
Restarting the process clears that directory.

It is **not** a production deployment template. Production authentication,
authorization, persistence, rate limiting, monitoring, AWS IAM configuration,
and infrastructure deployment are responsibilities of the application owner.
