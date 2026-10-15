# P1 Clean Code：架构、SDK 接入与迁移说明

> 适用范围：当前 `flutter_realtime_sdk` / `flutter_realtime_sdk_runtime`、内置 Media UI、Flutter Demo 及 Demo Server。本文基于 2026-10-09 工作区源码整理，记录**已实现的代码结构**与**验收范围**，不是对所有供应商和设备的上线承诺。

## 1. 项目定位

本项目是**前端 Flutter 实时互动 SDK**，而非围绕 Demo 定制的应用。业务 App 按统一请求创建或加入会议、直播、独立聊天；它不需要识别 Android/iOS/Web/macOS/Windows 的供应商具体实现。服务器提供可信的房间、身份与短期凭证控制面；音视频由选定供应商的客户端 SDK 承载，并不经过 Demo Server 转发。

- **统一轻量入口**：`flutter_realtime_sdk` 只依赖 Runtime，应用显式注册 Provider Bundle，不自动引入 UI 或所有厂商。
- **可选 UI**：`flutter_realtime_sdk_ui` 由 Demo 或业务 App 额外引入，详情见 [纯功能与 UI 可选接入](SDK_RUNTIME_INTEGRATION.zh-CN.md)。
- **三种体验**：`RealtimeExperience.meeting`、`live`、`chat`；媒体与产品级 IM 是两条独立能力链路。
- **能力驱动**：具体控制按钮依赖 `MediaCapabilities`、`ChatCapabilities` 和后端可信管理能力；不能根据供应商名称推断是否支持。
- **无旧版包袱**：当前只有仓库 Demo 是正式接入样例，本轮不保留已移除的旧 Pre-Join Dialog 或旧 base/Lite API。

## 2. 依赖与数据流

```text
┌────────────────── 业务 App / example/ ──────────────────────┐
│  Realtime(providers: ...) / RealtimeRequest / Connection    │
│  Demo 展示 SDK 标准页面（也支持纯 Runtime 自定义 UI）   │
└────────────────────────────┬────────────────────────────────┘
                             │ 公共 SDK API
┌────────────────────────────▼────────────────────────────────┐
│ flutter_realtime_sdk_runtime                                │
│  房间/身份/生命周期、预检、事件、能力查询、Provider 解析      │
└───────────────┬───────────────────────────────────┬─────────┘
                │                                   │
    ┌───────────▼────────────┐        ┌─────────────▼─────────┐
    │ Media/Chat/Classroom/  │        │ Provider Bundles       │
    │ Live/Whiteboard Core   │◄───────│ AWS/LiveKit/Agora/     │
    │ （平台无关的契约）     │        │ TRTC/ARTC、Chat 驱动  │
    └────────────────────────┘        └─────────────┬─────────┘
                                                     │ 供应商 SDK
                                                  RTC / IM 云端
                             ┌───────────────────────┘
                       短期凭证、房间上下文
                      ┌───────────────┐
                      │ Demo Server   │
                      │ 可信控制面    │
                      └───────────────┘
```

完整包集成示例使用真实公开声明：

```dart
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_realtime_provider_livekit/flutter_realtime_provider_livekit.dart';

final realtime = Realtime(
  backendUrl: 'http://YOUR_LAN_IP:3000',
  providers: [createLivekitProvider()],
);
final connection = await realtime.open(
  RealtimeRequest.create(
    type: RealtimeExperience.meeting,
    user: const RealtimeUser(id: 'user-1', name: 'Alice'),
  ),
);

// connection.mediaRoom 是解析后的 SDK RealtimeRoom。
// 应用可独立使用 Runtime，或选择性引入 flutter_realtime_sdk_ui 组件。
// 页面离开 / 会话结束时由连接所有者调用：
await connection.dispose();
```

以上片段展示接口用法，**不应在画面刚创建完就立即 dispose**；宿主应在房间页面生命周期结束时释放。加入现有房间使用 `RealtimeRequest.join(type: ..., user: ..., roomCode: '...')`。纯聊天用 `RealtimeExperience.chat`，并处理 `connection.chatRoom` 而不是强行读取 `mediaRoom!`。无后端的高级接入可采用 `RealtimeSource.credentials(...)`，但 token 应由可信服务签发，不在客户端保存供应商密钥。

## 3. Demo 现在如何使用 SDK

