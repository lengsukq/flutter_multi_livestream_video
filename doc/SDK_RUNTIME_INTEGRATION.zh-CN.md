# Flutter Realtime SDK：纯功能调用与可选 UI 接入

本指南只提供 SDK 接入方法与**短代码片段**，不新增 Headless 示例工程或第二套 Demo。现有 `example/` 只演示如何自由组合 SDK 自带的 UI 组件。

## 1. 依赖边界

应用使用纯功能 API 时，只需依赖 `flutter_realtime_sdk` 与选中的 `flutter_realtime_provider_*` 包；不需要 `flutter_realtime_sdk_ui`。主 SDK 的生产依赖只有 `flutter_realtime_sdk_runtime`，并通过 Runtime 传递依赖必要领域 Core（视频特效和系统桥接等为当前 Runtime 自身能力）。不注册供应商时 SDK 不会自动拉取任何特定供应商。

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_realtime_sdk:
    path: ../packages/flutter_realtime_sdk
  flutter_realtime_provider_livekit:
    path: ../packages/flutter_realtime_provider_livekit
```

其他可选 Provider：`flutter_realtime_provider_agora`、`_trtc`、`_artc`、`_aws`、`_agora_chat`、`_ivs_chat`、`_tencent_chat`。这些后缀均接在 `flutter_realtime_provider` 后面。AWS 公开 Provider 对 Meeting 使用 Chime，对 Live 使用 IVS。不要在 Flutter 客户端保存厂商长期 Secret。

## 2. 创建、加入与退出

```dart
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_realtime_provider_livekit/flutter_realtime_provider_livekit.dart';

final realtime = Realtime(
  backendUrl: 'https://your-backend.example',
  providers: [createLivekitProvider()],
);
final connection = await realtime.open(
  RealtimeRequest.join(
    type: RealtimeExperience.meeting,
    roomCode: 'room-code',
    user: const RealtimeUser(id: 'user-1', name: 'Alice'),
  ),
);
final room = connection.mediaRoom!;
final subscription = room.media.session.snapshots.listen((snapshot) {
  // 使用 immutable snapshot 更新宿主自己的任意 UI / 状态容器
});
// 仅当明确退出、销毁业务房间时：
await subscription.cancel();
await connection.dispose();
```

`RealtimeExperience.live` 用于直播；`RealtimeExperience.chat` 用于独立聊天。`RealtimeRequest.create` 与 `join` 使用同一身份结构。也可使用 `RealtimeSource.credentials` 传入业务后端签发的临时凭据，不要求使用仓库的 Demo Server。Web 的 Provider Bundle 自带按需 JS 加载回调；优先使用 `Realtime(providers: [...])` 而非手动拼接资源路径。

## 3. Media、Chat、直播与课堂的纯功能操作

```dart
final media = room.media.session;
if (media is InteractiveMediaSession) {
  await media.setMuted(false);
  await media.setVideoEnabled(true);
  if (media.capabilities.canScreenShare) {
    await media.setScreenShareEnabled(true);
  }
}

// 使用 Flutter 自己决定视频尺寸、排序、背景等，而不是整页模板：
// MediaTrackView(renderer: room.renderer, track: participant.videoTrack)

final chat = connection.chatSession;
if (chat?.capabilities.canSendMessage == true) {
  await chat!.sendMessage('Hello');
}
await room.liveInteractions?.sendLike(); // 当前房间具备 Live 会话时
await room.classroom?.raiseHand();       // 当前房间具备课堂权限时
```

`RealtimeRoom` 提供 `states`、`events`，底层 `MediaSession` 还提供 `snapshots`；聊天提供 `messageSnapshots`。**事件流为 broadcast，不保证新订阅者收到历史事件，订阅时同时读取当前 state/snapshot。** UI 的创建、重建与销毁不会断开媒体会话，退出请显式 `connection.dispose()`。

## 4. RTC + IM 成员与权限

与 Widget 无关的统一 RTC/IM 身份合并、成员列表、单人管理、批量静音、部分失败重试已位于 Runtime。

```dart
final directory = room.memberDirectory;
final result = await directory.load(
  room.media,
  chatSession: room.chat,
  chatModeration: room.chatModeration,
  isCurrent: () => true, // 实际集成时检查当前房间是否仍有效
);
final members = mergeSnapshotMembers(
  result.members,
  room.media.snapshot,
  localRole: room.media.role,
);
await directory.manageMedia(
  room.media,
  'target-participant-id',
  RoomMediaMemberAction.mute,
);
final batch = await directory.muteAll(room.media, isCurrent: () => true);
// batch.failures 记录失败成员及对应错误，可按失败成员再次提交 targets
```

Room 所在后端与各 Provider 负责权限最终裁决，SDK 依据能力矩阵拒绝不支持的操作。聊天室的 `room.chatModeration` 与 RTC 的 `room.mediaModeration` 互相独立。批量静音只是多次调用既有权限受控接口，不绕过服务端授权。

Classroom / Live 可选服务由 `RealtimeRoom.initialize()` **在 Runtime 内启动一次**；UI 控制器不再负责启动，重复调用 initialize 不会重复创建轮询。初始失败通过 Runtime 事件报告，不应把仅课堂/直播辅助服务的错误当成媒体会话断开。退出时由 Room 统一清理辅助会话。

## 5. Pre-Join 与平台差异

纯功能调用 `realtime.preJoin(...)` 获取诊断，`realtime.createLocalPreview(...)` 创建可选预览；预览由调用方显式销毁。能力、角色与平台差异均通过 `MediaCapabilities` / `ChatCapabilities` / Provider 注册信息判断。视频虚拟背景、屏幕共享、设备枚举、录制等功能受对应平台与供应商的实际能力限制，不能仅凭统一 API 推断全部可用。

## 6. 可选 SDK UI（当前 Demo 唯一定位）

需要快速搭建页面时，额外添加 `flutter_realtime_sdk_ui`：

```dart
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';

RealtimeRoomUiScope(
  room: room,
  child: const Column(
    children: [
      Expanded(child: RealtimeVideoGrid()),
      Row(children: [
        RealtimeMicrophoneButton(),
        RealtimeCameraButton(),
      ]),
    ],
  ),
);
```

宿主自由决定 `Scaffold`、路由、`Row` / `Column` / `Stack`、弹窗与多端断点。现有 `example/lib/demo_composable_*_page.dart` 是 UI 快速组装的参考，不承担第二套业务逻辑；完整 `RealtimeComposableRoomTemplate` 为可选快捷模板。

## 7. 验证

从仓库根目录运行 `python3 scripts/check_sdk_architecture.py` 验证主包/Runtime 无强制 UI 与 Provider 依赖；`python3 scripts/check_sdk_quality.py --resolve --analyze --test` 进行跨包静态/自动化验证。真正的供应商双设备 E2E 和平台安装包大小需要单独记录，不能由纯 Dart 测试或 Web JS 字节数代替。
