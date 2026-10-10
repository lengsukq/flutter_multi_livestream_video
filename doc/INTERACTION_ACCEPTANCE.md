# Interaction delivery and acceptance — 2026-10-08

## Updated package/UI verification — 2026-10-10

The optional Classroom and Live presets are now independent packages.
`RealtimeRoom` no longer hard-imports their business cores, whiteboard or
screen-annotation controllers. Demo explicitly selects both presets and adds
a `demo.reaction.wave` interaction built only on generic `room.interactions`.
Existing Classroom/Live behavior remains in the respective SDK preset packages;
the Demo owns only composition and event presentation.

| Local verification, current worktree | Result |
| --- | --- |
| Runtime `flutter test --no-pub` | 45 passed |
| Public SDK `realtime_client_test.dart` | 54 passed |
| SDK UI `flutter test --no-pub` | 19 passed |
| Demo `flutter test --no-pub` (including custom wave and connection E2E) | 16 passed |
| Reference backend `npm run check` | TypeScript check + 74 passed |
| `flutter analyze --no-pub`: Runtime, SDK, SDK UI, Demo and optional presets | Passed |
| Demo `flutter build web --release --no-pub` | Passed (standard JavaScript Web, 2026-10-10) |
| WebAssembly readiness dry run | Tencent Chat native FFI warnings; not accepted for Wasm |
| Demo `flutter build apk --debug --no-pub` | Passed (Android Debug APK, 2026-10-10) |
| Android Kotlin plugin migration | Legacy KGP warning for `flutter_webrtc` / `livekit_client`; future Flutter compatibility still pending |
| Demo `python3 scripts/build_flutter_macos.py --release --no-pub` | Passed (macOS Release .app, 2026-10-10) |
| macOS SwiftPM migration | Warnings for provider plugins still using CocoaPods; not equivalent to completed SwiftPM migration |
| Demo `flutter build ios --release --no-codesign --no-pub` | Passed (iOS unsigned device Release .app, 2026-10-10) |
| iOS SwiftPM / device installation | Several Provider plugins still use CocoaPods; no code signing or physical device installation in this run |
| `scripts/check_sdk_architecture.py` (40-package dependency graph) | Passed; no mandatory business presets |
| Real RTC/IM on two devices, remote media pixels and Windows native build | Not verified in this run |

These are **separate suite sizes, not an aggregate release test count**; the
Runtime suite imports optional presets as development dependencies. Widget
tests and reference-backend tests use fakes or mock media, not production
provider credentials. All work is in the current uncommitted worktree, not a
published SDK release. The remainder of this document retains historical
2026-10-08 delivery evidence and caveats.

## Status snapshot and reading guide

This record describes the 2026-10-08 working tree, including uncommitted
implementation. It is not a published release or completed vendor acceptance.
The first verification table records the earlier interaction implementation.
The whiteboard delivery below records its own current regression and build scope;
the two test totals overlap and must not be added together.

