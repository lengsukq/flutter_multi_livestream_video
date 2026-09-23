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
- 将供应商 SDK 依赖设为可选：新建 `flutter_multi_livestream_video_core` 公共核心包和 `flutter_multi_livestream_video_livekit` LiveKit 适配包；现有 `flutter_aws_chime` 保留原生 Chime 实现，并通过兼容适配层接入公共接口、重新导出公共类型。

## 架构与公共接口

### 核心包

`flutter_multi_livestream_video_core` 不依赖任何供应商 RTC SDK，定义：

- `MediaSession`：会话连接、断开、生命周期状态和事件流。
- `InteractiveMediaSession`：实时会议的麦克风、摄像头、前后摄像头切换等控制。
- `BroadcastHostSession` 与 `BroadcastViewerSession`：分别提供主播发布能力和观众接收能力；观众接口不暴露发布操作。
- 通用数据类型：`MediaParticipant`、`MediaTrack`、`MediaEvent`、`MediaError`、`MediaCapabilities`。
- `MediaTrackView` 渲染接口，使通用组件不依赖某一家 SDK 的轨道类型。

公共事件至少覆盖连接状态/重连、参与者加入/离开、轨道发布/移除、本地音视频状态变化及错误。服务商配置由对应适配包提供；核心层不强行把不同供应商的鉴权字段压成同一种格式。能力声明用于说明可选功能；调用不支持的功能时返回明确的类型化错误。

### 适配包与兼容性

- `flutter_multi_livestream_video_livekit` 依赖 LiveKit 官方 Flutter 客户端 SDK，将 LiveKit room、participant、track 和状态映射到核心接口。
- `flutter_aws_chime` 当前对外 API 为 v3 `ChimeMeetingSession` 和可选 `ChimeMeetingView`。后续如抽取公共核心包，增加 Chime 到核心会话接口的适配；不会保留 v2 的 `MeetingModel` / `MeetingView` API。
- 每个新增供应商以后以独立可选适配包接入，避免 Chime-only 应用被迫解析 LiveKit、Agora 等 SDK 依赖。
- 发布前先验证同一应用同时包含 Chime 与 LiveKit 依赖时的 Android/iOS 构建、资源释放与跨后端顺序切换。AWS Chime issue #699 报告了同一应用使用 Chime 与另一套 WebRTC 时的视频互操作问题，因此 iOS 视频互操作是发布门槛；若失败，不绕过门槛或宣称兼容，先定位并解决依赖/编解码问题。

### 通用组件

后续可增加可选的 `MediaSessionView` 和 `LiveBroadcastView`，支持本地预览、远端画面、基础音视频控制，以及加载、连接中断/重连和错误状态。组件通过 builder/theme 等入口允许应用自定义布局；本计划不改动 v3 会话 API。

## 实施阶段

1. **依赖与互操作验证**：创建最小 Android/iOS 集成示例，验证 Chime 与 LiveKit 依赖解析和构建；在设备上确认单一活动会话约束、退出清理、顺序切换及 Chime 视频互操作。
2. **提取核心接口**：创建公共 core 包；将现有 Chime 接入公共会话/事件/渲染接口，同时保持原 Chime API 和现有示例行为。
3. **实现 LiveKit 实时会议**：完成连接、加入/离开、麦克风和摄像头控制、参与者/媒体轨道事件及 Android/iOS 渲染。
4. **实现 LiveKit 一对多直播**：主播使用可发布权限加入房间；观众使用仅订阅权限加入；处理观众音视频渲染、主播结束、观众退出、断线与重连。
5. **通用 UI、示例与发布准备**：提供可选会议/直播组件和可配置示例；完善 API、权限、凭证和平台文档；在兼容性门槛通过后发布增量版本。
6. **后续供应商适配**：按路线图顺序，RTC 增加 Agora、TRTC、ARTC；直播增加 IVS、Agora、TRTC、ARTC。每个适配包均实现核心会话、能力声明、事件映射和该供应商必要的渲染适配。

## 测试与验收

- **核心单测**：使用 fake adapter 验证连接/断开、状态转换、事件映射、媒体能力、类型化错误及重复释放安全性。
- **角色单测**：验证主播可发布、观众 API 无发布方法；并确认观众 token 的服务端权限为只订阅。客户端限制不能替代服务端 token 授权。
- **组件测试**：验证会议、主播和观众视图，以及加载、权限拒绝、断线重连和错误状态。
- **平台构建**：公共包、Chime 包、LiveKit 包和示例均通过 Android/iOS 构建，保持当前部署下限；确认相机/麦克风权限配置完整。
- **服务集成验收**：在不把凭证提交进仓库的测试环境中，验证多人实时会议，以及一位主播加至少两位观众的直播；覆盖无效/过期 token、拒绝相机或麦克风权限、网络中断恢复、主播离开、观众离开及两种后端顺序切换。
- **回归**：Chime v3 会话 API、Chime 示例及相关测试继续通过；不要求一次性复制 Chime 的聊天、屏幕共享等供应商特有功能到公共 API，也不要求恢复 v2 兼容 API。

## 路线图状态

LiveKit MVP 通过验收后，将第 3、4 项标为“进行中（LiveKit 已支持）”，不标为全部完成。只有第 3 项列出的 Agora、LiveKit、TRTC、ARTC 通信后端，以及第 4 项列出的 IVS、LiveKit、Agora、TRTC、ARTC 直播后端都通过各自平台验收后，才将对应路线图项标为完成。

## 参考资料

- [LiveKit Flutter 客户端 SDK](https://github.com/livekit/client-sdk-flutter)
- [LiveKit 连接与 token 权限](https://docs.livekit.io/intro/basics/connect/)
- [LiveKit Egress 概览](https://docs.livekit.io/transport/media/ingress-egress/egress/)
- [AWS Chime iOS issue #699：与另一套 WebRTC 同应用时的视频互操作报告](https://github.com/aws/amazon-chime-sdk-ios/issues/699)
