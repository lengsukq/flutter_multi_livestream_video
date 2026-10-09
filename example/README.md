# Realtime Media example

This is the repository's single Flutter demo app and a usage sample for the
public `flutter_realtime_sdk` package. It creates the simplified
`Realtime.standard()` facade for room listing,
diagnostics, create/join, Pre-Join, Meeting/Live, and standalone Chat. All
connection flows go through `Realtime.open(RealtimeRequest)`. It does not
register adapters or branch on the current platform. The
`demo-server` may select the provider for newly-created rooms and returns
short-lived join information; the SDK routes that provider to its built-in
driver and reports unsupported capabilities explicitly.

## Demo module map (P1)

`lib/main.dart` now only initializes theme/locale and mounts
`JoinScreen` from `lib/demo_join_screen.dart`. The responsive homepage
is split into `demo_home_hero.dart` and `demo_available_rooms.dart`.
`DemoIdentityStore` owns install-scoped identity and nickname preferences;
`DemoBackendDiagnostics` owns the backend status; `DemoRoomDirectory`
owns discovery refresh; and `DemoRoomFlow` builds create/join requests
and saves logical owner credentials for rejoin. None of these modules
imports an individual vendor media implementation.

The room lifecycle is create/join/discover → `Realtime.preJoin` →
`MediaPreJoinPage.show` → `Realtime.open(RealtimeRequest)` → room
route → `RealtimeConnection.dispose()`. A failed entry remains in Pre-Join
for retry; a connected room that cannot be handed to a route must be
disposed. The `initialMediaSettings` returned by preparation must be
carried into the room UI so camera, microphone and video background choices
apply before publish.

Below 600px, the homepage uses a compact top header instead of the large
desktop hero. Meeting/Live room layout comes from SDK UI, not a Demo-specific
widget tree. `MediaRole.host` is not a reliable substitute for an explicit
meeting/live mode: passing `MediaRoomMode.broadcast` is important for
livestream hosts. See the [Chinese P1 architecture and integration guide](../doc/P1_ARCHITECTURE_AND_INTEGRATION.zh-CN.md)
for the module graph and tested versus pending features.

## Run the example

1. Start the backend by following [`../demo-server/README.md`](../demo-server/README.md).
2. Open the backend dashboard and select a configured provider for new rooms.
3. Set `MEDIA_BACKEND_URL` (or enter the backend URL in the app) to an address reachable from the test device.
4. Run the app on Android, iOS, macOS, Windows, or Web and create or join a room.
5. Allow microphone and camera access when prompted. Web requires a secure
   context for browser media permissions; localhost is treated as secure by
   supported browsers.

The SDK's bundled Flutter plugins declare their native permission requirements.
Host applications must keep the matching purpose text in iOS/macOS
`Info.plist`; the example already includes camera and microphone descriptions.
Windows and browser permission prompts are handled by their platform runtimes.
Minimum OS support and provider/feature differences are listed in
[`../SDK_CAPABILITY_MATRIX.md`](../SDK_CAPABILITY_MATRIX.md).

### Run on Web

Enable Flutter Web once on the development machine with `flutter config --enable-web`.
Choose the **Flutter Web (Edge)** launch configuration, then run or debug. The
SDK package bundles the pinned provider browser SDKs and loads local assets
when a media or Product Chat connection needs them. Demo users do not need npm,
script tags, or CDN configuration. This workspace maps Flutter's Chrome device
to Microsoft Edge on macOS; adjust `CHROME_EXECUTABLE` in `.vscode/settings.json`
on machines that use a different Chromium-based browser.

The SDK's Web driver catalog exposes Agora Chat, Amazon IVS Chat, and Tencent
Chat. Standalone chat rooms use the provider selected by the backend dashboard,
so the same provider can be used across Web and native clients. The pinned
Agora, IVS, and Tencent Chat browser SDKs are bundled into the SDK package; the
app does not load chat SDKs from a CDN.
Agora Chat uses the Flutter SDK on Android and iOS, and the pinned official
`agora-chat` JavaScript SDK inside a local WKWebView on macOS. The macOS app
embeds that SDK bundle in its resources. When no product Chat provider is configured,
the app uses the same RTC data-chat fallback as native clients when the selected
media provider supports bidirectional data; LiveKit supports this on Web.

### Run on macOS

Run `flutter run -d macos`. The Agora Chat adapter requires macOS 12 or later. It
uses the same backend-issued short-lived user token as other platforms; the
Agora App Certificate stays on the server.

For a terminal launch, run `flutter run -d web-server` from this directory and
open the printed URL in a supported browser.

### Regenerate bundled browser SDK assets

The checked-in runtime assets are built from pinned dependencies and source in
`../packages/flutter_realtime_sdk/tool/provider_bridge`. SDK maintainers can
install those locked development dependencies with
`npm ci --prefix ../packages/flutter_realtime_sdk/tool/provider_bridge`, then
run `../scripts/build_provider_web_assets.sh`. This is only needed when updating
a pinned browser SDK or bridge source; normal app builds use the bundled files
directly.

Existing rooms keep their original provider even after the backend dashboard is
switched. The app UI does not expose or require provider selection.

Use Flutter 3.47+, Dart 3.12+, Java 17, Android API 28+ with compile SDK 37,
iOS 15+, macOS 12+, Windows 10+, and a secure browser context for Web media.
This local monorepo example disables Flutter Swift Package Manager and uses CocoaPods on
iOS to avoid local path package-identity ambiguity; the SDK packages themselves
do not require applications to disable SwiftPM.

Agora's optional real-service device E2E flow is documented in
[`../AGORA_E2E.md`](../AGORA_E2E.md).

Applications that use the lower-level Core packages directly may still depend
on only the provider adapters they need. The recommended high-level
`flutter_realtime_sdk` intentionally acts as the batteries-included bundle so
application runtime code does not maintain adapter registration. TRTC and ARTC
device E2E instructions are in [`../TRTC_E2E.md`](../TRTC_E2E.md) and
[`../ARTC_E2E.md`](../ARTC_E2E.md). The ARTC 7.11.0 iOS pod does not support
simulator linking.


## Teaching and Live interaction demos

Meeting rooms show the SDK classroom entry with hands, Q&A, roster and teaching
tools. Live rooms show the SDK gift entry when the backend advertises the
optional interaction API. No Demo-specific classroom/gift state is maintained.
Material sharing uses existing links; storage, file upload and recording are
not implemented. Screen annotations are drawn in the shared-content preview.

For macOS builds that hit the Iris SwiftPM FlutterMacOS linker issue, use
`python3 ../scripts/build_flutter_macos.py --release --no-pub` instead of a
global Flutter configuration change. It temporarily selects CocoaPods for the
Demo manifest and restores that manifest afterwards.

See [interaction acceptance](../doc/INTERACTION_ACCEPTANCE.md) for current
build/test evidence and pending real-device checks.

教学 Meeting 的 SDK 房间界面新增「课堂内容」入口，教师可选择成员、独立分页白板或屏幕共享。学生跟随教师，屏幕预览和白板共用完整标注工具。供应商没有共享能力时仍可使用白板；旧后端保留原共享流程。详见 [白板 SDK](../doc/WHITEBOARD_SDK.md)。
