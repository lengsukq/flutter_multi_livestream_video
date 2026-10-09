# 跨应用屏幕标注 SDK

## 包与入口

`flutter_realtime_screen_annotation` 是独立 Flutter 插件，依赖 Flutter 和
Whiteboard Core，不依赖 Demo 或具体媒体供应商。`flutter_realtime_sdk_runtime`
负责与课堂共享内容生命周期衔接，完整 `flutter_realtime_sdk` 导出同一组公开接口。

功能：可移动工具条、操作/绘制切换、画笔、高亮、圆圈、箭头、文字、撤销、清除。
课堂内白板和屏幕标注统一使用 Whiteboard UI 的公开组件 `AnnotationToolbar` 与 `MovableAnnotationToolbar`。
跨应用标注悬浮工具栏通过辅助 Flutter 引擎加载相同的统一工具栏 Widget，具备 Material 3 圆角深色卡片、矢量图标、选中高亮与一键折叠能力；底层全屏透明原生画布负责高性能笔迹捕获与点击穿透。笔迹走已有 AnnotationController
与课堂权限/同步协议；原生插件不持有用户凭证，也不通过视频帧通道发送笔迹。

## 平台与适用范围

| 平台 | 实现 | 限制与验证状态 |
| --- | --- | --- |
| Android | WindowManager 悬浮 FlutterView（次级 FlutterEngine）/ 备用卡片、透明画布、文字输入窗口 | 需要用户允许“显示在其他应用上层”；debug 整包构建通过，跨应用/远端实机待验收 |
| macOS | AppKit 浮动透明 NSPanel（次级 FlutterEngine 嵌入 FlutterViewController）/ 备用 HUD 面板、绘图 NSView、跨 Spaces 窗口 | 新插件原生构建通过；完整 Demo 仍遇到现有供应商模块/重复打包冲突，跨应用/远端待验收 |
| Windows | Win32 置顶分层窗口、GDI+ 画布、原生文字输入 | 已实现适配源码；缺少 Windows 构建与运行环境，尚未验证 |
| Linux X11 | GTK/Cairo 透明画布、置顶工具窗、点击穿透 | 要求合成器和 RGBA visual；已实现源码，缺少 Linux 构建/运行验证；置顶效果仍受窗口管理器控制 |
| Linux Wayland | SDK 返回不支持跨应用悬浮 | 保留课堂内标注 |
| iOS / Web | SDK 返回不支持跨应用悬浮 | 保留课堂内标注，不显示成已具备系统悬浮能力 |

共享供应商还必须在当前系统支持屏幕共享。SDK 不把“存在标注插件”当作媒体
供应商已经实现屏幕共享：课堂入口同时检查教师权限、共享状态和平台能力。
因此可用于 LiveKit、TRTC 等已接通屏幕共享的组合；供应商未接通的组合仍不可用。

默认目标是**主显示器整屏**。工具条可拖动，使用“操作 / Move”可继续操作下方应用。
SDK 不自动定位被共享的窗口，不覆盖系统安全界面，不保证所有应用允许悬浮窗。
显示器几何、缩放或安卓方向改变时关闭工具，并清除旧坐标的笔迹；用户在当前共享
画面上重新打开。此版本不自动跟随移动的被共享窗口，也不支持选择第二显示器。

## 课堂 SDK 用法

```dart
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';

final content = room.sharedContent!;
await content.selectMode(SharedContentMode.screen);
// 使用完整主屏幕共享，再打开悬浮工具。
await content.startSystemAnnotations(languageCode: 'zh');
await content.stopSystemAnnotations();
```

`RealtimeRoomView` 的“课堂内容”菜单提供“跨应用标注”。Android 首次使用会进入系统
悬浮窗设置，返回后继续打开工具；拒绝后保留错误，允许授权后重试。
用户点击跨应用标注时，SDK 先请求权限，再提交后端呈现状态；已经授权不会再次跳转。
普通启动 App、入会或打开课堂内白板不请求悬浮权限。独立宿主也可调用
`tools.requestPermission()` 在用户点击工具时提前请求权限。
LiveKit Android 请求整屏捕获，避免单应用捕获排除悬浮画布。

切回成员/白板、停止共享、权限丢失、画布改变或房间销毁时会关闭窗口，解除
手势拦截，并取消/排空对应的同步工作。正在等待悬浮授权时退出房间也会取消 SDK
等待；系统设置页面由用户自行返回，不被 SDK 强行关闭。

