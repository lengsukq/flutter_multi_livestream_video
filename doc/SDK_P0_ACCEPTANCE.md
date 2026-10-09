# P0 Frontend SDK Verification / 前端 SDK 验收记录

## Scope / 范围

`flutter_realtime_sdk` is the application-facing Flutter SDK. The in-repository
`example` is the only existing app integration. No legacy root-plugin or old
public-API compatibility is required. Provider SDKs and native bridges belong
behind the SDK. Demo Server only provides optional room provisioning,
authorization, and short-lived credentials; no long-lived provider secret may
be embedded in Flutter.

## P0-1: Lifecycle and error handling

- LiveKit: leaving while `Room.connect` is still pending now tears down the
  engine without awaiting a potentially unresolved join. Late joins fail with
  `cancelled` instead of marking an ended room connected. See
  `packages/flutter_realtime_media_livekit/test/livekit_fault_test.dart`.
- TRTC: the same pending-enter cancellation/late-result protection is covered
  by the fake-engine regression in `trtc_session_lifecycle_test.dart`.
- Agora RTC: leaving during initialization cancels the join, suppresses late
  `onJoinChannelSuccess`, and releases the native engine; a `TimeoutException`
  now maps to the public `timeout` code. Covered by `agora_fault_test.dart`.
- Chime: a late provider snapshot cannot move an ended SDK meeting back to
  `connected`; covered by the fake delayed meeting session in
  `chime_adapter_test.dart`.
- IVS Stage and ARTC: leaving while the native engine is joining cancels the
  pending operation and rejects late completion. Covered by
  `ivs_session_contract_test.dart` and `artc_adapter_test.dart`.
- Agora Chat, IVS Chat, Tencent Chat: pending connect operations are cancelled
  by disconnect/dispose; late connection, message, deletion, and error events
  are ignored after teardown. See each `*_chat_session_contract_test.dart`.
- `Cleanup.finish(cause: ...)` preserves the primary error classification when
  rollback also fails, with secondary stages in `details.cleanupFailures`.
  Standalone disposal without a primary error still throws `cleanupFailed`.
- All available package unit tests run through `scripts/check_sdk_quality.py`.
  These checks do **not** establish real-network reliability for every vendor.

## P0-2: Single SDK entry point and Demo

- Demo screens import the public `flutter_realtime_sdk` library and open
  Meeting/Live/Standalone Chat via `Realtime.standard` and `Realtime.open`.
  Other public surfaces include `RealtimeSdk`, pre-join probes, previews,
  room controls, and direct provider-credential entry.
- Demo error text consumes public `RealtimeException` fields and translates
  recovery actions for English/Chinese. A widget regression test covers this.
- Demo room discovery refreshes when provider, concrete engine, room mode,
  attendee count, or creation time changes, not only when room IDs differ.
- `provider_platform_matrix_test.dart` enumerates every SDK platform, compares
  the resolved supplier catalog with registered drivers, checks typed
  unsupported-platform fallbacks, and asserts AWS Meeting→Chime / Live→IVS.
- Room UI, classroom interactions, moderation and video processing still need
  live provider-by-provider/device-by-device functional confirmation.

## P0-3: Platforms and release gates

Run locally at the repository root unless a working directory is indicated:

```bash
python3 scripts/check_sdk_architecture.py
python3 scripts/format_sdk.py --check
python3 scripts/check_sdk_quality.py --analyze
python3 scripts/check_sdk_quality.py --test
(cd example && flutter analyze --no-pub)
(cd example && flutter test --no-pub)
(cd example && flutter build web --debug)
(cd example && flutter build apk --debug)
(cd example && flutter build macos --debug)
(cd example && flutter build ios --no-codesign)
(cd demo-server && npm run check)
```

Initial validation on 2026-10-09: SDK dependency graph, all 36 package
analyses, existing package tests, Demo analyze/widget tests, Web Debug,
Android Debug APK, macOS Debug, and the unsigned iOS device-target build
passed. Re-run after subsequent changes before calling the branch green.
The subsequent final local test sweep also passed: Demo Server TypeScript
typecheck plus 66 Node tests, and 30 JavaScript Web/desktop bridge tests.
The 36 package analyses, package test inventory, and Demo analyze/widget tests
were rerun successfully after the lifecycle and error-handling changes.
The additional mocked lifecycle and platform catalog regressions were included
in the successful package test sweep. They verify cancellation and state
contracts, **not** actual video/audio negotiation over vendor networks.

### Known limitations / 尚未通过或未验证

| Target | Current evidence | Follow-up |
| --- | --- | --- |
| iOS simulator | **Blocked:** `AliVCSDK_ARTC.framework` is built for physical iOS, not simulator. | Obtain a vendor simulator XCFramework or build a simulator configuration that excludes the native ARTC dependency. Do not claim simulator coverage. |
| Windows | Windows CI build job exists; not run on this macOS host. | Confirm on Windows runner, including provider selection and native assets. |
| Web Wasm | Standard Web Debug builds; transitive `dart:ffi` dependencies produce Wasm dry-run warnings. | Verify only if Wasm support is declared. |
| Live service E2E | Not run without service credentials/devices. | Two real clients, room lifecycle, chat, host operations, permission failures, screen sharing, processed frames; keep credentials outside the repository. |
| SwiftPM | Third-party plugins warn about incomplete SPM support; CocoaPods/device builds work. | Track upstream dependencies; do not treat a warning as verified future SPM compatibility. |
| Android standalone Gradle tests | Direct Gradle invocation cannot find a Java runtime in the current shell, although `flutter build apk --debug` passes. | Set a valid Java 17+ toolchain (`JAVA_HOME`) before running the dedicated native-effects Gradle task. |

Before the plan is considered **fully complete**, record the actual results
for each advertised provider × platform × Meeting/Live/Chat role, with
supported/conditional/unsupported explanations in the SDK capabilities and
Demo, and exercise all non-stub integrations against live vendor services.
