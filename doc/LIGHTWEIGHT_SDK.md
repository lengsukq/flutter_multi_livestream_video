# Lightweight provider composition / 轻量接入

`flutter_realtime_sdk` is the lightweight facade (production dependency:
`flutter_realtime_sdk_runtime` only), with **no implicit provider or UI**.
`flutter_realtime_sdk_runtime` owns provider-neutral request, connection, room,
event, error and registry contracts; full-package exports point to those same
types rather than duplicate models. `Realtime(providers: …)` requires explicit bundles.
Runtime has no built-in UI or vendor dependency. Add `flutter_realtime_sdk_ui`
explicitly for widgets, and register only Provider bundles the app needs.

| Optional package | Registration function | Public provider |
| --- | --- | --- |
| flutter_realtime_provider_livekit | createLivekitProvider | livekit |
| flutter_realtime_provider_agora | createAgoraProvider | agora |
| flutter_realtime_provider_trtc | createTrtcProvider | trtc |
| flutter_realtime_provider_artc | createArtcProvider | artc |
| flutter_realtime_provider_aws | createAwsProvider | aws (meeting: chime; live: ivs) |
| flutter_realtime_provider_agora_chat | createAgoraChatProvider | agora-chat |
| flutter_realtime_provider_ivs_chat | createIvsChatProvider | ivs-chat |
| flutter_realtime_provider_tencent_chat | createTencentChatProvider | tencent-chat |

Add only the base and chosen bundles to the host manifest. Conditional platform
drivers live inside each bundle; application code uses the same `open()` request
on every target. Missing or unregistered providers fail explicitly. The backend
must return providers registered by the host. Custom bundles implement
`RealtimeProviderBundle` with platform drivers and a local Web assets loader.

Chat bundle constructors accept `maxMessages` (default 500); low-level chat
session factories and sessions also accept it. RTC fallback retains its existing
200 default. Limits must be positive. Eviction removes only local session history;
it does not delete server messages. Snapshot lists remain immutable.

Web vendor files belong to their selected bundle. Media bridge code is shared in
the base. Agora, IVS and Tencent Chat use separate runtime bundles; effects load
from the effects package only when a processed source/device preview needs them.
All files are locally packaged; hosts do not need CDN tags.

Bundled media providers also supply the default video-effects implementation.
`Realtime(providers: [createLivekitProvider(), ...])` therefore retains background
blur/image replacement support without requiring an additional `services` argument.
An explicit `RealtimeRoomServices(videoEffectsFactory: ...)` takes precedence.
For custom driver-only `Realtime.standard(drivers: ...)` integrations, supply the
factory through `services` because those drivers do not declare a provider bundle.

With `backendUrl` configured, both the standard SDK and directly constructed
`RealtimeClient` instances use an HTTP cloud recording session by default;
`recordingSessionFactory` overrides that default. Failed cloud recording results
preserve the backend's `error` string in `RecordingResult.metadata['error']` so
the host can display the recording task's failure reason.

The existing `example/` Demo demonstrates freely arranging optional UI
components. No separate Headless example project is required or maintained;
read `doc/SDK_RUNTIME_INTEGRATION.zh-CN.md` for UI-free integration snippets.
Use the architecture check and compare equivalent Release outputs before
making claims about actual APK/IPA/Web size reductions.

简体中文：运行入口显式注册供应商，App 不写平台分支。运行层不依赖现成 UI，按需加入 SDK UI。缓存上限影响本地显示历史，
不删除服务端消息；跨供应商历史分页与真实连麦仍是后续独立功能。
