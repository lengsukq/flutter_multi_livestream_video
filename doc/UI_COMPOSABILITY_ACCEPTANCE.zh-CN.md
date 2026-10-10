# Flutter Realtime UI 组件化：架构、接入与验收

> 状态：2026-10-10，本地静态/自动化/构建验收记录。真实云厂商与真机联网验收是独立的工作，不因 Widget 测试通过而视为已完成。主目标是 **SDK 管状态与命令，App/Demo 决定布局**。

## 1. 模块依赖与资源所有权

```text
flutter_realtime_foundation + domain_core
  ├─ flutter_realtime_sdk_runtime     (无 UI、无具体 Provider driver)
  ├─ flutter_realtime_chat_ui         (仅 Chat Core + Flutter)
  └─ flutter_realtime_media_ui        (Media Core + Chat UI，旧模板可选)
       ↑
flutter_realtime_sdk_ui                (可选聚合：Room、Live、Chat、Classroom、Whiteboard)
       ↑
App / Demo (Scaffold / Row / Column / Stack / Navigator / Breakpoints)

flutter_realtime_sdk                  (轻量公开入口，仅依赖 Runtime)
```

使用 `flutter_realtime_chat_ui` 不需要引入会议/直播及原生 RTC SDK；无 UI 的工程直接引用 Runtime 和需要的 Driver；真正的移动/桌面包体必须以各自的 Release 构建测量，而非凭源码行数推断。

资源生命周期：

- `RealtimeRoomUiScope(room: ...)` **持有并销毁它创建的 UI Controller**，不会在 widget unmount 时断开 Provider 会话；传入自建 controller 时，调用者负责释放 UI controller。
- `RealtimeRoomUiController.leave()` 会退出/销毁底层 room，应用负责路由导航。
- `RealtimePreJoinController` 由应用创建、`initialize()`，页面销毁时由应用 `dispose()`；重试/进入房间释放预览由 Controller 管理。
- `ChatUiController` 只拥有 UI 订阅，不拥有 `ChatSession`。同一 `RealtimeRoomUiScope` 中的列表与输入框共享 Chat UI controller。
- 成员权限以 `MediaRoomSession.managementCapabilities` 和 `ChatManagementCapabilities` 为准；`RoomMembersController` 已迁移至 Runtime，UI 只展示结果、处理 pending/error；UI 不签发 Token，不独立裁决权限。

## 2. 两种可运行的组织方式

**默认快速模板：** App 打开 `RealtimeRoom` 后直接渲染：

```dart
RealtimeComposableRoomTemplate(
  room: room,
  isLive: false, // 直播传 true
  onLeft: () => Navigator.of(context).maybePop(),
)
```

独立 Chat 用 `ChatDefaultPage(session: chatSession, roomCode: roomCode)`。
预加入使用 `RealtimeComposablePreJoinTemplate(controller: controller,
onEnter: (settings) async { /* 调用 App 的统一 open/join */ })`；必须在
宿主的 init/dispose 时初始化/清理该 `RealtimePreJoinController`。历史
`MediaRoomView`、`RealtimeRoomView`、`RealtimeChatView`、
`MediaPreJoinPage` 为保留高级操作和原 UI 风格的**可选旧模板**。

**完全自由布局：**

```dart
RealtimeRoomUiScope(
  room: room,
  child: Scaffold(
    body: Column(
      children: [
        const Row(children: [
          Expanded(child: RealtimeRoomInfo()),
          RealtimeLeaveButton(), // App 自己决定位置/导航
        ]),
        const Expanded(child: RealtimeSharedContentStage(
          members: RealtimeVideoGrid(),
        )),
        const Wrap(children: [
          RealtimeMicrophoneButton(),
          RealtimeCameraButton(),
          RealtimeSwitchCameraButton(),
          RealtimeScreenShareButton(),
        ]),
      ],
    ),
  ),
)
```

用户可把任一 `Realtime*` 功能组件移到抽屉、弹窗、悬浮层、会议页面任何区域，不依赖父级 `MediaRoomLayoutHost` 或供应商的具体 Session 类型。

## 3. 可复用组件目录

