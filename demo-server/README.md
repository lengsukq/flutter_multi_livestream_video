# Demo backend (keys stay here, never in Flutter)

`npm start` is the **single application-backend entry point** for the demo. It
serves the Flutter room API and the browser dashboard used to switch newly
created rooms between AWS Chime, LiveKit, Agora, Tencent TRTC, and Alibaba ARTC
at runtime.

## Run

The demo server uses Node's native erasable-TypeScript support and requires
Node.js 22.18 or newer. No transpile/build step is required for local use.

```bash
cd demo-server
npm install
AWS_PROFILE=chime-demo npm start
# or: PORT=3000 CHIME_MEDIA_REGION=ap-southeast-1 AWS_PROFILE=chime-demo npm start
```

`npm start` loads an optional local `.env` file. Keep that file out of version
control; the repository ignore rule already excludes it.

Static type checking and tests:

```bash
npm run typecheck
npm test
# or both
npm run check
```

Optional demo authentication:

```bash
DEMO_BEARER_TOKEN=my-local-token AWS_PROFILE=chime-demo npm start
```

When `DEMO_BEARER_TOKEN` is set, room connection endpoints require
`Authorization: Bearer <token>`. This is only a reference hook for exercising
`MediaClient.tokenProvider`; it is not a production identity system.

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

## Provider adapter architecture

The demo server now follows the same plugin-style boundary as the Flutter SDK:

```text
server.ts
   |
   +--> ProviderRegistry
   |       +--> providers/chime.ts
   |       +--> providers/livekit.ts
   |       +--> providers/agora.ts
   |       +--> providers/trtc.ts
   |       `--> providers/artc.ts
   |
   `--> RoomDirectory
```

`server.ts` owns HTTP contract handling, authentication hooks, provider
selection, room lifecycle orchestration, logging, and the dashboard. Provider
modules own SDK calls, credential signing, role rules, join payloads, cleanup,
and provider-specific room summaries.

Shared contracts live in `types.ts`. `ProviderRegistry` accepts only objects
that satisfy `ProviderAdapter`, so missing create/join/close/summary behavior
or incompatible join responses fail during `npm run typecheck`.

The `RoomDirectory` stores the application room-code-to-provider binding, so a
runtime provider switch only changes newly-created rooms. Chime may additionally
register its native meeting id as an alias for the legacy endpoints.

### Add another RTC provider

To add a fifth provider, create one module under `providers/` implementing the
adapter contract and register it once in `server.ts`:

```ts
const provider: ProviderAdapter = {
  id: 'vendor',
  displayName: 'Vendor RTC',
  isConfigured: () => true,
  supportsRole: () => true,
  async createRoom({ roomCode, role }) { /* ... */ },
  async joinRoom({ entry, rawName, role }) { /* ... */ },
  async closeRoom({ entry, reason }) { /* ... */ },
  summarizeRoom(entry, { host }) { /* ... */ },
}
```

Optional hooks include `metadata`, `aliases`, `removeAttendee`,
`refreshCredentials`, and `resolveExternalRoom`. The main create/join/close
routes do not require provider-specific `if`/`switch` branches. The dashboard
renders provider buttons and room labels from `/api/overview.providerList`, so
new adapters do not need a dedicated dashboard button.

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

## Public Vercel deployment

The server can be deployed from this directory as an Express Vercel Function.
The dashboard HTML lives in `public/index.html` and is bundled with the
function. Set the Vercel project root to `demo-server`.

Before a public deployment, configure a strong `MEDIA_ADMIN_PASSWORD`. The
dashboard requires this password, then uses an HttpOnly, Secure, SameSite
admin cookie. Management endpoints are same-origin only. The media API enables
CORS by default and allows the contract and Authorization headers, so a Flutter
app hosted on another origin can call it. Browser admin cookies are deliberately
not enabled for cross-origin requests.

`MEDIA_CONNECTIONS_ENABLED=false` makes room creation, joining, credential
refresh, leave, heartbeat, and legacy connection endpoints return HTTP 503.
On Vercel, environment changes apply to a new deployment, so pausing or
resuming through this setting requires redeploying. Deploy publicly with this
setting `false`, then set it to `true` only when ready to accept connections.

