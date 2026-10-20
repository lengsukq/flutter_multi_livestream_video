# 会议模式与交互反馈

SDK 提供模式契约、插件选择、共享内容会话、角色入口及反馈组件。Demo 只选择模式并调用公开 API；后端负责保存模式和校验权限。

## 接入与兼容

```dart
final connection = await realtime.open(
  RealtimeRequest.create(
    type: RealtimeExperience.meeting,
    user: user,
    meetingMode: MediaMeetingMode.standard,
  ),
);
```

- `MediaMeetingMode.standard` 为普通会议，`classroom` 为课堂；不改变媒体的 meeting/broadcast 模式，也不选择厂商。
- 创建时发送 `meetingMode`，后端保存并在创建、加入、凭证刷新、房间发现中返回。加入者不能改变模式。
- `MediaRoomSession.meetingMode` 和 `MediaRoomSummary.meetingMode` 提供可信响应中的模式；`MediaPreJoinResult.meetingMode` 提供发现结果。预加入展示只是提示，连接后的后端结果为准。
- 旧调用不传字段，存量会议缺少字段时继续按课堂处理。显式普通模式若未获后端确认，SDK 在加入媒体前拒绝并尝试回滚新建房间。
- 自定义创建服务可实现可选的 `MediaMeetingRoomProvisioner`；现有 `MediaRoomProvisioner` 无需修改，显式模式请求不会被旧实现静默忽略。
- Demo 默认普通会议，使用 SDK 的 `RealtimeMeetingModeSelector`，现有房间自动跟随其模式。

## 教学与共享内容分离

- `ClassroomPreset` 在普通会议中不会分配教学仓库或会话，普通成员没有学生开麦限制。
- `SharedContentPreset` 支持独立的 `SharedContentRepository`，通过 `SharedContentSession` 管理状态、批注、错误、并发读取与释放，不要求注册课堂插件。
- 默认 `ClassroomSharedContentRepository` 适配器复用现有可信控制面；普通会议只创建共享内容会话。已有课堂会话可以被借用，适配器不会释放借用对象。
- 未提供共享内容扩展的旧后端继续使用屏幕共享；SDK 不展示不可用的白板控件。共享内容展示不由 `showClassroom` 决定。
- 普通会议主持人管理白板，成员查看；具备媒体能力的成员可以发起屏幕共享。当前分享者可管理自己的屏幕批注，其他成员和主持人均不能代为修改其批注。
- 内容切换使用内容 revision 做冲突检查，完整快照另以 snapshot revision 排序，避免较慢的旧读取覆盖刚完成的绘图操作。

## 反馈覆盖表

`RealtimeMeetingPage`、`RealtimeLivePage` 默认接入 `RealtimeRoomEventOverlay`。组合页面可将同一组件放入自己的舞台 Stack；`RealtimeClassroomEventOverlay` 保留兼容入口。提示默认 5 秒、最多同时 3 条，同文案在显示期间合并，首次挂载不重播历史瞬时事件。

| 交互 | 发起方反馈 | 接收方反馈 | 可信来源 | 自动验证 |
| --- | --- | --- | --- | --- |
| 举手、取消 | 本人状态与气泡 | 老师具名气泡、持续申请数量 | 已认证课堂快照差异 | `classroom_workspace_test`、`classroom_event_overlay_test` |
| 授予、收回发言 | 权限状态与结果气泡 | 对应学生开麦提示；不会自动开麦 | 课堂快照及厂商权限调用结果 | `classroom_workspace_test`、`provider-routing.test` |
| 提问、回答、解决 | 本人提交结果 | 老师或对应学生气泡、待处理数量 | 课堂快照差异 | `classroom_event_test`、`room_classroom_interactions_test` |
| 公告、作业、资料 | 发布结果及列表状态 | 房间内气泡 | 带条目 ID 的课堂通知 | `classroom_event_overlay_test`、`classroom_tools_test` |
| 互动发布、回答、结束 | 提交结果与状态 | 教师统计更新、学生状态及气泡 | 课堂快照差异 | `classroom_event_overlay_test`、`classroom_tools.test` |
| 计时开始、停止 | 状态及气泡 | 共享倒计时与气泡 | 服务端 endsAt、课堂快照 | `classroom_event_overlay_test` |
| 白板、屏幕共享切换 | 共享状态及气泡 | 舞台切换、气泡 | 共享内容权威状态；无共享扩展时使用媒体 Track 事件 | `meeting_sharing_test`、`shared_content_controller_test` |
| 绘图、翻页、撤销、清空 | 画布变化、失败回调 | 同步画布变化；不对每笔绘图弹气泡 | 白板/批注权威状态 | `whiteboard-state.test`、`whiteboard_test` |
| 录制开始、停止 | 录制状态与气泡、结果入口 | 接入方实际收到录制状态时显示 | SDK RecordingStatus；不编造远端状态 | `recording_controller_test`、`room_components_test` |
| 成员管理、批量静音 | 成功确认；部分失败提示与重试入口 | 已有媒体状态或终止状态 | 可信管理调用结果、厂商媒体事件 | `room_ownership_test`、`room_member_directory_test` |
| 礼物 | 发送中、结果、失败重试 | 具名礼物横幅 | 可信礼物事件 | `live_interactions_test`、`live_gift_panel_test` |
| 点赞 | 计数、处理中、失败回调 | 计数和飘心 | 可信点赞事件 | `live_interactions_test`、`secondary_pages_test` |
| 聊天、表情、课堂反馈 | 消息/表情状态、失败反馈 | 消息、未读标记、自定义表情展示或课堂反馈气泡 | 聊天事件、瞬时表情、课堂快照；瞬时表情不能授权 | chat UI、`demo_custom_interaction_test`、课堂反馈测试 |
| 麦克风、摄像头、设备切换 | 按钮状态与处理中；失败走错误回调 | 对应媒体状态 | SDK 媒体状态 | `room_ownership_test`、媒体控件测试 |
| 断线、恢复、会话结束 | 持续状态与恢复气泡 | 各端依据自身会话状态展示 | SDK 会话生命周期 | `room_event_overlay_test` |

老师的入口为“举手申请”，使用队列图标和数量角标；学生入口为“举手 / 取消举手”。服务端同时拒绝教师执行学生专属命令。

同一错误对象不会重复向宿主报告。SDK UI 的错误文案通过统一错误呈现处理；礼物面板等具有重试上下文的组件保留就地错误状态。普通开关操作以状态反馈，避免气泡刷屏。

## 验收边界

2026-10-20 本地验证：SDK 44 个包已执行离线依赖解析、静态检查和各自的测试；全量检查发现的新增 lint 已修复并在受影响包复验。架构、格式、能力矩阵检查通过；参考后端类型检查及 122 项测试通过；Demo 静态检查及 30 项测试通过。

自动测试包含共享后端状态的老师/学生双 SDK 客户端，以及隔离 HTTP 服务的模式、凭证和权限测试；它们不等于真实厂商或物理设备双端验收。

仍需在更新后的参考后端上运行真实双端会议与直播：验证提示到达、真实麦克风权限、共享画面与批注、礼物及断线恢复。只靠状态变化无法确定操作发起者时使用中性文案；厂商未提供可靠结束原因时，不将普通断线描述为被老师移出。

本次不部署后端、不重启现有服务，不创建云资源。
