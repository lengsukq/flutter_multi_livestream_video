# SDK 能力矩阵

**简体中文** | [English](SDK_CAPABILITY_MATRIX.md)

应用应根据 `MediaCapabilities` / `MediaFeature` 判断当前可用功能，而不是根据
`providerId` 推断。不同平台和角色可能拥有不同的能力集合。

## 内置平台 Driver

`RealtimeSdk.standard()` 内置并维护以下路由表。业务代码在所有平台调用同一套
API，由 SDK 根据当前运行平台选择 Provider 实现。破折号表示 SDK 知道该 Provider，
但当前平台没有内置 Driver，会明确返回 `unsupportedPlatform`。

| 对外 Media Provider | Android | iOS | macOS | Windows | Web |
| --- | --- | --- | --- | --- | --- |
| LiveKit | 支持 | 支持 | 支持 | 支持 | 支持 |
| Agora RTC | 支持 | 支持 | 支持 | 支持 | 支持 |
| Tencent TRTC | 支持 | 支持 | 支持 | 支持 | 支持 |
| Alibaba ARTC | 支持 | 支持 | 条件支持* | — | 支持 |
| AWS | 支持 | 支持 | 支持** | — | 支持 |

| Product Chat Provider | Android | iOS | macOS | Windows | Web |
| --- | --- | --- | --- | --- | --- |
| Agora Chat | 支持 | 支持 | 支持 | — | 支持 |
| Tencent Cloud Chat | 支持 | 支持 | 支持 | 支持 | 支持 |
| Amazon IVS Chat | 支持 | 支持 | — | — | 支持 |

Linux 暂未注册到默认 Catalog。高级使用者仍可通过
`RealtimeProviderPlugin` 增加或覆盖 Driver，而无需修改 Core。

## 宿主应用要求

当前全量 SDK Demo 的最低目标为 Android API 28+（compile SDK 37）、iOS
15+、macOS 12+、Windows 10+，以及安全浏览器上下文中的标准 Flutter Web。
Android 构建使用 Flutter 3.47+、Dart 3.12+ 和 Java 17。单独使用低层
Adapter 包时，部分 Adapter 支持更低的 Android 版本。

Android 插件 Manifest 声明所需的运行时权限。宿主 iOS/macOS 应用必须提供
摄像头和麦克风用途说明；macOS 应用还需对应摄像头/麦克风 entitlement。
Demo 已包含这些设置。浏览器会请求设备访问权限，Web 部署必须使用 HTTPS
或 localhost。Pre-Join 和连接错误会通过 SDK 类型化诊断报告权限拒绝。

ARTC 的 iOS 二进制支持真机目标，但无法链接 iOS Simulator；因此 CI 使用
关闭代码签名的 iOS 设备目标构建。
`条件支持*` 表示 ARTC macOS 原生桥已经实现并通过构建，但仓库不重新分发
阿里官方 Mac framework；发布包未携带该 framework 时，Adapter 会明确返回
`unsupportedPlatform`，不会伪装成可用。

上表 Web 当前指标准 JavaScript Flutter Web 目标。`flutter build web`
已验证通过，但现有 Tencent Cloud Chat 依赖仍使用 `dart:html`、`dart:js`
以及 FFI 相关代码，因此 Flutter 的 Wasm dry-run 会报告不兼容；在上游依赖完成
迁移之前，不应把当前整套 Web Driver 宣称为 Wasm-ready。

macOS 已使用 CocoaPods 验证构建通过。AWS 的 `支持**` 表示完整 SDK 内部使用
同一个 WebKit Runtime：Meeting 加载锁定版本的 Chime JS，Live 加载锁定版本的
IVS Web Broadcast；业务代码仍只看到 `aws` 和统一 Dart API，不创建 WebView、
不加载脚本。Flutter 当前会提示部分插件尚未提供 macOS Swift Package Manager
支持；这是打包限制，不是本 SDK 的 Driver 路由失败。

当前验证环境为 macOS：Android Debug APK、iOS 真机 Release（关闭签名）、
macOS Release 以及标准 JavaScript Web 均已完成构建验证。上表中的 Windows
组合已经注册到默认 Catalog，并有平台选择单测覆盖；但 macOS 主机无法执行
Windows 原生构建。CI 配置了 Windows runner 构建；macOS 开发主机无法在本机生成
Windows 构建结果。

SDK 包自带 Web bridge 和锁定版本的供应商 JavaScript 资源。首次连接媒体或产品 Chat
时由 facade 自动加载；应用不需要维护 script 标签、CDN 链接或单独执行 npm 构建。
资源缺失或无法加载时返回 `webSdkUnavailable`。