| 领域 | 公开 UI | SDK 权威逻辑 |
| --- | --- | --- |
| 房间 | `RealtimeRoomInfo`、`RealtimeConnectionIndicator`、`RealtimeVideoTile`、`RealtimeVideoGrid`、`RealtimeScreenShareStage`、`RealtimeSharedContentStage` | MediaSnapshot、SharedContentState |
| 媒体控制 | `RealtimeMicrophoneButton`、`RealtimeCameraButton`、`RealtimeSwitchCameraButton`、`RealtimeScreenShareButton`、`RealtimeLeaveButton`、`RealtimeBackgroundEffectsButton` | UI Controller + MediaCapabilities + Video Effects |
| 设备 | `RealtimeMediaDevicePicker`（microphone / camera / audioOutput）、`RealtimeAudioOutputButton` | MediaDeviceController，可选能力、失败原样报告 |
| 成员管理 | `RealtimeParticipantList`（RTC-only）、`RealtimeManagedParticipantList`（RTC+IM）、`RealtimeBulkMuteButton` | Runtime `RealtimeRoom.memberDirectory`：统一逻辑 userId、主持人权限、静音失败重试 |
| 聊天 | `ChatUiScope`、`ChatSearchField`、`ChatMessageList`、`ChatComposer`、`ChatMemberList`、`ChatManagementButton`、`ChatDefaultPage`；会议组合的 `RealtimeChatPanel` | ChatUiController / ChatModeration / IM |
| 直播 | `RealtimeLiveVideoStage`、`RealtimeLiveLikeButton`、`RealtimeLiveGiftButton`、`RealtimeLiveStatus` | LiveInteractionSession |
| 课堂 | `RealtimeRaiseHandButton`、`RealtimeClassroomHandQueue`、`RealtimeClassroomRoster`、`RealtimeClassroomQuestions`、`RealtimeClassroomQuestionComposer`、`RealtimeClassroomFeedbackButton`、`RealtimeClassroomToolsButton`、`RealtimeClassroomActivityList`、`RealtimeClassroomEngagement` | ClassroomSession + authoritative classroom snapshot |
| Pre-Join | `RealtimePreJoinScope`、`RealtimePreJoinPreview`、`RealtimePreJoinCheckList`、`RealtimePreJoinPermissions`、`RealtimePreJoinMediaControls`、`RealtimePreJoinDevicePicker`、`RealtimePreJoinBackgroundSelector`、`RealtimePreJoinJoinButton` | RealtimePreJoinController：权限/设备/预览/进房竞态 |

Demo 页面位于 `example/lib/demo_composable_{meeting,live,chat,pre_join}_page.dart`。
常见断点和页面导航属于 Demo，而不是 SDK Widgets。

## 4. 旧 UI 收敛说明

- `realtime_ui_style.dart` 分离基础视觉、控件、卡片/对话框。
- `media_room_view.dart` 拆出 `RoomChatEventsController`、
  `RoomAuxiliarySubscriptions`、`RoomMembersController`、
  `legacy_room_media_stage.dart`、`room_members_actions.dart` 等。
- `realtime_chat_view.dart` 已使用 `ChatUiController`，原输入/管理
  视图拆至 `legacy_chat_actions.dart`；Pre-Join 的业务控制器也可脱离整页运行。
- `RealtimeRoomView` 与组合式视图共用 SharedContentStage renderer；
  旧完整模板保留的高级 UI 功能**不能**在未完成等价验证前直接删掉。

## 5. 自动化、构建与仍待验证事项

本地验收命令：

```sh
python3 scripts/check_sdk_architecture.py
python3 scripts/check_sdk_quality.py --resolve --analyze --test
python3 scripts/format_sdk.py --check
flutter build web --release --no-pub  # 在 example 目录执行
```

全仓包清单包含 `flutter_realtime_chat_ui`，应验证无循环依赖、Runtime
无 UI 依赖、没有跨包 `src/` 私有类型导入。独立 Widget 测试覆盖不同窗口尺寸、
Chat 单订阅、RTC/IM 成员身份合并、主持人 capability、设备选择、房间切换订阅
释放、媒体操作去重、Pre-Join 重试、直播/课堂组合。

2026-10-10 Web **Release 构建成功**；`example/build/web/main.dart.js`
最终复测产物大小 **4,579,427 bytes**（未压缩、未计其他资源）。这**不是**
按需依赖改造前后的 A/B 比较，也不是 APK/IPA/macOS 体积；WASM dry-run
另有不兼容依赖警告，不可称已通过 WASM。

**最终本地验收结果（2026-10-10）**：

| 项目 | 结果 |
| --- | --- |
| 37 包 `python3 scripts/check_sdk_quality.py --analyze --test` | 通过，`Failures:` 空 |
| `python3 scripts/check_sdk_architecture.py` | 通过：37 包依赖无环、Runtime 无 UI 依赖 |
| `python3 scripts/format_sdk.py --check` | 通过：485 Dart 文件、0 待格式化 |
| `python3 scripts/generate_capability_matrix.py --check` | 通过；声明文档已重新生成 |
| `flutter analyze --no-pub`（Demo） | 无问题 |
| `flutter test --no-pub`（Demo） | 14/14 通过 |
| `flutter build web --release --no-pub`（Demo） | 构建成功；WASM dry-run 仅发出警告 |
| `git diff --check` | 通过 |

上述验收面向当前仓库代码和 Web 编译产物；与真实远端 Provider
连接或各 OS 原生权限、音视频采集的端到端验收是两个不同维度。

**真实厂商与真机待验**（不能用 Fake / Widget tests 代替）：
Android、iOS、Web、macOS、Windows 的媒体捕获、渲染、屏幕共享、
前后摄像头、虚拟背景处理帧、音频设备输出选择；LiveKit、Agora、AWS
Chime/IVS、TRTC、ARTC 的双端 RTC/IM、host 权限/设备 E2E；课堂授权/
撤权、送礼、点赞、网络重连、多设备用户身份。缺少真机、长期运营
凭证或可连接测试服务时，以上事项只能标记 `blocked/unverified`。

后续想测“轻量接入节省多少”时必须对同一平台、相同 Dart/Flutter
版本分别构建：①仅 Runtime+指定 Provider ②Runtime+chat_ui
③sdk_ui 聚合 ④全 Provider `flutter_realtime_sdk`，对比 Release
安装包/JS 产物（必要时 gzip）及构建日志，不能简单相减源码体积。