For the full requirement-by-requirement table, four-platform feature status,
Windows registration boundaries and teacher screen-share matrix, see
[SDK capability matrix (Chinese)](../SDK_CAPABILITY_MATRIX.zh-CN.md#教学工具与直播互动)
or [English](../SDK_CAPABILITY_MATRIX.md#teaching-tools-and-live-interactions).

## Delivered in SDK

- Classroom hand/Q&A/roster/speaking V1 and optional tools UI.
- Announcements, focus reminders, homework publication, material links,
  session attendance and server-deadline timers.
- Single-choice Quiz/Poll with answer replacement, teacher results and student
  correct-answer hiding until close.
- Independent Live gift SDK, events/totals and retry UI without payments.
- Shared-content annotations: pen/highlight/circle/arrow/text/undo/clear,
  normalized content coordinates and server-authorized canvas state.
- Independent Chat choice for AWS Live, matching other media vendors.
- CI includes the classroom and Live interaction packages.

The Demo only opens the common SDK room view. Its backend is a reference
control plane with transient new interaction state. Storage and recording are
out of scope. Existing optional legacy classroom persistence is not a new tool
storage implementation.

## Evidence boundaries

Automated tests cover Core/UI state, permissions, idempotent retries, rejected
stale canvases, Quiz answer redaction, leave/rejoin attendance, bounded message
isolation and phone layouts. A local HTTP test provisions one teacher with two
students and one host with two viewers against a **mock LiveKit control
service**. It proves reference protocol authorization and synchronization, not
media transport, actual vendor Chat, microphone enforcement or remote pixels.

Builds are recorded separately from this protocol evidence. Standard JavaScript
Flutter Web is supported; the full SDK still has upstream Tencent Chat Wasm
incompatibilities. ARTC macOS still requires its official native framework for
that provider to be usable.

## Earlier interaction verification recorded

| Check | Result |
| --- | --- |
| Reference backend typecheck and 55 tests | Passed in implementation run |
| Classroom Core/UI and Live Core/UI tests | Passed |
| All relevant Dart/Flutter tests including Classroom/Live/SDK/Chat/Media UI/Demo: 156 | Passed in implementation run |
| Core/UI/SDK/Demo static analysis | Passed |
| Standard JavaScript Web release | Built |
| Android debug APK | Built |
| iOS device release, no signing | Built |
| macOS release with scoped CocoaPods configuration | Built |
| Both lightweight Web samples and provider-pruning check | Passed |
| Generated SDK declaration freshness | Passed |
| Real vendor Chat / remote annotation pixels / physical multi-device enforcement | Pending |

**Recorded total: 55 backend + 156 Dart/Flutter = 211 passing tests.** The
Classroom/Live package tests are included in 156, not additional counts.
CI has been configured; this record does not claim a completed remote CI run.

The Demo manifest enables SwiftPM for iOS-only IVS plugins. On this Flutter
version its explicit setting overrides `FLUTTER_SWIFT_PACKAGE_MANAGER=false`.
macOS Iris linkage therefore uses a temporary **project** CocoaPods override,
restored after building; global Flutter settings are unchanged. Reproduce with
`python3 scripts/build_flutter_macos.py --release --no-pub` from the repository.
The same helper is used by the macOS CI build.

## Remaining implementation and coverage gaps

| Gap | Current boundary | Follow-up |
| --- | --- | --- |
| Material upload | Existing links and host uploader interface only | File selection, actual upload integration and optional embedded preview; storage remains host-owned |
| Recording/replay | Deferred; neither implemented | Separate future recording and replay scope |
| Forced speaking permissions | LiveKit control-plane implementation only; real media pending | Enforce other vendors through their actual permission APIs before claiming forced mute |
| Native teacher screen sharing | LiveKit is the first path; TRTC Android/iOS calls exist; others have gaps | Extend the missing adapter/platform paths and validate devices |
| iOS cross-app capture | LiveKit explicitly uses in-app capture without Broadcast Extension | Implement/configure the whole-screen path if required; validate TRTC's complete iOS flow |
| System annotation layer | SDK system-window adapters now exist for Android/macOS/Windows/X11; builds and native acceptance differ | See SYSTEM_SCREEN_ANNOTATION_SDK.md for platform evidence and remaining real-device/remote-pixel checks |
| Roster media flags | Unknown when vendor telemetry is absent | Improve applicable adapter telemetry without inventing enabled/disabled states |
| Windows | Some media/Chat drivers registered, but this run has no native build evidence | Use a Windows runner for builds and new interaction acceptance |
| Real vendor/platform combinations | Mock protocol tests and builds only for this delivery | Complete the multi-device checklist below, including remote pixels and cleanup |

Homework submission/grading, formal absence rules, server-wide chat analytics
and cross-course history are future extensions, not promised completions of
this room-lifecycle SDK prototype. New tool/gift state remains transient;
legacy optional classroom persistence must not be described as new tool storage.

## Real-device checks still required

Run each configured provider with one teacher and two students, or one host and
two viewers, across Web, Android/iOS and macOS:

1. Send product Chat in both directions as a viewer. Change dashboard providers
   and confirm existing rooms stay bound to their original media/Chat pair.
2. Publish announcement, focus reminder, homework and material link; verify the
   two students receive the same state, and a late joiner receives it too.
3. Submit and change Quiz/Poll answers on both students. Confirm hidden answers,
   teacher counts, close behavior and post-close results.
4. Join/leave/rejoin and interrupt the network; verify roster, attendance and
   deadlines restore without duplicate events or treating unknown media flags
   as enabled. Compare clocks if synchronized timer displays differ.
5. Gift from both viewers. Retry one timed-out submission with the same event
   ID; verify shared totals and no duplicate animation/count. Disconnect host
   and confirm submission errors remain visible.
6. Share on an adapter/platform that advertises sharing. Draw all tools, undo
   and clear. Compare remote coordinates on phone/tablet/desktop, portrait and
   landscape, letterboxes and changing share sources. Verify an in-progress
   stroke syncs, stale-canvas writes fail, and reconnect restores marks.
7. For LiveKit, verify actual audio publishing is denied before approval,
   enabled after teacher grant, and removed after revoke/reconnection. Other
   adapters remain advisory unless separately implemented and validated.

Unsupported combinations stay `unsupported`; device/provider checks that have
not been run stay `pending`. Follow [real-call acceptance](ACCEPTANCE.md) for
sanitized evidence and provider resource cleanup. Local leave does not prove
cloud-room deletion.

## Independent whiteboard delivery — 2026-10-08

Implemented two independent Whiteboard packages, a replaceable/local repository,
page lifecycle, shared annotation rendering and the SDK content controller/stage.
The Meeting Demo uses one content menu; students follow teacher modes/pages.
Legacy backend sharing and annotation imports/widgets remain available. Both new
packages are included in CI. See [public APIs and integration](WHITEBOARD_SDK.md).

Current targeted regression scope:

| Suite | Passing tests |
| --- | ---: |
| Whiteboard Core | 5 |
| Whiteboard UI | 4 |
| Classroom Core / UI | 8 / 6 |
| SDK Base / full SDK | 10 / 66 |
| Media UI | 41 |
| Media Core / Chime / Web ownership (VM) | 97 / 10 / 1 |
| Demo | 1 |
| Reference backend with typecheck | 57 |
| **Total in this delivery scope** | **306** |

These 306 checks overlap the earlier 211-check scope; this is not additional checks to add to the earlier total. Backend HTTP coverage uses a mock LiveKit service: teacher plus
two students, read-only authorization, mode/page following, repeated requests,
stale targets, and leave/rejoin recovery of current page/marks. Local Core tests
cover all drawing tools, page limits and deletion selecting the preceding page.
UI tests cover all tools on whiteboard and screen surfaces, read-only affordances,
portrait/landscape/desktop letterboxes and inverse zoom coordinates. The screen
background widget stays mounted during mark updates. Media UI tests confirm mark updates retain camera tiles. Controller
tests cover selection cancellation, failed stop, failed commit, rollback failure
and retries without automatic recapture, and avoid camera/microphone API calls.

Static analysis passed for Whiteboard Core/UI, Classroom Core/UI, SDK Base/full
SDK, Media Core/UI, Chime/Web adapters and Demo. Standard JavaScript Web release, Android debug APK and
unsigned iOS device release built from the final source. macOS release uses the
scoped CocoaPods helper. Both lightweight Web examples retain provider pruning;
generated capability declarations and whitespace checks are current.

**Still pending:** real vendor screen selection/capture, remote annotation pixels,
physical device orientation changes, native overlay composition, and multi-device
network recovery. Screenshot/coordinate unit tests, mock protocol checks and builds
are not evidence that those device/provider scenarios have passed. Whiteboard
state remains transient in the reference backend. At the time of that delivery,
system desktop overlays were deferred; the newer system annotation delivery is
recorded in SYSTEM_SCREEN_ANNOTATION_SDK.md. Custom per-frame video composition,
courseware import, storage and recording remain deferred.

Chime content tracks keep their native modality ID while an optional content-owner
interface maps them to the teacher. Existing track implementations continue to
use participantId without implementing the optional interface. Web profiles apply
the mapping only for Chime screen tracks. This is unit/build evidence, not a real
Chime shared-screen acceptance.


## Review fixes verification — 2026-10-08

This verification covers the current working tree's four review fixes. Its tests
overlap earlier delivery records; the totals must not be added to earlier totals.

- Agora/Tencent/IVS Chat escape and restore ordinary reserved-prefix text. Only
  structurally valid versioned envelopes enter system hints; malformed frames
  remain ordinary messages. Hints still cannot authorize state changes.
- Classroom/Live automatic reads merge hints and polling into one in-flight read,
  with a one-second cooldown and at most one queued trailing read. Explicit
  refreshes and action responses remain immediate. Controlled-time tests cover
  bursts, blocked reads, polling and disposal; transport tests cover domain isolation.
- Fresh participant identities reset hands/grants and receive restricted tokens.
  Old LiveKit identities are revoked first, using retained presence history even
  after heartbeat pruning. Failed revocations reject replacement. Same-identity
  snapshots retain grants; legacy persisted grants without matching participant
  bindings are cleared. Old grant event replays cannot authorize the new identity.
- Room queues serialize permission updates with snapshots, joins, leaves, removal
  and closing. Mock RTC tests hold provider responses to verify ordering, retries,
  remote failures and post-close validation. Queue tests prove other rooms proceed.
- Quiz answer choices derive from actual options; removal clears the selection.
  Widget tests cover two/eight options, blank lines, duplicates, removed answers
  and retaining form input after validation or publication errors.

| Check | Result |
| --- | --- |
| Reference backend typecheck and complete suite | 66 tests passed |
| Chat Core/Agora/IVS/Tencent | 15 / 4 / 9 / 5 tests passed |
| Classroom Core/UI | 8 / 9 tests passed |
| Live Core/UI | 3 / 1 tests passed |
| SDK Base/full SDK/Media UI | 12 / 66 / 41 tests passed |
| Static analysis of all eleven packages above | No issues |
| SDK declaration freshness and diff whitespace | Passed |

Recorded run: **66 backend + 173 Dart/Flutter = 239 passing tests**.
No new application builds were run for these fixes. Real LiveKit multi-device
microphone publication, revoke/reconnect behavior and actual vendor Chat remain
**pending**; local mocked control responses and widget/unit tests are distinct
from that acceptance. The reference server queue is process-local, not a shared
multi-instance transaction mechanism.