This demo server keeps room bindings and activity logs in process memory. Vercel
Functions can run on different instances, so keep public connections paused
until `RoomDirectory` is backed by shared persistent storage. The admin
dashboard remains available while connections are paused.

## Env

| var | default | note |
|---|---|---|
| `AWS_PROFILE` | — | must be `chime-demo` (least-privilege IAM) |
| `AWS_REGION` | `us-east-1` | Chime control plane |
| `CHIME_MEDIA_REGION` | `ap-southeast-1` | media region near CN |
| `PORT` | `3000` | — |
| `DEMO_BEARER_TOKEN` | unset | optional bearer token for room API demos |
| `MEDIA_ADMIN_PASSWORD` | unset | required on Vercel; protects the management dashboard and admin endpoints |
| `MEDIA_CONNECTIONS_ENABLED` | `true` locally, `false` on Vercel | set `false` to reject room connection requests; Vercel requires a redeploy after changes |
| `MEDIA_DEFAULT_PROVIDER` | `chime` | default provider for new rooms; on Vercel set this in the project environment |
| `LIVEKIT_URL` | unset | LiveKit Cloud/server WebSocket URL |
| `LIVEKIT_API_KEY` | unset | server-side LiveKit API key |
| `LIVEKIT_API_SECRET` | unset | server-side signing secret; keep it in the ignored `.env` |
| `LIVEKIT_TOKEN_TTL_SECONDS` | `600` | short-lived LiveKit token lifetime |
| `AGORA_APP_ID` | unset | public Agora App ID returned in Agora join payloads |
| `AGORA_APP_CERTIFICATE` | unset | server-only Agora signing secret; never return it to Flutter |
| `AGORA_TOKEN_TTL_SECONDS` | `600` | AccessToken2 lifetime in seconds, clamped to 60–86400 |
| `TRTC_SDK_APP_ID` | unset | public TRTC SDKAppID returned in join payloads |
| `TRTC_SDK_SECRET_KEY` | unset | server-only UserSig/PrivateMapKey signing secret; never return it to Flutter |
| `TRTC_TOKEN_TTL_SECONDS` | `600` | UserSig and PrivateMapKey lifetime; accepted range is 60 seconds–90 days |
| `ARTC_APP_ID` | unset | public ARTC AppID returned in join payloads |
| `ARTC_APP_KEY` | unset | server-only ARTC token-signing key; never return it to Flutter |
| `ARTC_TOKEN_TTL_SECONDS` | `600` | ARTC token lifetime; accepted range is 60–86400 seconds |

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

For TRTC, put `TRTC_SDK_APP_ID` and `TRTC_SDK_SECRET_KEY` in the ignored
`.env` or server environment. Enable **Advanced Permission Control** for that
SDKAppID in the Tencent RTC console; without it, TRTC will not enforce the
PrivateMapKey grant. `participant` rooms use the video-call scene, while
`host`/`viewer` rooms use the live scene. Scene choice is fixed when the room
is created, so the backend rejects cross-scene joins. Viewer PrivateMapKeys
allow room entry and receiving main-stream audio/video, but omit audio/video
publish and screen-share rights. The optional
`POST /rooms/{roomCode}/credentials/refresh` route only renews credentials for
an existing attendee with the same identity and role. The Flutter adapter
renews before ticket expiry and rejoins with the same user id.

For ARTC, set `ARTC_APP_ID` and `ARTC_APP_KEY` in the ignored `.env` file or
server environment. The server signs short-lived, single-parameter ARTC auth
information; the AppKey is never returned to Flutter. `participant` rooms use
communication mode, while `host`/`viewer` rooms use interactive live mode.
The backend locks a room to its creation mode and authorizes credential refresh
only for the same attendee and role. ARTC's signed token does not encode
viewer-versus-streamer permissions: role is selected by the client SDK. The
viewer adapter surface is subscribe-only, but this is not a server-enforced
security boundary against a modified client.

## Scope

This server is a reference implementation for running the example and
validating backend contract v1. It intentionally uses in-memory room state;
restarting the process clears that directory. A public Vercel deployment must
remain paused until shared room persistence and production monitoring are added.