AWS 对外统一展示为一个 Vendor，内部按模式路由：`Meeting -> Chime`、
`Live -> IVS Real-Time`。下表中的 Chime / IVS Real-Time 表示 AWS 内部 Engine 的能力。

| 能力 | LiveKit | Chime | Agora | TRTC | ARTC | IVS Real-Time |
| --- | --- | --- | --- | --- | --- | --- |
| Meeting 实时音视频 | 支持 | 支持 | 支持 | 支持 | 支持 | 支持 |
| Broadcast 直播房主/观众 | 支持 | 不支持（仅 participant） | 支持 | 支持 | 支持 | 支持 |
| RTC 数据发送 | 支持 | 支持 | 房主/participant | 房主/participant | 房主/participant | 不支持 |
| RTC 数据接收 | 支持 | 支持 | 支持 | 支持 | 支持 | 不支持 |
| RTC Chat fallback | 角色可发送时支持 | 支持 | 房主/participant | 房主/participant | 房主/participant | 不支持 |
| 单条 RTC 消息上限 | 15 KiB | 2 KiB | 1 KiB | 1 KiB | 1 KiB | — |
| 定向发送数据 | 支持 | 不支持 | 不支持 | 不支持 | 不支持 | 不支持 |
| 不可靠数据发送 | 支持 | 不支持 | 不支持 | 不支持 | 不支持 | 不支持 |
| 设备枚举/选择 | 支持，视平台而定 | 音频输出选择 | Adapter 未提供 | Adapter 未提供 | Adapter 未提供 | 麦克风/摄像头探测；切换摄像头仅 Android/iOS |
| 加入前原生设备探测 | 麦克风/摄像头 | 无 | 无 | 无 | 无 | 麦克风/摄像头 |
| 加入前 Provider 网络探测 | 需要房间凭证时不支持 | 无 | 无 | 无 | 无 | 需要参与者令牌时不支持 |
| 网络统计 | 支持 | Adapter 未提供 | 支持 | 支持 | Adapter 未提供 | 基础 RTC 统计 |
| 屏幕共享 | 发布者支持 | Adapter 未提供 | 暂未实现 | Adapter 未提供 | Adapter 未提供 | Adapter 未提供 |
| 房主查看参与者列表 | 后端验证逻辑房主 | Meeting 创建者通过逻辑房主凭证 | 后端验证逻辑房主 | 后端验证逻辑房主 | 后端验证逻辑房主 | 后端验证逻辑房主 |
| 房主移除参与者 | 支持 | 不支持 | 不支持 | 不支持 | 不支持 | 通过 IVS `DisconnectParticipant` |
| 房主关闭房间 | 后端支持 | Meeting 创建者通过控制面关闭 | 后端支持 | 后端支持 | 后端支持 | 后端支持 |

Meeting 是多人双向音视频模式。Broadcast 是一对多直播模式：房主发布音视频，观众订阅观看。
Chime 当前只提供 participant 角色，不支持房主/观众直播角色。

## 产品聊天

产品聊天不由音视频 Provider 或 `MediaCapabilities` 决定，使用
`flutter_realtime_chat_core` 的 `ChatSession` / `ChatCapabilities`。

| 能力 | Amazon IVS Chat | Tencent Cloud Chat | Agora Chat | RTC Data fallback |
| --- | --- | --- | --- | --- |
| 发送消息 | 支持 | 支持 | 支持 | Media 同时支持双向 Data 时支持 |
| 接收实时消息 | 支持 | 支持 | 支持 | 支持 |
| 删除消息 | 房主/管理员令牌：客户端执行 | Demo 普通成员凭证不开放；可由自建 owner/admin 凭证扩展 | Demo 普通成员凭证不开放；可由自建 owner/admin 凭证扩展 | 不支持 |
| 断开用户 | 房主/管理员令牌：客户端执行 | Demo 走参考控制面 REST；供应商 owner/admin 凭证可声明 client | Demo 走参考控制面 REST；供应商 owner/admin 凭证可声明 client | 不支持 |
| 成员列表 | Demo 控制面逻辑成员列表 | Demo 控制面逻辑成员列表 | Demo 控制面逻辑成员列表 | 不提供管理目录 |
| 管理执行策略 | client 优先，必要时 backend | 当前 Demo 为 backend；真实 owner/admin 凭证可 client | 当前 Demo 为 backend；真实 owner/admin 凭证可 client | unsupported |
| 重连时自动刷新凭证 | 支持 | 支持 UserSig 刷新 | 支持 Token 刷新 | 跟随 MediaSession |
| 服务端消息历史 | IVS Chat 服务能力；Core v1 未提供历史分页 | Tencent Chat 服务能力；Core v1 未提供历史分页 | Agora Chat 服务能力；Core v1 未提供历史分页 | 仅当前会话内存 |
| 是否依赖音视频 Provider | 否，可独立选择 | 否，可独立选择 | 否，可独立选择 | 是 |

