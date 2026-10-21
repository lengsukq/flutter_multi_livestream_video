# Windows 虚拟背景 — 原生对接与上线验收

> 开发状态（2026-10-21）：LiveKit、Agora RTC、Tencent TRTC 的 Windows
> processed-video native adapter 已写入源码，**尚未在 Windows 构建机器上完成
> C++ 链接、ONNX 推理和真实远端验收**。请勿在版本说明中标记为已上线。

## 统一数据流

`MediaFoundation camera BGRA → PPHumanSeg ONNX foreground mask →
native BGRA composite → FrameHub C ABI → vendor sink`

| Publisher | Windows 输入 | Native adapter |
| --- | --- | --- |
| LiveKit | BGRA → I420 → vendored flutter_webrtc `CreateCustomVideoSource` / `OnCapturedFrame` → 本地视频轨道 | `packages/flutter_realtime_media_livekit/windows` |
| Agora RTC | BGRA → `IMediaEngine::pushVideoFrame` 到 `customVideoTrackId` | `packages/flutter_realtime_media_agora/windows` |
| Tencent TRTC | BGRA → BT.601 I420 → `enableCustomVideoCapture` / `sendCustomVideoData` | `packages/flutter_realtime_media_trtc/windows` |

三种协议共享 `flutter_realtime_video_effects` 插件内唯一 FrameHub，通过
`processed_video_frame_api.h` 的 C ABI 订阅/释放。帧数据只在原生层传输，
Flutter MethodChannel 仅传递源身份、效果配置和绑定信息。

## Windows x64 环境准备

1. Windows 10+/11、Visual Studio 2022（含 Desktop C++、MSVC 与 Windows SDK）、
   Flutter 3.47+、CMake、可用摄像头。
2. 安装或解压 **Microsoft 发布的 ONNX Runtime x64 C++ 分发包**，
   设置 `REALTIME_ONNXRUNTIME_ROOT` 指向包含
   `include/onnxruntime_cxx_api.h`、`lib/onnxruntime.lib` 和
   `lib/onnxruntime.dll` 的根目录。分发需同时保留 ONNX Runtime
   的许可声明；不配置时插件编译为安全的 unsupported。
3. `packages/flutter_realtime_video_effects/assets/windows/pphumanseg.onnx`
   必须随 Flutter assets 打包；检查 `PPHUMANSEG_LICENSE.txt`，
   模型 SHA256 见 `windows/MODEL.md`。
4. Windows 宿主应使用仓库自带的 `packages/flutter_webrtc` 版本。
   LiveKit 自定义轨道接口是在该分支扩展的，不能替换成无此接口的上游二进制。

## 自动化与验收

Windows GitHub Actions 工作流：
`.github/workflows/windows-video-effects-smoke.yml`。
包含三个 Provider 原生插件的编译入口；GitHub Actions 未运行前没有
Windows 构建通过的证据。没有 ONNX Runtime 的默认 smoke 构建只验证
链接，不验证真实推理。

每个 Provider 均需逐项记录：

- 2 台真实设备 A（Windows x64）与 B（不同设备）：以 host、participant、
  viewer 身份加入 Meeting / Broadcast。
- Pre-Join 模糊与换图预览正确；房间中切换 None / Blur / ReplaceImage，
  **B 端收到与 A 端一致的处理后视频像素**。
- 断开摄像头、撤销权限、删除/替换 ONNX 模型、切换摄像头：
  报错明确且**不会改发原始背景**。
- 会议中关闭/打开摄像头、退出/重入房间、网络断开重连后，
  处理后的轨道不会重复发布，音频不中断、资源会清理。
- 验证 720p @ 24fps、单次两小时会话的 CPU/内存/设备发热。
  需要在性能不达标的设备上明确降级策略。

各阶段验收要分别记录：Dart 测试、Windows C++ 编译、Windows ONNX 模型
推理、真实 RTC 远端像素。**不能将任一前序测试替代后序验收。**
