# AGENTS.md — flutter_multi_livestream_video 项目级规范

> 本文件随 git 跟踪，是通用 agent 的项目级提示词注入。
> 本地私有的 prompts / skills 一律不进 git（见 `.gitignore`）。

## 1. AWS 凭证规范（强制）

> 原则：只认 profile 名字，不碰明文 Key。

### 1.1 可用 profile

| profile | 身份 | 用途 |
|---|---|---|
| `chime-demo` | IAM user，最小权限 | **默认**：日常 Demo / CLI / 后端调用全用它 |
| `lengxiaoying599` | root | **封存**：只用来建/删 IAM 用户，平时不用 |
| `oxpecker` | IAM user `leo` | Oxpecker 业务账号，**与本项目无关，不要混用** |

其他业务 profile（`self` / `rechic` / `build-surety` 等）一律不用于本项目 Demo。
勿用账号 `739280997854`（已收到永久关闭通知，不要在其上建任何资源）。

### 1.2 调用铁律

1. 默认 profile 就是 `chime-demo`：`export AWS_PROFILE=chime-demo`，
   或每条命令显式加 `--profile chime-demo`。
2. Chime **控制面固定 `us-east-1`，媒体面用 `ap-southeast-1`**：
   ```bash
   aws chime-sdk-meetings create-meeting \
     --region us-east-1 --media-region ap-southeast-1 \
     --profile chime-demo \
     --client-request-token "demo-$(date +%s)" \
     --external-meeting-id <demo-id>
   ```
3. `chime-demo` 使用最小权限、仅针对录制 Bucket 和 AWS 录制服务授权，**没有** `iam:*` / `s3:*` 通配权限；现已允许对指定录制 Bucket 使用 `s3:GetBucketPolicy` 等受限 S3 操作。
   `aws iam list-users --profile chime-demo` 报 `AccessDenied` 是**预期正确**，不是故障。策略与 Bucket Policy 详见 [AWS S3 云录制权限配置](doc/AWS_S3_RECORDING_PERMISSIONS.md)。
4. root（`lengxiaoying599`）只做 IAM 管理，不直接 `create-meeting` 跑 Demo。
5. **AK/SK 永不进 Flutter 包、永不进 git、永不贴到聊天记录。**
   新 Key 的 Secret 只出现一次，丢了就删了重建，不找回。

### 1.3 计费红线

`CreateMeeting / CreateAttendee` 本身不计费，**真人进会**才按 `attendee-minute` 计费。
Demo 验证完立即删会，探路会议必须清零，`get-meeting` 返回 `NotFoundException` 才算删干净：

```bash
aws chime-sdk-meetings delete-meeting \
  --meeting-id <MeetingId> --region us-east-1 --profile chime-demo
```

### 1.4 出问题先查这三条

1. `InvalidClientTokenId` = AK 在云端已不存在（轮换/删除/账号关闭），不是本地格式问题；
   `SignatureDoesNotMatch` 才怀疑 Secret 写错。
2. 新建 IAM Key 有数秒传播延迟，刚建完 `sts` 失败等 10 秒再试。
3. 策略要写 `chime:*` + `chime-sdk-meetings:*` 双命名空间，只写一边会放行失败。

## 2. 项目定位与代码规范

> 本章描述本仓库是什么、代码往哪个方向写、以及什么算不合格。
> 涉及 AWS 账号、profile、凭证的内容一律以第 1 章为准，本章不重复、不复制任何密钥。

### 2.1 定位：SDK 是产品，Demo 是快速构建的展示场

本仓库是一个 **provider-neutral 的 Flutter 实时音视频 SDK monorepo**，
用同一套 Dart API 支撑会议（meeting）、直播（live）、IM 聊天、课堂互动、
白板与批注，底层可切换 LiveKit / Agora / TRTC / Chime / ARTC / IVS。