| 位置 | 当前职责 | 禁止新增的职责 |
| --- | --- | --- |
| `example/lib/main.dart` | App 初始化、语言/主题装配、`JoinScreen` | HTTP、媒体 Provider 分支、房间生命周期 |
| `demo_join_screen.dart` | 操作协调、表单、进入 Pre-Join 与页面跳转 | 内嵌供应商 RTC SDK、保存密钥 |
| `demo_home_hero.dart` / `demo_available_rooms.dart` | 响应式首页展示、房间列表 | 网络请求、管理后端状态 |
| `demo_identity_store.dart` | 设备标识/昵称偏好 | 原生硬件 ID 或持久云凭证 |
| `demo_backend_diagnostics.dart` | 后端检测状态 | Provider 专有 API |
| `demo_room_directory.dart` | 房间列表刷新/过期结果处理 | RTC SDK 连接 |
| `demo_room_flow.dart` | 创建/加入请求、逻辑房主凭证保存 | `Navigator`、Widget 生命周期 |

创建和加入（包括从发现列表选择房间）统一为：

1. Demo 从本地身份存储读取 `deviceId`、`displayName`，构建 `RealtimeRequest`。
2. `Realtime.preJoin(...)` 运行检查，`createLocalPreview(...)` 获取可用的本地预览；UI 通过 `RealtimePreJoinPage` 呈现。
3. 用户确认后触发 `onEnter`，调用 `Realtime.open(request)`。
4. SDK 根据后端返回的 Provider、角色、短期凭证创建连接；只有成功建立后才由 Demo 导航到房间页面。
5. 连接所有者在房间路由结束后 `connection.dispose()`。失败应仍停留在 Pre-Join，便于重试；中途页面卸载必须释放已经建立但未接管的连接。

房间列表与当前默认 Provider 无必然对应关系：**已有房间始终绑定创建时的 Provider**。移动首页采用紧凑 Hero，桌面端保留完整介绍。布局优化不应改变上述流程。

## 4. 标准页面与组件边界

`flutter_realtime_sdk_ui` 维护唯一的完整页面：`RealtimeRoomView` 根据后端
权威模式选择 `RealtimeMeetingPage` / `RealtimeLivePage`，独立聊天使用
`RealtimeChatPage`。`RealtimeRoomViewConfig` 是对应配置；其模式字段仅作
无后端元数据时的提示，不能授予主播或教师权限。

| 组件 | 所有权 / 责任 |
| --- | --- |
| 标准会议/直播页面 | 响应式排版、侧栏/弹层、工具栏及交互展示 |
| `RealtimeRoomUiController` | 共享 UI 订阅、操作去重、权限与错误投影 |
| `RealtimeMeetingStage` | 聚焦/网格和权威共享内容展示 |
| Runtime `RoomMembersController` | 逻辑 RTC/IM 成员同步与管理 |
| `InitialMediaSettingsController` | 设备与初始媒体设置，处理房间切换竞态 |
| `flutter_realtime_media_ui` | Media Core + 设计系统上的独立组件，无 Runtime/Chat 依赖 |

摄像头、麦克风和屏幕共享仍由 SDK/provider 契约控制；RTC Data 不等于产品
Chat。完整页面和自定义组件共享同一套会话。卸载 UI 只释放订阅和界面资源，
连接所有者在房间路由结束后调用 `connection.dispose()`。

## 5. Pre-Join：公开页面与资源所有权

```dart
RealtimePreJoinPage(
  roomLabel: roomCode,
  displayName: displayName,
  runCheck: () => realtime.preJoin(role: MediaRole.participant, roomCode: roomCode),
  openPreview: (providerId, role) =>
      realtime.createLocalPreview(providerId: providerId, role: role),
  onEnter: (pageContext, settings) async {
    // 建立真实连接，然后使用仍 mounted 的 pageContext 导航。
    // settings 传入 RealtimeRoomViewConfig.initialMediaSettings。
  },
);
```

页面拥有 `RealtimePreJoinController`；底层预览所有者负责幂等释放，权限协调器
负责状态读取，设备设置控制器丢弃过期异步结果。失败留在同一页面重试；进入中
阻止重复提交。默认麦克风/摄像头关闭，设备枚举与背景选择不隐式采集。
阻断级检查失败不得入会，未知能力不能伪装成支持，受保护背景失败不得发布原始帧。