内置 UI 的用户聊天始终只消费 `ChatSession`。房间绑定独立产品 Chat Provider 时，
该 `ChatSession` 始终优先；房间没有绑定产品 Chat 时，只有当前 MediaSession 同时支持
RTC 数据发送和接收，`flutter_realtime_chat_rtc` 才会创建会话级 fallback。
独立产品 Chat 连接失败时不会自动降级到 RTC fallback。

原始 RTC Data 仍是独立的媒体传输/Debug 能力；`showRtcDataMessages` 不会把调试负载
注入 Chat 消息列表。RTC fallback 只保留当前会话内消息，没有服务端历史或管理员能力。
聊天能力与麦克风/摄像头发布权限完全独立。

管理能力通过 `ChatManagementExecution` 明确标记为 `client`、`backend`、
`hybrid` 或 `unsupported`。高层 `RealtimeChatModeration` 优先执行
Provider 客户端能力，只有供应商权限模型确实要求服务端管理员 API 时才回退到可选
control-plane。因此使用者不需要按 Provider 写分支，也不需要为了管理能力把长期密钥下发到 App。

## Provider 无关 API

### 加入前检查

`MediaClient.runPreJoinCheck()` 在创建或加入房间前提供统一的就绪状态。Core 会检查后端可达性、目标
Provider 是否已注册、权限状态、设备可用性（Provider 支持时）和基础网络可达性。Adapter 可通过
`MediaPreJoinProbe` 增加检查。

- `required` 检查为 `failed`、`unsupported` 或 `unknown` 时会阻止继续。
- `recommended` 检查未通过时显示警告，不阻止继续。
- `skipped` 表示不执行该检查。
- Adapter 不应把未实际执行的检查报告为 `passed`。
- 需要正式房间凭证才能执行的 Provider 网络探测应返回 `unsupported`，不能为了诊断而创建房间。

后端 `GET /health` 是可选诊断接口，不是 Backend Contract 的必要条件。接口不存在时可显示警告；网络
传输或超时错误属于网络失败；已实现的健康接口明确返回错误时属于后端失败。

### 房间发现

`MediaClient.listRooms()` 返回轻量级 `MediaRoomSummary`。发现接口不暴露用户/设备身份、参与者 ID 或
Provider 凭证。

### 设备与统计

会话可通过 `listMediaDevices()` / `selectMediaDevice()` 使用其已声明支持的设备能力。Core 也提供
`listMicrophones()`、`listCameras()`、`listAudioOutputs()`、`selectMicrophone()`、`selectCamera()` 和
`selectAudioOutput()` 等统一方法。未支持的操作应返回 `MediaErrorCode.unsupportedFeature`。

支持 RTC 指标的 Provider 实现 `MediaStatsProvider`。应用可读取最新的
`session.connectionStats`，也可订阅 `session.stats`；Adapter 不会伪造 Provider 未提供的数据。

### 数据消息与恢复

`session.sendData(...)` 是高级数据发送接口；旧的 `sendMessage(...)` 保持兼容。
`MediaSendOptions` 描述 topic、目标参与者、可靠性和顺序要求。Core 会根据
`MediaCapabilities` 校验请求语义及消息大小限制。
Provider 收到的数据消息统一通过 `session.dataMessages` 暴露；`canReceiveData` 与
`canSendData` 分开声明，从而能区分只能发送/只能接收与真正可双向 fallback 的角色。

`MediaRoomSession.recoveries` 将重连中、恢复成功和失败状态统一为恢复事件，同时保留逻辑参与者身份。
Provider 凭证刷新仍需保持 Provider、房间、角色和参与者身份不变。

### 房主管理

房主管理权限由后端验证。`MediaRoomSession.listParticipants`、`removeParticipant` 和 `closeRoom` 会把当前
参与者 ID 与凭证发给后端，由后端检查已登记的房主身份。客户端本地的 `MediaRole.host` 值本身不能授予
管理权限。

## 接入新 Provider

Adapter 只能声明实际实现的能力。新功能应先映射到 Provider 无关模型；高级场景可由 Adapter 包额外提供
Provider 专属接口。未支持的操作应返回有类型的错误，不能静默成功。

只有在无需加入房间即可执行真实诊断时，才应实现 `MediaPreJoinProbe`。不可用的检查应明确返回
`unsupported` 或 `unknown`，并保留 Core 指定的检查级别。