- **SDK（`packages/`）是真正的资产**，可发布给外部接入方使用。
- **Demo（`example/` + `demo-server/`）是快速构建的展示场**，
  用来证明 SDK 在真实链路下可行。Demo 不享有特权，使用的必须是公开 API。
- 仓库名 `flutter_multi_livestream_video` 是历史名；真正的 pub 包是
  `flutter_aws_chime`，根目录只是 tooling workspace（`publish_to: none`）。

### 2.2 流向规则（最核心）

1. Demo 里跑通的能力，必须抽象回 SDK 的 provider-neutral 契约。
2. **不在 `example/` 沉淀业务逻辑**，不给 Demo 开后门或私有捷径。
3. 新增 showcase 页面时先问："这个能力该不该进 SDK？"该进就抽进 `packages/`，
   Demo 只留组装与展示。
4. 宁可 Demo 少做，也不让 SDK 为 Demo 变形。

### 2.3 Monorepo 地图

```text
应用 / Demo
  └─ flutter_realtime_sdk                 轻量 facade，只依赖 runtime，无内置 provider/UI
       └─ flutter_realtime_sdk_runtime    Realtime / RealtimeRoom / 成员 / 生命周期 / 插件注册
            ├─ Domain Core（纯契约，无厂商依赖）
            │    foundation / media_core / chat_core / classroom_core
            │    live_core / whiteboard_core / interaction_core
            ├─ Provider 适配（各自 _media_* / _chat_* / provider_* bundle）
            ├─ 可选预设（显式注册才实例化）
            │    classroom_preset / live_preset
            └─ 可选 UI
                 sdk_ui / media_ui / chat_ui / classroom_ui / live_ui / whiteboard_ui
```

- 完整包清单见 `scripts/sdk_packages.json`（41 个），新增包必须登记。
- 关键文档：`doc/INTERACTION_ARCHITECTURE.md`、`doc/SDK_CODE_QUALITY.md`、
  `doc/LIGHTWEIGHT_SDK.md`、`doc/PROVIDER_ADAPTER_GUIDE.md`、
  `doc/P1_CLEAN_CODE_BASELINE.md`。

### 2.4 依赖方向红线

以下约束已有工具强制，**违反即 analyze/架构检查失败**，不要试图绕过：

1. core 包**永不 import 厂商 SDK**；adapter 把厂商事件/Track 翻译成 core 模型。
2. runtime **零 UI、零厂商依赖**。
3. 课堂/直播是**可选插件**，`featurePlugins` 不注册就不创建 session；
   `room.classroom` / `room.liveInteractions` 是可选包的 extension getter，不是 Room 成员。
4. `flutter_realtime_sdk` 只依赖 runtime；provider 与 UI 一律由宿主显式注册。
5. Media 与 Product Chat 是两条独立轴，可分别选不同厂商。

违反以下任一项会被拒绝：

- 依赖环；runtime 里出现 `_ui` / `provider_*` / 非 core 的 `media_*`
- 跨包 `implementation_imports`（即 import 别人的 `src/`）

### 2.5 交互三件套语义（不可混淆）

| 概念 | 语义 | 边界 |
|---|---|---|
| **Transient event** | RTC Data 传递的版本化房间信封 | best-effort，`sender` 字段**不是可信身份** |
| **Command** | 需要权限/计费/持久化的动作 | 必须走注入的可信 `controlPlane`；RTC/IM 消息只能"通知去拉取"，不能授权 |
| **Snapshot** | 后端权威状态 | revision 单调递增；倒计时用服务端 `endsAt`，不用本地计时器 |

revision hint 只是失效通知，永不等于状态本身。

### 2.6 Clean Code 规范

analyze 已强制：`package:lints/recommended` + `unawaited_futures` +
`discarded_futures` + `implementation_imports`，以及
`strict-casts` / `strict-inference` / `strict-raw-types`。
**analyze 报错就是红线，不是建议。**

以下是不在工具覆盖范围内、但决定代码质感的部分：