## 6. Demo Server：控制面模块

```text
demo-server/server.ts            导出公开单入口（npm start）
          └── app.ts             Express/注册表/全局中间件/依赖装配
                ├── routes/dashboard-routes.ts      Admin/Health/默认 Provider
                ├── routes/room-routes.ts           Create/Join/Discover/Leave/Close
                ├── routes/chat-routes.ts           独立及附着式 Chat
                ├── routes/interaction-routes.ts    Classroom/Live 互动 API
                └── routes/legacy-chime-routes.ts   参考后端遗留兼容路由
                     ↘ providers/, chat/, classroom/, live/
```

`app.ts` 负责依赖装配、通用中间件、路由注册以及定时回收调度。身份与角色规则、房间解析注册、并发锁/摘要、半关闭失败补偿、管理员会话鉴权、Provider 默认选择与持久化分别交给 `services/room-input.ts`、`room-registry-service.ts`、`room-operations.ts`、`room-closure.ts`、`admin-auth.ts`、`provider-selection.ts`。Dashboard Router 通过显式注入的可读写 Provider 选择状态保持切换行为。Node 服务端只做授权、短期凭证、逻辑房间、成员/互动控制和必要可信 Provider 管理调用；真正的媒体传输由 RTC 供应商负责。HTTP 请求与响应遵循 [MEDIA_BACKEND_CONTRACT](MEDIA_BACKEND_CONTRACT.md)、[CHAT_BACKEND_CONTRACT](CHAT_BACKEND_CONTRACT.md)，不应因重构改变状态码、鉴权、路径或合同版本。

请勿把 `DEMO_BEARER_TOKEN`、供应商 Secret、`roomOwnerCredential` 写进 Flutter 源码、日志或版本库；生产部署需接入真实业务身份、限流、持久化和可信密钥管理，Demo Server **不是生产后端模板**。

## 7. 测试与目前不应宣称的能力

### 本阶段已运行的回归

| 命令范围 | 当前记录 | 能证明什么 |
| --- | --- | --- |
| `packages/flutter_realtime_media_ui/flutter analyze` | 通过 | Dart/Flutter 静态检查 |
| Media UI 房间、Pre-Join、直播互动专项 `flutter test` | 50/50 通过 | Widget/Controller 离线行为 |
| `demo-server/npm run typecheck` | 通过 | TS 领域与路由类型一致 |
| `demo-server/npm test` | 67/67 通过 | HTTP/Provider 等离线契约行为 |

运行输出属于**开发期间的局部回归**；最终根工程与各 Provider 的全仓 quality gate、Demo 各平台构建和真实双设备连通性需要单独记录，不要从上述通过状态推断已经完成。

### 仍需独立验收

- Demo 创建/加入/发现房间的连接成功、失败、页面导航和重复提交，及 Web/Android/iOS/macOS 的实际交互。
- Pre-Join 系统级权限拒绝、设备拔插、背景处理像素级正确性、连接途中退出等真实设备场景。
- 各媒体 Provider 的双端上下行、屏幕共享、RTC Data、Product Chat、主持人真正踢人及云端资源清理。
- Windows runner 与真实 Windows 设备；平台/供应商不支持时明确报不支持。
- Demo Server 路由完整性与并发压力下的最终验收；后端存储非生产持久化方案。

这份文档同时充当 P1 代码迁移清单。阶段进度以 MCP Plan 为准；**尚未提交、推送或完成真实设备 E2E 的项目不得标记为发布完成**。

## 8. 推荐维护入口

- [主 README](../README.md)：SDK 产品入口和最短组合路径。
- [Demo 使用说明](../example/README.md)：如何运行 Demo、不同平台注意事项。
- [Media UI README](../packages/flutter_realtime_media_ui/README.md)：UI/房间模式/Pre-Join 接入。
- [Demo Server README](../demo-server/README.md)：服务端启动与控制面协议。
- [Clean Code 原始基线](P1_CLEAN_CODE_BASELINE.md)：变更前状态和回归对照。
- [SDK 工程质量](SDK_CODE_QUALITY.md)：错误与资源所有权。
- [能力矩阵](SDK_CAPABILITY_MATRIX.zh-CN.md)：供应商/平台能力，不应从 Demo 按钮推断支持。
