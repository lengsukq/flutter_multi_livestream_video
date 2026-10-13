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

Web vendor files belong to their selected bundle. The shared media protocol
belongs to `flutter_realtime_media_web`, while processed-track registration and
rendering belong to `flutter_realtime_processed_video`. Agora, IVS and Tencent
Chat use separate runtime bundles. All files are locally packaged; hosts do not
need CDN tags or repository tooling.

Media bundles do not install video effects. A host that wants blur/image
replacement adds `flutter_realtime_video_effects` and explicitly supplies
`RealtimeRoomServices(videoEffectsFactory: DefaultRealtimeVideoEffects.new)`.
The Demo uses this configuration. Ordinary media, independent Chat and lean room
UI do not instantiate or probe effects and do not bundle effects models.

`flutter_realtime_room_ui` supplies room scope, video layouts and media controls.
It has no Classroom, Live, shared-content or system-annotation dependency.
`flutter_realtime_sdk_ui` remains the complete UI composition entry point.
Register Classroom, shared content, system annotation and Live independently.
Only the last two layers of the shared-content dependency chain acquire system
annotation implementations when `SystemAnnotationPreset` is explicitly added.

With `backendUrl` configured, both the standard SDK and directly constructed
`RealtimeClient` instances use an HTTP cloud recording session by default;
`recordingSessionFactory` overrides that default. `RecordingResult.taskState` carries the authoritative cloud task state;
`RecordingStatus` describes local controller operations. A failed stop remains
uncertain until a trusted query confirms the task state. Display only sanitized
service messages, and send diagnostics through the host's error channel.

The existing `example/` Demo demonstrates freely arranging optional UI
components. No separate Headless example project is required or maintained;
read `doc/SDK_RUNTIME_INTEGRATION.zh-CN.md` for UI-free integration snippets.
Use the architecture check and compare equivalent Release outputs before
making claims about actual APK/IPA/Web size reductions.

简体中文：运行入口显式注册供应商，App 不写平台分支。运行层不依赖现成 UI，按需加入 SDK UI。缓存上限影响本地显示历史，
不删除服务端消息；跨供应商历史分页与真实连麦仍是后续独立功能。