#### A. 命名与文件

- 一个 public 概念一个文件，文件以主类型命名。
- 公开 API 只在包的 barrel 文件导出；`src/` 内部实现不进 public API。
- 不手工换行/对齐，不与 `dart format` 打架。
- 命名表达意图，不用 `data` / `info` / `manager` / `helper` 兜底。

#### C. 类型与 null 安全

- 不用 `dynamic`，不用 `Object?` 装业务值；用具体类型或 record/sealed class。
- 状态用 sealed class 建模（idle/loading/success/error），
  而不是用一组裸 bool + nullable 字段拼出状态机。
- 公开集合返回不可变快照；不把内部可变状态暴露给外部。

#### D. 错误与异常

- 全域用 `RealtimeException` + `RealtimeErrorCode`；
  message 只含 stage 名，不带原生/HTTP 原始 payload。
- 不写 `catch (e) {}` 吞异常：要么上报 `reportError`，要么带上下文重抛。
- 不在 UI 层 catch 后弹个 SnackBar 掩盖 SDK 错误；SDK 错误如何呈现由业务决定。

#### E. 并发与生命周期

- 任何持有订阅 / Timer / StreamController 的类必须实现 `dispose`，
  且幂等、并发重复调用共享同一 future。
- `mounted` 检查只保护 `setState`，不替代 cancel。
- 异步入口先校验权限再开摄像头；取消/枚举设备/选背景都不得触发隐式采集。
- Pre-Join 默认麦克风与摄像头**全关**。

#### F. 测试

- 新增公开契约必须有单测；测试名描述**行为**，不描述函数名。
- 行为修复要同时改测试断言，并说明这是修复而非迁就。
- 测试失败先对照基线 `doc/P1_CLEAN_CODE_BASELINE.md`，
  区分"既有问题"还是"本次新回归"，不要把新回归说成既有问题，反之亦然。

#### G. Demo 代码质量

- Demo 与 SDK 用**同一套 lint**，禁止在 `example/` 放宽规则。
- Demo 不实现业务逻辑：课堂/礼物只注册 preset，不复制 SDK 业务实现。
- 身份持久化归**单一 adapter**，不塞进 widget。
- showcase 页面优先复用 `sdk_ui` / `media_ui` 组件，不自己重造样式。

### 2.7 质量门禁

改动 SDK 代码后，在仓库根目录执行：

```sh
python3 scripts/check_sdk_quality.py --resolve --analyze --test
python3 scripts/check_sdk_architecture.py
python3 scripts/format_sdk.py --check
python3 scripts/generate_capability_matrix.py --check
```

- vendored WebRTC 与 `flutter_aws_chime` 保留其原有 lint 策略，
  不参与 SDK 工具的格式化与 lint 变更。
- 只改单个包时，可先在该包内跑 analyze/test 做快速反馈，再跑全量门禁。

### 2.8 Demo 快速构建工程约定

- `demo-server` 是**唯一后端入口**（`npm start`），Provider 切换走
  `/api/overview`，不得为新厂商在房间 create/join/heartbeat 等路由里加分支。
- 后端选择 provider，Flutter 侧只发送请求；**Flutter 永不指定 provider**。
- Demo Server 保持"路由只校验并委派服务"的形状，特权凭证与房间状态留在服务端。
- 构建与平台注意事项以 `doc/DEVELOPMENT.md` 为准（iOS 本地 checkout 目录名、
  macOS 依赖管理器开关、Windows 需要 Windows runner），本章不重复。

### 2.9 验收边界

本地单测、analyze、构建通过 **不等于**真机、多端、远端处理后像素、
Windows runner 或云端资源清理的验收。这些是**分开的证据类别**，
按 `doc/ACCEPTANCE.md` 等文档分别记录。

- 没实际跑过的真实厂商 / 多端 / 构建验证，不要标记为完成。
- AWS 云资源的清理验证规则见第 1.3 节。
