# Provider adapter guide

Add a realtime provider without changing Core or application business logic.

1. Create an adapter package that depends on Core plus the provider SDK. Core
   must never import the provider SDK.
2. Subclass `MediaJoinInfo` and validate the provider-specific backend block.
   Only short-lived participant credentials should reach Flutter.
3. Implement `MediaSessionFactory` with a stable lowercase `providerId`, real
   platform support, real supported roles, `parseJoinInfo`, and `createSession`.
4. Implement the narrowest session surface: `InteractiveMediaSession`,
   `BroadcastHostSession`, `BroadcastViewerSession`, and/or
   `MediaDataMessenger`.
5. Translate provider state, participants, tracks, messages, devices, and
   failures to Core models. Do not leak native/provider exceptions.
6. Wrap provider video handles in `MediaVideoTrack` and render them through an
   adapter-specific `MediaTrackRenderer`.
7. Implement `MEDIA_BACKEND_CONTRACT.md` in Node.js, Java, Python, Go, .NET, or
   any server stack. Authenticate users, select the provider server-side,
   persist the room-to-provider mapping, authorize room/role access, mint
   short-lived provider credentials, and keep API keys/secrets server-side.
8. Add offline contract tests for malformed join data, every declared role,
   unsupported roles, lifecycle idempotency, error mapping, capabilities,
   viewer publish isolation, track rendering, and data messaging.

Do not advertise a role or capability merely because a provider SDK exposes an
API. The backend must also be able to enforce the corresponding permission.
