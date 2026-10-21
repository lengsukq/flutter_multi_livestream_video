# Web 摄像头与虚拟背景修复（2026-10-19）

第三方报告：`flutter_realtime_sdk 0.1.0-dev.7`，Headless 页面使用公开的
`DefaultRealtimeVideoEffects`、`room.setCameraEnabled` 和 `room.setBackgroundEffect`。
修复位于 SDK 包及打包源，不要求第三方复制 Demo 的逻辑。

## 已确认的缺陷与修改

1. **Web 视频容器绑定过早**：Flutter 的 `onElementCreated` 在元素插入 DOM 前调用。
   原实现立刻 `getElementById`，查不到时直接返回，造成发布成功但本地画面仍黑。
   现在直接传元素对象给桥与 Agora 的 `play`；更换轨道时保留并重绑已有元素。
   移除了挂载错误的空 catch，异步异常保留 typed failure 与诊断 cause。
2. **Agora 普通摄像头误经处理管线**：没有背景效果时仍使用自定义轨或预览采集；
   关闭原始预览后，旧自定义轨可能仍引用已结束的摄像头。
   现在无效果走 Agora 原生摄像头；关镜头释放、重开重新创建；发布失败释放摄像头并允许重试。
   启用/恢复外部处理轨时同步启用厂商自己的克隆。
3. **LiveKit Web 调用了不存在的原生通道**：`ProcessedVideoBridge` 只有原生
   MethodChannel 实现，Web 未注册该插件，却在启用处理轨时必经此处。
   现在按平台条件导出实现，Web 直接等待浏览器源注册表的异步操作。
4. **LiveKit 摄像头交接与克隆状态**：旧摄像头仅静音仍保留 publication；处理源
   以禁用状态附着时，其克隆也保持禁用。现在移除旧 publication，再发布已启用的
   处理克隆；反复关开镜头复用同一 publication，并细分失败阶段。
5. **首帧及运行中错误**：Web 源等待有效的视频尺寸，并成功渲染首帧后才交付；
   切换效果/开镜时的首帧处理异常会拒绝对应 Future。运行故障保留在源中，
   再次开镜继续抛错，直到显式重设效果成功；房间停止故障发布，并保留事件与诊断。

没有把原始厂商异常直接拼入公开 message/toString。业务使用错误 code、domain、
operation、suggestedAction；私有诊断日志保留 cause、details、stackTrace。
运行后发生的错误通过 `RealtimeBackendFailure` 通知，最近错误可从 `room.diagnostics` 读取。

报告中的“GPU 图资源竞争”“drawImage 静默失败”“attach 已经重复发布”是排查假设，
不能当作已证实根因。此次未改 CPU delegate，也未在处理失败时自动退回未经保护的摄像头。

## 验证

- 全部 44 个包：离线依赖解析、analyze、可运行的默认平台测试通过。
- 最后新增的 Web 渲染修改另行完成包内 analyze/test 及浏览器验证。
- Web 桥：视频尺寸未就绪、首帧推理失败、运行故障、显式重置、帧率与脸部边缘回归。
- 浏览器 Dart 测试：处理源不依赖原生插件；LiveKit 旧摄像头移除、克隆启用、
  单次发布、反复开关和释放；Flutter DOM 挂载前绑定与轨道更换。
- 在生成的单包候选中重复上述浏览器回归。
- 复制第三方现有 lib/web/assets 到隔离宿主，仅替换 SDK 依赖后 Web 构建通过；
  原第三方项目未修改。产物资源清单、模型与 WASM 共 8 项校验通过。
- 实际 GPU 像素检查使用本地合成视频：模糊 82.9、关开镜头 84.4、
  图片替换 137.3、恢复无背景 89.7（640×360，平均 RGB 亮度，非黑帧）。
- 架构、格式与能力声明检查通过。

以上不等于真实 Agora/LiveKit 双端通话或真实摄像头验收；此次未连接云端厂商房间。
合成视频验证的是处理管线及输出像素，不验证真实人像分割质量。

## 第三方接入

本记录完成后，此修复随 `flutter_realtime_sdk 0.1.0-dev.8` 发布；后续的 dev.9
已于 2026-10-19 发布并取代该版本。继续依赖 dev.7 不会获得本记录中的修复。

临时本地验证可在第三方项目使用如下 `pubspec_overrides.yaml`，然后执行
`flutter pub get --offline` 并完整重新启动 Web 应用（热重载不替换已加载的 JS）：

```yaml
dependency_overrides:
  flutter_realtime_sdk:
    path: /Users/leo/Documents/code/multi-video/build/pub_release/0.1.0-dev.8/flutter_realtime_sdk
```

正式接入请使用当前已发布的 `flutter_realtime_sdk: ^0.1.0-dev.9`；不应修改系统 pub-cache 中的旧版本。
