# Lightweight provider composition / 轻量接入

`flutter_realtime_sdk` provides the all-provider convenience entry point.
`flutter_realtime_sdk_runtime` owns provider-neutral request, connection, room,
event, error and registry contracts; full-package exports point to those same
types rather than duplicate models. `Realtime(providers: …)` requires explicit bundles.
Runtime has no built-in UI dependency. Add flutter_realtime_sdk_ui explicitly when using the ready-to-use views; effects remain a platform controller dependency.

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

Build the two examples and run `python3 scripts/check_lite_artifacts.py` to verify
both their dependency graphs and actual Web artifacts. Compare byte counts for
the same release target; a lightweight sample and the full Demo have different UI
and should not be treated as a controlled startup-latency benchmark.

简体中文：运行入口显式注册供应商，App 不写平台分支。运行层不依赖现成 UI，按需加入 SDK UI。缓存上限影响本地显示历史，
不删除服务端消息；跨供应商历史分页与真实连麦仍是后续独立功能。