## 独立使用

```dart
import 'package:flutter_realtime_screen_annotation/flutter_realtime_screen_annotation.dart';

final tools = SystemScreenAnnotationController(annotations: myAnnotationController);
final availability = await SystemScreenAnnotationController.capabilities();
if (availability.supported) {
  await tools.start(languageCode: 'zh');
}
// tools.active、tools.error、tools.changes 可驱动自定义 UI。
await tools.dispose();
```

宿主负责真实屏幕捕获、编辑授权、后端同步和播放端呈现。一个 Dart isolate 中同时
只有一间房间可持有系统工具；SDK 在异步能力查询后再次检查所有权。

高级宿主可传入 `SystemAnnotationViewport`，指定主屏幕内的固定归一化矩形。
共享单窗口且捕获不包含系统画布时，宿主必须跟踪窗口位置并指定正确矩形，且调用：

```dart
await content.startSystemAnnotations(
  viewport: const SystemAnnotationViewport(x: .1, y: .1, width: .7, height: .7),
  embeddedInVideo: false,
);
```

此矩形例子不是自动窗口追踪。宿主变更共享目标必须停止并重新绑定画布。

## 视频与笔迹的呈现

整屏共享会捕获本地系统画布。参考后端新增教师动作
`tool.annotation.presentation`，载荷为 `canvasId` 和 `embeddedInVideo`。
后端验证教师权限、活动共享源、当前画布及布尔值，并在权威快照中返回标记。

开启工具前 SDK 提交 `embeddedInVideo: true` 并确认后端已接受，接收端据此隐藏
重复的矢量绘制层。关闭工具后恢复为 `false`，恢复课堂内标注显示。
共享窗口不包含悬浮画布时可显式使用 `false`，由播放端绘制同步矢量笔迹。
接收端也需更新 SDK；旧客户端不会识别新呈现标记。

这需要部署更新后的参考后端，或在自有后端实现对应协议。未实现的后端会报错，
SDK 不会假装悬浮标注已成功。恢复呈现状态失败时通过内容状态错误保留诊断。
权限获取成功后若仍提示后端不支持，请更新正在运行的参考后端；不能靠客户端热重载
添加 Android 原生插件和清单权限，需要完整重建并安装应用。

自由笔迹约每 100 ms 发送进度，Dart 合并同一笔迹的待处理版本，单批不超过 100
点、单笔不超过 2048 点。后端完成后才确认本地草稿。撤销/清除与笔迹使用同一
顺序队列。同步失败后停止接受新绘制并显示错误，关闭后重开可依据权威快照恢复。

## 宿主配置与验证记录

- Android 插件合并 `SYSTEM_ALERT_WINDOW` 声明；用户授权仍必须在系统设置中完成。
  原屏幕共享仍需供应商的 MediaProjection 前台服务和用户捕获授权。
- macOS CocoaPods 插件依赖 `FlutterMacOS`/AppKit，不要求辅助功能权限。
  屏幕录制权限仍由媒体供应商申请。
- Windows 插件链接系统 GDI+，宿主应使用 Flutter 桌面模板的 DPI 配置。
- Linux 插件使用 Flutter 桌面的 GTK 依赖；运行时检查 X11/合成器/RGBA visual。

2026-10-08 的本地记录：Android debug 整包、标准 Web release 构建通过；七个受影响
Dart/Flutter 包静态分析无问题；参考后端类型检查通过；macOS 新插件独立原生构建通过。
完整 macOS Demo 两次尝试分别受已有重复框架打包和供应商模块依赖阻塞；临时构建
设置已恢复，未永久修改宿主工程。此轮未新增或运行测试套件。

**待真实验收**：Android 权限拒绝/重试、跨应用绘制、点击穿透、停止共享/退出后的
窗口清理、屏幕旋转；macOS 跨 Spaces；Windows/Linux 本机编译与运行；全平台远端
笔迹像素与坐标；供应商捕获是否实际包含悬浮窗口。构建和源码适配不证明这些已通过。

参考：[Android 悬浮窗口](https://developer.android.com/reference/android/view/WindowManager.LayoutParams#TYPE_APPLICATION_OVERLAY)、
[macOS 跨 Spaces 窗口](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/canjoinallspaces)、
[GTK 置顶限制](https://docs.gtk.org/gtk3/method.Window.set_keep_above.html)。
