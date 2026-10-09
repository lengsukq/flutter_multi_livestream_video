# Flutter Realtime SDK

Provider-neutral Flutter SDK for meetings, live media, product chat, classroom tools and shared content. The Demo uses the same public APIs as a host application.

## Entry points

| Package | Use |
| --- | --- |
| `flutter_realtime_sdk` | All bundled providers and ready-to-use UI; `Realtime.standard()` |
| `flutter_realtime_sdk_runtime` | Explicit provider composition; `Realtime(providers: …)` without built-in UI dependencies |
| `flutter_realtime_sdk_ui` | Optional room, classroom, live and whiteboard UI |
| `flutter_realtime_foundation` | Pure Dart errors, HTTP execution, cleanup and protocol validation |
| Domain Core packages | Independently composable Media, Chat, Classroom, Live and Whiteboard contracts |
| Provider bundles | Register only the selected media/chat drivers and local Web assets |

```dart
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';

final realtime = Realtime.standard(backendUrl: 'http://localhost:3000');
```

For explicit composition, import the runtime and selected bundle:

```dart
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_provider_livekit/flutter_realtime_provider_livekit.dart';

final realtime = Realtime(providers: [createLivekitProvider()]);
```

Add the SDK UI separately when using the runtime with the ready-to-use views. Existing base/Lite and legacy standalone Chime client APIs were removed during the quality refactor; this repository is the source of the current Demo and package APIs.

## Architecture and behavior

Runtime coordinates provider-neutral rooms. Providers own native APIs, platform support and processed-video input probes. UI packages render immutable state and delegate member operations, unread tracking and device initialization to controllers. Classroom revisions are invalidation hints; backend state remains authoritative.

Media and product Chat can be selected independently. RTC data Chat is available only with complete send/receive capability. Unsupported controls remain gated. Selected protected camera effects never silently fall back to publishing the raw camera.

All domains use `RealtimeException` and `RealtimeErrorCode`. Backend request deadlines include credential callbacks and response streaming. SDK-owned clients are closed by the SDK; injected clients remain caller-owned. Cleanup attempts every resource in dependency order and reports all failed stages. Repeated disposal returns the same future; the default per-stage deadline is ten seconds.

The canonical Chime plugin is in `packages/flutter_aws_chime`. The repository root is a tooling package, not a second Flutter plugin. The vendored WebRTC hotfix remains isolated from project-wide source formatting and lint changes.

## Quality checks

Run from the repository root with the project's Flutter toolchain:

```sh
python3 scripts/check_sdk_quality.py --resolve --analyze --test
python3 scripts/check_sdk_architecture.py
python3 scripts/format_sdk.py --check
python3 scripts/generate_capability_matrix.py --check
```

Dependency resolution defaults to the local cache. CI resolves only declared project dependencies. The package inventory includes every owned SDK package; vendored WebRTC uses its original lint policy.

Build the Demo from `example`. For macOS, use the project-local helper:

```sh
python3 scripts/build_flutter_macos.py --release --no-pub
```

See [SDK architecture and error handling](doc/SDK_CODE_QUALITY.md), [provider integration](doc/PROVIDER_ADAPTER_GUIDE.md), [lightweight composition](doc/LIGHTWEIGHT_SDK.md), [capability matrix](SDK_CAPABILITY_MATRIX.zh-CN.md) and [acceptance boundaries](doc/INTERACTION_ACCEPTANCE.md).

## Acceptance

Unit tests, local Demo interaction and successful builds are recorded separately from real-provider calls, remote processed pixels, multi-device recovery and cloud cleanup. Windows requires a Windows runner. Credentials stay outside the Flutter package and Git; AWS Demo work uses the project-defined `chime-demo` profile.
