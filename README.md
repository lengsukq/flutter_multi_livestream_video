# Flutter Realtime SDK

Provider-neutral Flutter SDK for meetings, live media, product chat, classroom tools and shared content. The Demo uses the same public APIs as a host application.

> **发布状态 / Publication status (2026-10-15):** Preview **[`flutter_realtime_sdk 0.1.0-dev.1`](https://pub.dev/packages/flutter_realtime_sdk/versions/0.1.0-dev.1) published successfully**; its public version-metadata endpoint returns HTTP 200. The single-package distribution combines 44 internal modules under one public package. Independent-host unsigned iOS Release compilation, analysis and pub dry-run passed. Windows/Linux and real-device vendor acceptance remain unverified. The development facade remains separate from the generated distribution. See [single-package release plan](doc/SINGLE_PACKAGE_RELEASE.zh-CN.md) and [pub.dev release guide](doc/PUB_DEV_RELEASE_GUIDE.zh-CN.md).

**简体中文** · [快速接入](#快速接入开发阶段) · [Package 划分](#entry-points) · [接入指南](doc/SDK_RUNTIME_INTEGRATION.zh-CN.md) · [供应商与平台能力](doc/SDK_CAPABILITY_MATRIX.zh-CN.md) · [云录制](doc/CLOUD_RECORDING.md) · [发布准备](doc/PUB_DEV_RELEASE_GUIDE.zh-CN.md)

**从零在第三方 Flutter App 接入：**[完整接入清单（安装依赖 → 配置后端 → 创建/加入 → UI/权限 → 验收）](doc/APP_INTEGRATION_QUICKSTART.zh-CN.md)。
**发行目标：**[一个公开包、44 个内部模块的合并方案](doc/SINGLE_PACKAGE_RELEASE.zh-CN.md)。
**内部模块职责：**[44 个模块的依赖与功能索引](doc/PACKAGE_INTEGRATION_INDEX.zh-CN.md)。

### pub.dev 单包预览版接入

已发布预览版**只需要一个 SDK 包和一个 SDK import**：

```yaml
dependencies:
  flutter_realtime_sdk: ^0.1.0-dev.1
```

```dart
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';

final realtime = Realtime(
  backendUrl: 'https://your-backend.example',
  providers: [createLivekitProvider()],
);
// 可以只用 Headless SDK，也可以使用同一包中的可组合 UI。
```

供应商在运行时仍需显式注册以免误选，但**不再要求使用者添加另一个
`flutter_realtime_provider_*` 依赖**。单包的缺点是不同厂商原生依赖可能
全部被解析、安装，不能仅凭未注册 Provider 就承诺减小安装包体积。

## 快速接入（开发阶段）

**源码开发要求：** Flutter ≥ 3.47、Dart ≥ 3.12；运行参考后端需 Node.js ≥ 22.18。修改内部模块时，克隆仓库并以相对路径引入 facade + 选定 Provider；使用已发布预览版请按上一节安装：

```yaml
# Host app pubspec.yaml; assume the SDK checkout sits beside your app.
dependencies:
  flutter:
    sdk: flutter
  flutter_realtime_sdk:
    path: ../flutter_multi_livestream_video/packages/flutter_realtime_sdk
  flutter_realtime_provider_livekit:
    path: ../flutter_multi_livestream_video/packages/flutter_realtime_provider_livekit
  # Optional UI:
  flutter_realtime_sdk_ui:
    path: ../flutter_multi_livestream_video/packages/flutter_realtime_sdk_ui
```

先按 [Demo Server 指南](demo-server/README.md) 启动可信任的服务端、配置真实供应商和临时入会凭证。这里的 `backendUrl` 必须可从**运行应用的设备**访问：macOS 本机开发可用 `http://localhost:3000`；Android 模拟器可使用 `http://10.0.2.2:3000`；物理手机需要服务端的局域网 IP 或 HTTPS 域名。**不要把 App Certificate、Customer Secret、S3 密钥等写入 Flutter 客户端。**

```dart
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_realtime_provider_livekit/flutter_realtime_provider_livekit.dart';

final realtime = Realtime(
  backendUrl: 'https://your-backend.example',
  providers: [createLivekitProvider()],
);

final connection = await realtime.open(
  RealtimeRequest.create(
    type: RealtimeExperience.meeting,
    user: const RealtimeUser(id: 'user-1', name: 'Alice'),
  ),
);
final room = connection.mediaRoom!; // Meeting/Live；纯 Chat 则取 chatRoom。
// 使用 room.states / room.events / room.media.session.snapshots 更新宿主 UI。
// 只有用户真正离开房间时，才释放 SDK 持有的会话。
await connection.dispose();
```

需要成品房间组件时，应用**额外依赖** `flutter_realtime_sdk_ui` 并导入：

```dart
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';

RealtimeRoomView(room: connection.mediaRoom!);
```

需要举手、课堂 Q&A 或直播点赞/礼物时，请再依赖 `flutter_realtime_classroom_preset` / `flutter_realtime_live_preset`，使用 `featurePlugins: const [ClassroomPreset(), LivePreset()]` **显式注册**。礼物是演示互动，不包含支付或资金结算。参照 [SDK 接入指南](doc/SDK_RUNTIME_INTEGRATION.zh-CN.md)、[可选功能注册](doc/INTERACTION_PRESET_GUIDE.zh-CN.md) 和 [Demo 示例](example/README.md)；无需单独维护 Headless Demo。

> **平台能力不等于真实设备验收：**会议/直播、IM、共享屏幕、录制、虚拟背景依赖选定 Provider、平台和角色。部分 Windows、iOS/Android 屏幕共享和云录制流程仍需实机联调。看 [能力矩阵](doc/SDK_CAPABILITY_MATRIX.zh-CN.md) 与 [验收记录](doc/ACCEPTANCE.md)，不要把示例的 UI 按钮视为已实现全部厂商能力。

## Internal entry points (development modules, not separate public releases)

| Package | Use |
| --- | --- |
| `flutter_realtime_sdk` | Internal lightweight facade (runtime only); the generated public package also includes provider factories, optional UI and presets |
| `flutter_realtime_sdk_runtime` | Provider-neutral `Realtime`, `RealtimeRoom`, room member/mutation and lifecycle contracts |
| `flutter_realtime_interaction_core` | Business-neutral typed events, revision snapshots, authoritative commands, and transport contracts |
| `flutter_realtime_classroom_preset` | Optional classroom business feature, shared content, whiteboard and annotation adapters (no UI required) |
| `flutter_realtime_live_preset` | Optional likes, gifts and event history (no UI required) |
| `flutter_realtime_sdk_ui` | Optional room, classroom, live and whiteboard UI |
| `flutter_realtime_foundation` | Pure Dart errors, HTTP execution, cleanup and protocol validation |
| Domain Core packages | Independently composable Media, Chat, Classroom, Live and Whiteboard contracts |
| Provider bundles | Register only the selected media/chat drivers and local Web assets |

```dart
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_realtime_provider_livekit/flutter_realtime_provider_livekit.dart';

final realtime = Realtime(
  backendUrl: 'http://localhost:3000',
  providers: [createLivekitProvider()],
);
```

Create and join use a provider-neutral request on every platform:

```dart
final connection = await realtime.open(
  RealtimeRequest.create(
    type: RealtimeExperience.meeting,
    user: const RealtimeUser(id: 'user-1', name: 'Alice'),
  ),
);
// RealtimeRoom/ChatSession are SDK-owned; the host chooses whether to display
// any SDK UI components. Dispose on explicit leave, not on UI unmount.
await connection.dispose();
```

Use `RealtimeRequest.join(type: ..., roomCode: ..., user: ...)` for an existing room, `RealtimeExperience.live` for broadcasts, and `RealtimeExperience.chat` for standalone IM. Use `Realtime.preJoin` and `createLocalPreview` directly for custom checks, or optionally add the SDK UI package for built-in controls.

For explicit composition, import the runtime and selected bundle:

```dart
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_provider_livekit/flutter_realtime_provider_livekit.dart';

final realtime = Realtime(providers: [createLivekitProvider()]);
```

Add `flutter_realtime_sdk_ui` explicitly to use optional room buttons, video grids, chat panels and templates. The existing Demo is **only** an example of composing those widgets; it registers its own providers in `example/lib/demo_provider_catalog.dart`. The SDK itself has no default provider catalog. Advanced `Realtime.standard(drivers: ...)` also requires explicit drivers; for Web prefer Provider bundles so their JS assets are loaded lazily.

Classroom and Live business behavior are **not** loaded by default, even if
backend room metadata advertises support. Import the corresponding optional
preset package and pass `featurePlugins: const [ClassroomPreset(), LivePreset()]`
to the SDK's `Realtime` factory. The existing `room.classroom`,
`room.sharedContent` and `room.liveInteractions` getters are typed **extensions
from the optional packages**. The Demo elects to register both presets and
retains the existing business implementations. It also implements its own
`demo.reaction.wave` event and notification UI directly on the generic
`room.interactions` API; no new SDK business method is needed.

See [Interaction architecture and opt-in feature registration](doc/INTERACTION_ARCHITECTURE.md).
For Meeting creator/guest, Live broadcaster/viewer and standalone Chat
host/member wording and permission boundaries, see
[role-aware UI semantics](doc/ROLE_UI_SEMANTICS.md).
For four independent integration patterns and a custom feature plugin, see
[Headless / Preset / Interaction 接入指南](doc/INTERACTION_PRESET_GUIDE.zh-CN.md).

See [纯功能 SDK 接入与 UI 可选指南](doc/SDK_RUNTIME_INTEGRATION.zh-CN.md) for API, lifecycle, permissions, RTC/IM members and snippets; **no separate Headless Demo is maintained**.

Cloud recording: [供应商托管的 Agora、LiveKit Cloud、TRTC VOD、Alibaba ARTC、AWS Chime 与 AWS IVS+MediaConvert 云录制/MP4 下载](doc/CLOUD_RECORDING.md). The Flutter SDK owns only provider-neutral start/stop/status/download methods; Demo Server calls vendor APIs and streams completed cloud files to users. **No Linux recording workers, local Java Recording SDK or server-side media encoding.** Buckets may be left blank until recording is enabled. IVS native HLS output is converted to MP4 by AWS MediaConvert (additional cloud configuration needed). **LiveKit Cloud + S3 recording was confirmed working by the project user on 2026-10-12** (not independently retested as part of this documentation update); real-cloud E2E for other vendors remains pending, with Agora currently blocked at `acquire` HTTP 401.

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

To build an **Apple Silicon (arm64-compatible) macOS installer DMG** from the
repository root, and optionally install the Demo to `/Applications`:

```sh
./build_macos_arm64.command                  # Build, package, install and launch
./build_macos_arm64.command --skip-build     # Package and install an existing Release app
```

Double-click `build_macos_arm64.command` in Finder for the same build/install
flow. Run `chmod +x build_macos_arm64.command` once if your checkout does not
preserve the executable bit. This entry point reuses the CocoaPods-aware helper,
builds macOS through CocoaPods without duplicating Flutter's generated SwiftPM
product (while preserving iOS SwiftPM integration),
rejects simultaneous one-click builds, checks for processes using Xcode's
`build.db` before starting, and reports missing Flutter/Xcode/CocoaPods tools.
If another build is active, wait for it to finish instead of deleting its
database. A `build.db` lock is distinct from the `iris_method_channel` SwiftPM
module/link errors; see [DEVELOPMENT.md](doc/DEVELOPMENT.md) for troubleshooting.
The script never terminates other builds or automatically deletes build caches.
It verifies the built executable
contains `arm64`, and packages an Applications shortcut into the DMG. It builds
the **Demo**, not an SDK framework. Dependencies should already be resolved in
`example/` (`flutter pub get` there if needed). No Apple signing or notarization
is performed; this is a local/development distribution package. More details
and install permission alternatives are in [DEVELOPMENT.md](doc/DEVELOPMENT.md).

See [SDK architecture and error handling](doc/SDK_CODE_QUALITY.md), [provider integration](doc/PROVIDER_ADAPTER_GUIDE.md), [lightweight composition](doc/LIGHTWEIGHT_SDK.md), [capability matrix](doc/SDK_CAPABILITY_MATRIX.zh-CN.md) and [acceptance boundaries](doc/INTERACTION_ACCEPTANCE.md).

For independent room controls, optional composed default pages, chat-only UI,
Pre-Join scope ownership, RTC+IM member controls, package dependency direction,
and explicit build/E2E acceptance limits, see the
[UI 组件化接入与验收说明](doc/UI_COMPOSABILITY_ACCEPTANCE.zh-CN.md).

**P1 中文接入与架构文档：** [SDK Quick Start、Meeting/Live、Pre-Join、Demo/Server 模块与验收边界](doc/P1_ARCHITECTURE_AND_INTEGRATION.zh-CN.md)。同时参考 [变更前测试基线](doc/P1_CLEAN_CODE_BASELINE.md)、[内置 Media UI](packages/flutter_realtime_media_ui/README.md)、[Demo](example/README.md) 和 [Demo Server](demo-server/README.md)。

## Acceptance

Unit tests, local Demo interaction and successful builds are recorded separately from real-provider calls, remote processed pixels, multi-device recovery and cloud cleanup. Windows requires a Windows runner. Credentials stay outside the Flutter package and Git; AWS Demo work uses the project-defined `chime-demo` profile.
