# P1 Clean Code phase 1 — historical baseline

> Archived baseline from 2026-10-09. Several UI types named below were removed
> on 2026-10-15. For current APIs, use SDK_RUNTIME_INTEGRATION.zh-CN.md and
> UI_COMPOSABILITY_ACCEPTANCE.zh-CN.md. This record is not current integration guidance.

## Scope and unchanged behavior

This phase covers four independently testable areas: `MediaRoomView` (meeting,
live, members, chat, interactions), `example/lib/main.dart` (Demo view, identity,
diagnostics, room flows), `MediaPreJoinPage` (permissions, preview, settings,
asynchronous entry), and `demo-server/server.ts` (HTTP routers and services).
Do not introduce new provider-specific behavior into the Flutter Demo or UI.
Tokens and privileged provider operations remain in the backend.

The working tree is shared with concurrent changes. At baseline, branch
`codex/processed-video-stability` points to `eb10c511`. Several files are
modified, including `example/lib/main.dart`, the Pre-Join source/tests,
`media_room_view.dart`, and the untracked `meeting_room_layout.dart` and
`live_room_layout.dart`. Preserve these changes; never reset them as part of
the refactor. Separate feature commits should only stage verified changes.

## Before-refactor test baseline (2026-10-09)

| Check | Existing result | Notes |
| --- | --- | --- |
| `example/flutter test test/widget_test.dart` | 3 passed | Responsive homepage and SDK errors |
| `demo-server/npm test` | 67 passed | Provider routing, credentials, classroom, live |
| `flutter_realtime_media_ui/flutter test` | 19 passed, 27 failed | Uncommitted meeting/live UI diverged from older `media_room_view_chat_test.dart` selectors and assumptions; NOT a refactor regression |

Run scoped Pre-Join tests independently before touching its implementation.
Re-run the same commands after each module to separate pre-existing failures
from regressions. Do not mark real vendor/hardware E2E successful without
running it.

## After-refactor verification snapshot (2026-10-09, uncommitted worktree)

The following entries record **successful commands observed during this P1
work**, not all-platform or real-vendor acceptance:

| Verified scope | Result | Comparison |
| --- | --- | --- |
| `packages/flutter_realtime_media_ui/flutter analyze` | No issues | New independent Meeting/Live components analyze |
| Media UI room / Pre-Join / live interaction targeted tests | **50 / 50 passed** | Initial suite failures from old selectors and actual behavior defects were resolved |
| Pre-Join dedicated suite | **15 / 15 passed** | Includes resource release, device-result race and permission behavior |
| `demo-server/npm run typecheck` | Passed | Typed routers and injected Dashboard provider state compile |
| `demo-server/npm test` | **67 / 67 passed** | No known contract regression in the tested Node suite |

Two important changes are **functional fixes**, not just updated tests: a
meeting host was previously misidentified as a livestream host when
`roomMode` was absent, and Live danmaku/hearts rendered twice in the cached
video stage. A compact Meeting top-bar overflow at 390px was also fixed.

The P1 full integration gate remains separate: all-package tests/analyze,
Demo entry/navigation E2E, real-provider two-device RTC/Chat, Android/iOS
builds, processed video pixels, Windows runner and production-like server
resource cleanup must not be claimed completed from the above.

Read the [current P1 architecture and integration guide](P1_ARCHITECTURE_AND_INTEGRATION.zh-CN.md)
for the new module graph, typed layout and Pre-Join state boundaries, SDK
entry path, and remaining acceptance requirements.

## Dependency policy

* SDK UI depends on provider-neutral media/chat/core contracts, never vendor
  SDK APIs or Demo configuration.
* The Demo drives room creation, entry and diagnostics through public SDK APIs.
  Identity preferences belong in one persistence adapter, not a widget.
* Pre-Join manages preview ownership and releases media resources at most once.
  Failure retains the page and the option to retry; route replacement happens
  only after the connection succeeds.
* Demo Server retains one `npm start` entry, provider registry, and HTTP
  contract. Routers validate inputs and delegate to services; privileged
  credentials and room state remain server-side.

## Migration checkpoints

1. Extract independent controllers and keep UI interactions covered by tests.
2. Introduce explicit, narrowly typed dependencies from Meeting/Live layouts.
3. Split Demo identity, room flows and presentational widgets.
4. Remove unused Pre-Join implementation and isolate device/permission state.
5. Move Demo Server routes to feature routers; preserve public API contracts.
6. Run scoped tests, analyze/typecheck, and full regression with baseline
   comparison before reporting closure.
