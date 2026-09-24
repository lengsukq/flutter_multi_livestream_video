# 多媒体后端路线图实施计划

## 目标

推进 README Roadmap 中尚未完成的两项：

1. 在 AWS Chime 之外增加实时音视频通信后端：Agora、LiveKit、TRTC、ARTC。
2. 增加一对多直播后端：IVS、LiveKit、Agora、TRTC、ARTC。

本计划先交付 LiveKit MVP，随后用同一套服务商无关接口逐步接入其余服务商。

## 已确认的范围与决定

- MVP 平台为 Android 和 iOS；保持项目当前 Android API 23、iOS 15 部署下限。
- MVP 同时覆盖 LiveKit 实时会议，以及一位主播、多位观众观看的直播模式。
- 直播使用 LiveKit 房间内的 WebRTC 发布/订阅：主播发布音视频，观众以只订阅身份加入同一房间。本期不做 HLS、LiveKit Egress 或其他服务端直播输出。
- 观众规模按功能 MVP 验收：至少一位主播和两位观众可正常收看；不承诺固定并发容量或性能 SLA。
- 应用后端负责提供 LiveKit 服务地址和短期 participant token；本仓库不实现 token 签发、房间管理服务，也不保存服务端密钥。token 的 room、identity 和权限由签发端设置。
- 同一时刻只允许一个媒体会话运行。切换 Chime/LiveKit 前须完整断开并释放当前会话。
- 保持 `flutter_aws_chime` 包名。v3 已将 Chime API 重设计为 `ChimeMeetingSession`，不提供 v2 `MeetingModel` / `MeetingView` 兼容层。未来新增服务商无关 API 时，以 v3 会话为 Chime 适配器基础，不恢复已移除的 v2 接口。
- 将供应商 SDK 依赖设为可选：新建 `flutter_realtime_media_core` 公共核心包和 `flutter_realtime_media_livekit` LiveKit 适配包；现有 `flutter_aws_chime` 保留原生 Chime 实现，并通过兼容适配层接入公共接口、重新导出公共类型。

## 架构与公共接口

### 核心包

`flutter_realtime_media_core` 不依赖任何供应商 RTC SDK，定义：

- `MediaSession`：会话连接、断开、生命周期状态和事件流。
- `InteractiveMediaSession`：实时会议的麦克风、摄像头、前后摄像头切换等控制。
- `BroadcastHostSession` 与 `BroadcastViewerSession`：分别提供主播发布能力和观众接收能力；观众接口不暴露发布操作。
- 通用数据类型：`MediaParticipant`、`MediaTrack`、`MediaEvent`、`MediaError`、`MediaCapabilities`。
- `MediaTrackView` 渲染接口，使通用组件不依赖某一家 SDK 的轨道类型。

公共事件至少覆盖连接状态/重连、参与者加入/离开、轨道发布/移除、本地音视频状态变化及错误。服务商配置由对应适配包提供；核心层不强行把不同供应商的鉴权字段压成同一种格式。能力声明用于说明可选功能；调用不支持的功能时返回明确的类型化错误。

### 适配包与兼容性

- `flutter_realtime_media_livekit` 依赖 LiveKit 官方 Flutter 客户端 SDK，将 LiveKit room、participant、track 和状态映射到核心接口。
- `flutter_realtime_media_agora` 依赖 Agora 官方 `agora_rtc_engine`，已接入 participant/host/viewer、音视频控制、远端渲染、事件映射和 RTC data stream；屏幕共享继续暂缓，viewer data 发送暂不开放。
- `flutter_realtime_media_trtc` 依赖官方 `tencent_rtc_sdk`，以独立可选包提供 participant/host/viewer 会话、渲染、消息和通用凭证续签；viewer 发布权限由服务端 PrivateMapKey 限制。
- `flutter_realtime_media_artc` 依赖阿里云 ARTC 原生 Android/iOS SDK 7.11.0，以独立可选包提供 participant/host/viewer 会话、渲染、消息和通用凭证续签；ARTC viewer 角色由客户端 SDK 设置，Token 不提供服务端发布权限边界。
- `flutter_realtime_media_chime` 已将现有 `flutter_aws_chime` v3 `ChimeMeetingSession` / 原生渲染桥适配到公共 Core；原 `flutter_aws_chime` API 保持兼容，不要求已有 Chime-only 应用迁移。
- 每个供应商均以独立可选适配包接入；Core 不设默认 Provider，应用只注册自身实际使用的适配器。
- 同一 `example/` 注册 Chime、LiveKit、Agora、TRTC 与 ARTC Adapter；App 不选择 Provider，由 `demo-server` 返回 Provider。LiveKit 已有真实服务 E2E；Agora 已完成真实项目单会话 join/leave E2E；TRTC 和 ARTC 有真实设备 E2E 入口，需配置各自项目凭证与设备后运行。

### 通用组件

