# Flutter Realtime UI：标准页面、组件与验收

> 2026-10-15：只维护当前 UI。旧完整页面、兼容模板、旧配置名和 Demo 转发别名已删除，不保留 Deprecated 入口。历史质量基线见 `P1_CLEAN_CODE_BASELINE.md`，其中旧类型名不能用于当前接入。

## 1. 完整页面

| 场景 | 公开入口 |
| --- | --- |
| 自动选择会议 / 直播 | `RealtimeRoomView(room: room)` |
| 会议 / 直播页面单独使用 | `RealtimeMeetingPage` / `RealtimeLivePage` |
| 独立产品聊天 | `RealtimeChatPage(chatRoom: chatRoom)` |
| 入会准备 | `RealtimePreJoinPage` |
| 房间页面配置 | `RealtimeRoomViewConfig` |
| 异步预加入回调 | `RealtimePreJoinEnter` |

```dart
RealtimeRoomView(
  room: room,
  config: RealtimeRoomViewConfig(initialMediaSettings: settings),
  onLeave: () => Navigator.of(context).pop(),
);
```

后端权威 `roomMode` 选择会议或直播，配置的模式仅作无元数据时的提示。
RTC 角色不能代替逻辑房主、教师或主播权限。默认麦克风和摄像头关闭；
预加入设备与媒体选择在准备完成、权限允许后应用。

Demo 的 Chat / Pre-Join 路由直接调用 SDK 页面；Meeting / Live 适配层只注入
本地背景图片及自定义挥手事件。断点、侧栏、手机弹层、浮动工具栏、聚焦/网格、
清屏、虚拟背景和录制交互均在 SDK 中维护。

## 2. 可组合组件与依赖边界

```text
Domain Core / Foundation
  ├─ Runtime                  会话、成员、功能插件、生命周期，无 UI/厂商依赖
  ├─ chat_ui                  独立聊天组件，不依赖 Media UI / RTC
  ├─ design_ui                设计系统
  └─ media_ui                 Media Core + design_ui + Flutter 组件
       ↑
room_ui                       房间作用域、媒体组件与控制器
       ↑
sdk_ui                        标准页面与可选 Classroom / Live / 共享内容组合
       ↑
App / Demo                    连接、路由、内容注入；也可自由组合组件
```

独立 UI 组件继续公开。完整页面和自定义布局共享相同会话与权威状态，
不需要复制业务操作或引入供应商实现。

- `RealtimeRoomUiScope` 清理它创建的 UI Controller，传入自建 controller 则由调用方释放。
- Room/Chat UI 卸载不关闭连接；显式离开操作先离开/关闭房间再回调导航，连接所有者最终调用 `connection.dispose()`。
- 完整预加入页面拥有并释放 `RealtimePreJoinController`；自行组合时由宿主初始化和关闭它。预览在入会前释放，失败后可保留选择并重试，过期操作不能触发晚到导航。
- Classroom/Live 是显式注册的可选插件，权限与快照以可信后端为准，瞬时消息不能授权。
- RTC Data 调试不等于产品 Chat；成员目录按 Runtime 的逻辑身份合并，媒体/Chat 管理能力分别判断。

## 3. 扩展与录制

通过 `header`、`participantBuilder`、`loadImagePresets`、
`onCustomReaction`、`stageOverlayBuilder` 以及功能可见性参数调整标准页面。
原子组件可以放入宿主的 `Row`、`Column`、`Stack`、抽屉或弹窗。

录制是否可用由注入的执行器决定，布局由后端报告，不维护厂商名字名单。
会议和直播共用启动/停止/结果流程。结果对话框展示中英文权威任务状态，
卸载或切换房间后失效旧查询，完成后才提供下载。
背景处理需要显式注册特效服务；不支持时展示原因，不能静默发布未经保护的帧。

## 4. 本地验证与验收边界

```sh
python3 scripts/check_sdk_quality.py --resolve --analyze --test
python3 scripts/check_sdk_architecture.py
python3 scripts/format_sdk.py --check
python3 scripts/generate_capability_matrix.py --check
```

重点回归：单一标准页面入口、角色权限、重复操作保护、预览幂等释放、
失败重试、设备/媒体/背景选择、房间切换、订阅释放和手机/桌面布局。
移除旧模板时，其实现专属测试随之移除；仍适用的生命周期和交互行为迁移至
新页面、公共组件及控制器测试。

本次全量验证：44 个 SDK 包离线 resolve/analyze/test 门禁通过，Failures 为空；
架构检查和能力声明检查通过。定向测试包括 SDK UI 65 项、Media UI 17 项、Chat UI 7 项、Room UI 2 项
及 Demo 29 项测试通过；Demo 静态检查和单包组装 8 项回归通过。生成候选的
`tool/single_import_smoke.dart` 已验证新版配置、预加入回调、预加入页和聊天页
可从单一 SDK 入口导入。格式检查覆盖 737 个 Dart 文件，0 待格式化。

本地 Widget 测试与模拟会话预览不代表真实厂商、真机、远端处理后像素、
发布构建、Windows runner 或云资源清理验收。本次清理未运行这些独立验收。
