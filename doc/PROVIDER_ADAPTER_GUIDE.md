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

## Explicit lightweight composition

Applications should use `Realtime(providers: …)` from
`flutter_realtime_sdk_runtime` with optional provider bundles. Driver registration
and platform selection stay inside each bundle; Web resources are local to the
selected package. Custom adapters can expose `RealtimeProviderBundle` without
depending on an all-provider SDK. See the lightweight integration guide and
unified acceptance checklist in `doc/` (or the current documentation directory).

轻量接入保留统一请求、事件和房间类型；平台路由在注册包内部完成。
产品聊天缓存可配置，跨供应商服务端历史分页与真实连麦另行推进。

## Quality contracts

Use the public runtime library to register a bundle. Media and product Chat are independent. Add an optional `RealtimeProviderPlugin.effectsProbe` callback for processed-video capability; platform channels and input probes belong to the provider. An unregistered probe grants no additional effect capability. Failed probes are retryable and diagnostic.

Translate failures to the shared `RealtimeException`/`RealtimeErrorCode` contract. Keep third-party implementation imports in the documented native bridge boundary. Inject provider SDK construction for lifecycle fault tests. Disposal shares one future, attempts all resource stages and retains primary join failure plus rollback failures.
