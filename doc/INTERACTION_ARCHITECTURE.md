# Interaction architecture (incremental migration)

## Ownership and dependency baseline

This is a frontend SDK, not a classroom or gifting product. Keep transport,
session lifecycle, capabilities and cross-provider adaptation in the SDK. Keep
the existing classroom and live interactions as **optional, prebuilt SDK
features**, not as rewritten Demo-only logic.

| Existing implementation | Current role | Target |
| --- | --- | --- |
| `media_core` `MediaSessionDataControl` | RTC Data send/receive and provider feature flags | Reuse as low-level transport; never claim all providers support data |
| `chat_core` `ChatSystemMessaging` | Chat-mediated revision hints | Reuse for hints only, not authenticated business commands |
| `classroom_core` `ClassroomSession`/`HttpClassroomRepository` | Hand raise, Q&A, speak grants, homework, announcements, timers | Preserve implementation as opt-in Classroom prebuilt feature |
| `live_core` `LiveInteractionSession`/`HttpLiveInteractionRepository` | Likes, gifts, catalog and counters | Preserve implementation as opt-in Live prebuilt feature |
| `sdk_runtime` `RealtimeClient` | Always recognizes `roomMode=meeting` and `liveInteractions=true` metadata, creates business sessions; depends directly on both cores | Explicitly selected features; make core independent of prebuilt business modules |
| `sdk_ui`, `classroom_ui`, `live_ui` | Composable room controls, overlays and panels | Entirely optional; no fixed navigation or UI required for headless features |
| `example/`, `demo-server/` | Showcase layouts and HTTP reference authority | Demo composes widgets; server remains optional reference for authoritative operations |

## Contract boundaries

1. **Transient event:** transport delivers a versioned, room-scoped envelope;
   the sender field in its JSON is *not* a trusted identity. Transport adapters
   validate the authenticated sender when the provider exposes one. Delivery
   is best-effort and does not establish authoritative shared state.
2. **Command:** application-specific actions requiring permission, billing or
   durability go through an injected trusted control plane. RTC Data / IM
   messages can notify clients to fetch the updated snapshot, but cannot
   authorize a teacher grant or debit currency.
3. **Snapshot:** late join and reconnection require a trusted state fetch and
   monotonically increasing revision. Countdown uses a server `endsAt`, not
   local timers as the source of truth.
4. **Plugin:** core exposes feature registration, lifecycle and capabilities
   without importing classroom, gift, HTTP or UI types. Prebuilt modules supply
   their existing repository and business behavior; consumers may register
   their own features.

## Incremental rollout

- P0: independent Dart interaction contract and codec with tests; runtime
  adapter to existing RTC transport; no breaking changes to prebuilt sessions.
- P1: feature registry, opt-in Classroom and Live adapters, shared UI as
  composable widgets, and Demo integration without duplicating business code.
- P2: security checks, two-client/late-join recovery, provider capabilities,
  complete docs and platform verification.

### Existing worktree

At plan start, the worktree already contains unrelated uncommitted Demo,
Pre-Join, Chat and UI edits, plus classroom notification overlay work. Keep
those changes intact; do not reset, overwrite or mix into refactor commits.
