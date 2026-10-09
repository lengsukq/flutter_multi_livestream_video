# SDK architecture, ownership and failures

The SDK quality refactor allows API changes and migrates the Demo alongside the packages. There is no compatibility layer for removed base/Lite or standalone Chime client APIs.

## Dependencies

Foundation is pure Dart. Domain cores depend on foundation and other required domain contracts. Runtime depends on cores and platform/processed-video controllers, with no bundled provider or built-in UI dependency. Provider bundles depend on runtime contracts and their adapters. SDK UI assembles domain views over runtime. The full SDK adds standard provider registration and SDK UI.

`Realtime(providers: …)` explicitly composes bundles; `Realtime.standard()` selects the full catalog. The connection, room, event and failure types are shared through the runtime's public library. Media and product Chat remain independently composable.

## Resource ownership

Sessions own connections and native resources. Room wrappers own subscriptions, shared-content coordination and the clients created for that room. UI owns input controllers, navigation and presentation subscriptions. Applications injecting HTTP clients retain ownership. A preview returned by `createLocalPreview()` must be disposed when cancelled or replaced.

Pre-Join defaults to microphone and camera off. Local preview factories must
defer camera capture until explicit enablement; device enumeration, background
selection and cancellation must not implicitly open it. The selected state is
preserved on room entry. In-app annotation tools float within the current
route's visible safe area and can be dragged outside the drawing canvas;
their overlay disappears with the owning surface.

Every cleanup stage is attempted in dependency order even when earlier stages fail. `CleanupFailure` records the stage, original failure and stack trace. `RealtimeException(cleanupFailed)` exposes an immutable failure list; its printable message contains stage names rather than native/HTTP payloads. Concurrent/repeated disposal shares a single future. Room/session `cleanupTimeout` controls the default ten-second stage limit. A timeout proves that a release attempt exceeded its limit; it does not prove a broken native resource was released.

Join failures retain the primary cause when rollback also fails. Closing owners reject new work and ignore late state callbacks. Internal serialization tails may consume errors already returned to the operation caller; detached UI callbacks require an explicit diagnostic owner.

## Network and protocol

A request deadline covers authentication headers, send, response body and JSON decoding. Timeout aborts the individual HTTP request. An authentication callback completing after cancellation cannot issue a late write. Non-success HTTP status classification remains valid for HTML or corrupt JSON responses. Successful malformed responses use `invalidResponse`.

The executors do not add automatic write retries. Typed classroom and whiteboard commands serialize only at repository boundaries, preserving the existing backend wire contract. Retries of a logical idempotent operation must preserve its event ID. Protocol readers report invalid fields and enums. Public collection-owning models and command payloads are defensive snapshots.

## Provider effects

`RealtimeProviderPlugin.effectsProbe` is an optional provider-owned role/platform probe returning `MediaBackgroundCapabilities`. Runtime does not infer support from a provider name or know a provider MethodChannel. Successful probes are cached per runtime instance and role; failed probes remain retryable and appear in runtime diagnostics. Optional effect failure does not prevent an ordinary preview. Protected publication still requires a compatible processed source and sink.

The LiveKit native external-track bridge is the one approved third-party internal import boundary. It targets the currently declared LiveKit version and the maintained Flutter WebRTC hotfix, and must be checked with native/processed-track tests when either dependency changes. Vendor source is not reformatted by SDK tooling.

## Validation

`scripts/sdk_packages.json` is the shared package inventory. Quality tooling analyzes and tests owned packages, including system annotation and new packages. Architecture checks reject cycles, UI/provider dependencies in runtime, duplicate root Chime implementation and cross-package internal imports outside the documented bridge.

Local tests and builds do not establish real-provider, multi-device, remote pixel, Windows or cloud cleanup acceptance. Those evidence categories remain separate in the acceptance documents.