后续可增加可选的 `MediaSessionView` 和 `LiveBroadcastView`，支持本地预览、远端画面、基础音视频控制，以及加载、连接中断/重连和错误状态。组件通过 builder/theme 等入口允许应用自定义布局；本计划不改动 v3 会话 API。

## 实施阶段

1. **依赖与互操作验证 — 已完成基础门禁**：单一统一示例同时解析 Chime、LiveKit 与 Agora；Android/iOS Simulator 构建通过，资源释放和 provider 切换由统一 Core/后端契约覆盖。
2. **提取核心接口 — 已完成**：公共 Core、Chime Adapter、LiveKit Adapter 已落地；原 Chime API 保持兼容。
3. **实现 LiveKit 实时会议 — 已完成**：连接、加入/离开、麦克风、摄像头、摄像头切换、参与者/轨道事件和 Android/iOS 渲染已接入。
4. **实现 LiveKit 一对多直播 — 已完成核心能力**：host/viewer 角色、viewer 禁止发布、数据消息和订阅能力已实现；真实设备媒体 E2E 按需运行。
5. **通用 UI、示例与发布准备 — 已完成当前仓库范围**：复用现有 `example/`，App 不选择 Provider；`demo-server` UI 决定新房间使用 Chime、LiveKit、Agora、TRTC 或 ARTC；相关契约与接入文档已补齐。
6. **Agora 适配 — 已完成代码与真实单会话门禁**：独立 Adapter、RTC/host/viewer 角色、媒体控制、渲染、RTC data stream、AccessToken2、demo-server 三 Provider 路由均已接入；真实 Agora 项目 join/leave E2E 已通过，双设备 host/viewer 与 co-host authentication 强约束验证按凭证显式运行。
7. **TRTC 适配 — 已完成代码接入**：独立可选适配包、三种角色、后端签名/刷新、房间场景锁定、Viewer 服务端发布权限、统一示例、离线测试和真实设备 E2E 入口均已实现。RTC 后续供应商为 ARTC；直播后续供应商为 IVS 与 ARTC。TRTC 真机验收仍需配置凭证和至少三台设备。
8. **ARTC 适配 — 已完成代码接入**：独立可选原生适配包、participant/host/viewer、后端短期 Token 签发与续期、房间模式锁定、统一示例、离线测试和设备 E2E 入口已实现。Android APK 与 iOS 真机目标可构建；阿里云 ARTC 7.11.0 iOS CocoaPod 仅提供设备 framework，iOS Simulator 不能链接。Participant 通话及一位 host 加两位 viewer 的真机服务验收仍待配置 ARTC 凭证和至少三台设备；viewer Token 本身不限制恶意客户端发布。

## 测试与验收

- **核心单测**：使用 fake adapter 验证连接/断开、状态转换、事件映射、媒体能力、类型化错误及重复释放安全性。
- **角色单测**：验证主播可发布、观众 API 无发布方法；验证 Agora/TRTC 的 viewer 凭证服务端发布权限，以及 ARTC viewer 客户端角色的安全边界。客户端限制不能替代服务端 token 授权。
- **组件测试**：验证会议、主播和观众视图，以及加载、权限拒绝、断线重连和错误状态。
- **平台构建**：公共包、Chime、LiveKit、Agora、TRTC 和示例应通过 Android/iOS 构建，保持当前部署下限；确认相机/麦克风权限配置完整。ARTC iOS 7.11.0 例外要求设备目标构建，不支持模拟器链接。
- **服务集成验收**：在不把凭证提交进仓库的测试环境中，验证多人实时会议，以及一位主播加至少两位观众的直播；覆盖无效/过期 token、拒绝相机或麦克风权限、网络中断恢复、主播离开、观众离开及两种后端顺序切换。ARTC 真机 E2E 入口已加入，设备验收需外部 ARTC 项目配置。
- **回归**：Chime v3 会话 API、Chime 示例及相关测试继续通过；不要求一次性复制 Chime 的聊天、屏幕共享等供应商特有功能到公共 API，也不要求恢复 v2 兼容 API。

## 路线图状态

LiveKit MVP 通过验收后，第 3、4 项保持进行中状态。Agora、TRTC、ARTC 已完成代码接入；ARTC 的 participant 通话与 host/viewer 真机验收仍待 ARTC 项目配置和设备。只有第 3 项列出的 Agora、LiveKit、TRTC、ARTC 通信后端，以及第 4 项列出的 IVS、LiveKit、Agora、TRTC、ARTC 直播后端都通过各自平台验收后，才将对应路线图项标为完成。

## 参考资料

- [LiveKit Flutter 客户端 SDK](https://github.com/livekit/client-sdk-flutter)
- [LiveKit 连接与 token 权限](https://docs.livekit.io/intro/basics/connect/)
- [LiveKit Egress 概览](https://docs.livekit.io/transport/media/ingress-egress/egress/)
- [AWS Chime iOS issue #699：与另一套 WebRTC 同应用时的视频互操作报告](https://github.com/aws/amazon-chime-sdk-ios/issues/699)
