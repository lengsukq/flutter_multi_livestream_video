# 屏幕共享：供应商 × 平台实现/验证矩阵

> 审查基于统一媒体 SDK 的真实 adapter/source/controller，而不是厂商官网支持矩阵。**源码接入 / SDK 能力声明 / 真实多人远端画面验收是三种不同状态。** 不要仅通过客户端按钮是否显示来判断成功。

## 标准契约

`InteractiveMediaSession.setScreenShareEnabled(true/false)` 是供应商无关的共享入口。`snapshot.localScreenShareEnabled` 必须只在真正的本地采集/发布成功时为 true；`snapshot.contentShareTrack` 是共享画面轨道，`MediaTrackPublished/MediaTrackUnpublished` 通知 UI；远端应按共享源原始纵横比 `BoxFit.contain` 展示，而不是裁剪。用户主动停止、屏幕源意外终止、权限被拒绝、离会/销毁都必须清理采集资源与状态。

**凡仅能接入摄像头，但无法远端正确呈现共享画面的组合，均不应称为已完成全链路。**

## 当前代码状态

以下表格中的“基础”表示采集与控制代码存在，未实机验收；“初步”表示本轮已接入部分代码，仍缺完整远端/权限验收；“未接”表示 SDK 未接通，不代表厂商官方不支持；“条件”表示取决于浏览器/系统。

| RTC 媒体适配器 | Web 桌面浏览器 | Android | iOS | macOS | Windows |
|---|---|---|---|---|---|
| LiveKit | 基础，浏览器授权 | 基础，MediaProjection | 条件，当前以应用内采集为主，缺 Broadcast Extension 全屏 | 基础，系统屏幕录制权限 | 基础，待 Windows 构建/实机 |
| Agora | 初步，屏幕选择/取消/恢复摄像头已修复；远端共享识别需完善 | **初步，本轮实现官方 MediaProjection Capture + 共享发布与状态**，远端共享轨道识别待补 | 未接 ReplayKit Broadcast Extension | 未接屏幕/窗口源选择 | 未接屏幕/窗口源选择 |
| 腾讯 TRTC | 初步，JS 辅路采集与播放 | 基础，原生辅路 | 条件，原生 ScreenCapture/ReplayKit 扩展配置需验收 | **初步，本轮实现主显示器自动枚举/选定 + 辅路采集** | **初步，本轮实现主显示器自动枚举/选定 + 辅路采集**，缺 Windows 构建 |
| 阿里 ARTC | 初步，本轮补远端摄像头/屏幕 bitmask 分流和幂等清理 | 未接原生桥 | 未接原生桥 | 未接原生桥；官方 macOS framework 前置条件 | 无默认原生 Driver |
| AWS Chime | 基础，桌面浏览器 Content Share | 未接原生 Content Share 桥 | 未接原生 Content Share/ReplayKit 桥 | 未接 SDK 桌面共享桥 | 无默认 Chime Driver |
| AWS IVS Real-Time | 初步，屏幕采集/发布与资源清理测试已补，远端区分仍待验收 | 未接原生 Broadcast 屏幕源 | 未接原生 Broadcast/ReplayKit 屏幕源 | 未接桌面共享桥 | 无默认 IVS Driver |

Web 浏览器是否支持 `navigator.mediaDevices.getDisplayMedia` 需运行时检测。桌面 Chrome、Edge、Safari 的实现与权限不同，**移动浏览器不能因为同属 Flutter Web 就宣称能共享系统屏幕**。

## 已完成的 SDK 修复

- **统一 Web 状态**：`provider_web_session_factory.dart` 根据本地共享轨道同步 `localScreenShareEnabled`，避免实际共享成功但 UI 永远显示未开启。
- **Agora Web**：先等待用户选择屏幕再停止原来的摄像头发布；取消选择不影响摄像头。发布失败释放屏幕并恢复摄像头，停止共享后恢复摄像头。
- **TRTC/ARTC Web**：幂等开启、停止和轨道释放；ARTC 根据远端视频 bitmask 区分摄像头和屏幕；发布失败清理。
- **IVS Web**：采集失败释放本地屏幕轨道，避免重复开启；观众角色禁止发起屏幕共享。
- **Agora Android**：`startScreenCapture/stopScreenCapture`、`ChannelMediaOptions.publishScreenCaptureVideo`、本地屏幕轨道与退出清理；原生视频失败回调同步清除活动状态。
- **TRTC macOS/Windows**：使用 `getScreenCaptureSources` 选择主显示器并 `selectScreenCaptureTarget`，再沿用已存在的辅路编码/远端订阅。

## 仍未完成的关键闭环

1. **Agora Web/Native 远端共享标识和独立显示**：屏幕与摄像头视频只有一个或多个 RTC UID/轨道时，必须用服务端分配的可信标识或视频源元数据建立“这是共享源”的映射。不能单凭画面比例猜测。原生 Android 的基本采集发布不意味着异端已能显示到共享舞台。
2. **ARTC/Chime/IVS 原生平台适配**：需接入厂商原生 SDK 的屏幕采集、Publisher、远端 Track、选屏/授权、共享中断回调。尤其 Chime Android/iOS 官方 SDK **有** Content Share 能力，但当前 Flutter 适配尚未实现。
3. **iOS 跨 App 全屏共享**：ReplayKit Broadcast Upload Extension 和 App Group、原生 SDK 的广播上传桥须由示例 Host App 正确安装并签名；Flutter 单一入口无法省掉扩展。当前 LiveKit iOS 仅应用内捕获，不是整机屏幕。
4. **原生桌面多显示器与窗口共享**：TRTC 当前仅选主显示器，未做 UI 源选择。Agora macOS/Windows、AWS 桌面仍未接通源选择与 SDK Track。
5. **运行时权限和系统停止事件**：Android 前台 MediaProjection 服务，macOS 屏幕录制权限，iOS 广播停止、浏览器 `track.ended`、销毁和重连；真实场景均需端到端确认。
6. **多供应商/多平台验收**：每个组合至少用双设备测试本地采集 → 发布 → 远端订阅 → 坐标与画面比例 → 主动停止/权限拒绝/意外停止 → 重连与退出。自动化 Mock 测试不等于真实 SDK 通过。

官方资料：[Agora Flutter Screen Sharing 示例](https://github.com/AgoraIO-Extensions/Agora-Flutter-SDK/blob/main/example/lib/examples/advanced/screen_sharing/screen_sharing.dart)、[腾讯 TRTC 屏幕共享](https://trtc.io/zh/document/39859?platform=flutter)、[AWS Chime 移动屏幕共享](https://aws.amazon.com/about-aws/whats-new/2021/01/amazon-chime-sdk-ios-android-support-screen-share/)。
