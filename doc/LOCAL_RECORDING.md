# 真实本地录制 / Local Recording

## 当前状态（阶段性实现）

本地录制不再创建以文本填充的“MP4”。`RealtimeRoom.startRecording()` 在媒体会话提供 `MediaLocalRecordingSession` 或应用显式注入 `localRecordingDriverFactory` 时启动真实编码；否则返回 `RealtimeErrorCode.unsupportedFeature`。原生录制组件是可选插件，绝不作为 Runtime 的隐式依赖。

| 平台 | 本地录制 | 说明 |
| --- | --- | --- |
| Web | 已实现浏览器编码器和下载调用链，待真实浏览器 E2E | `getDisplayMedia` 请求用户选择屏幕、窗口或标签页，`MediaRecorder` 编码 Blob，录完点击下载 |
| macOS 13+ | 已实现原生 ScreenCaptureKit + AVAssetWriter，Debug 构建通过，待屏幕授权/回放 E2E | 录制所选显示器的画面及系统允许的播放音频，保存 MP4 在 app Documents/RealtimeRecordings |
| Android 7+ | 已实现 MediaProjection + MediaRecorder、前台服务，Debug APK 构建通过，待授权/回放 E2E | 明确请求系统录屏授权，暂时只录制视频，不采集 RTC 远端/麦克风混音 |
| iOS / Windows | 暂不支持 | 后续阶段评估各自平台的采集/编码接口 |

此阶段的 Web 录制**不是** Provider 原始轨道混流。它录制用户在浏览器共享选择器里明确选择的内容。若要录入会议画面，应选择显示会议画面的标签页/窗口；浏览器是否提供共享音频受浏览器、操作系统及具体共享目标限制。特别是多方混音、麦克风独立音轨、主动发言人布局并未保证覆盖。

## 无 UI 的 SDK 用法

在 Android/macOS 上，业务项目需要显式依赖并注册可选插件 `flutter_realtime_recorder_native`：

```dart
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_realtime_recorder_native/flutter_realtime_recorder_native.dart';

final realtime = Realtime(
  providers: myProviders,
  localRecordingDriverFactory: nativeRecordingDriverFor,
);
```

没有注册此插件的原生应用将继续报告不支持，本插件无需供应商 token 或业务服务端协助。Android 工程必须合并插件的 `FOREGROUND_SERVICE_MEDIA_PROJECTION` 声明；首次录制通过系统 MediaProjection 授权弹窗。Android 文件先存放在应用私有 `filesDir/realtime_recordings` 中，需主动调用导出接口才会复制到用户选择的文档位置。macOS 13+ 需要 Screen Recording 授权，捕获的是显示器内容而非特定参会者的独立音轨。

```dart
if (room.capabilities.media.canRecordLocal) {
  await room.startRecording(RecordingOptions.local());
  // 录制中 UI 可订阅 room.recordingStatuses / room.recordingDurations
  final result = await room.stopRecording();
  if (result?.downloadId != null) {
    // Web: 同步从用户点击事件中调用，不能先 await 其他操作。
    room.downloadRecording(result!);
  } else if (result?.localFilePath != null) {
    // Android/macOS: 在录制结果页由用户触发另存为
    final savedTo = await room.exportRecording(result!);
    // Android 为用户选定的 content:// URI；macOS 返回保存路径。
  }
}
```

### Native 录制文件导出

- Android：`room.exportRecording(result)` 启动系统 `ACTION_CREATE_DOCUMENT` 保存选择器，确认后将 MP4 从应用沙盒复制到用户选择的目录，返回 `content://` URI；不请求宽泛的文件读取权限，也不自动上传或公开私有文件。
- macOS：同一 API 打开 `NSSavePanel` 选择保存位置，复制完成后返回导出文件路径；宿主沙盒应用需要 `com.apple.security.files.user-selected.read-write` entitlement（Demo 已配置）。
- 源文件继续保留在沙盒。取消选择器或导出失败会抛异常，Demo 显示失败原因；不能将取消当作成功。
- 仅允许 SDK 录制目录下存在且非空的 MP4 作为导出源，防止任意用户路径被插件读取。
- 当前接口负责**保存副本**，不是系统分享面板、相册上传、文件列表管理或云存储。真实设备上仍需测试用户授权、选择、取消、覆盖已有文件与大文件复制。

### 系统录屏中断

`flutter_realtime_recorder_native` 为 Android 的 MediaProjection 授权撤销、macOS 的 ScreenCaptureKit 异常停止提供独立事件流；SDK 的 `RoomRecordingController` 收到后将录制状态设为 `failed`、终止计时、触发 `RealtimeBackendFailure`，避免 UI 仍显示虚假的 `REC`。仅在系统确实提供进程内回调时生效；进程被强杀等无法收到回调的情况不能保证恢复。用户主动点击“停止录制”不会被报告为异常中断。

中断后的临时文件不应视为完整媒体文件，也不应该展示成功下载/导出入口；原生平台只允许经过结束录制及轨道校验的结果进入导出流程。录制中的 RTC 路由、音轨、显示屏切换仍需真机 E2E 验收。

当用户在录屏系统授权弹窗尚未处理完成时离开会议，SDK 会等待授权请求结束；若平台已启动采集，则立即请求停止/完成清理，不继续进入常规 `recording` 状态。若 `stopRecording` 正在封装 MP4，房间销毁会等待其完成再释放媒体资源。上述 start/dispose 与 stop/dispose 竞态已覆盖 Runtime 自动化测试，仍需真实设备的权限弹窗与退出路径验收。

Web 默认请求视频和共享音频。如果浏览器没有提供音频轨，录制结果的 `metadata['hasAudio']` 为 `false`，Demo 会提示文件只有画面。录制容器由浏览器 `MediaRecorder.isTypeSupported` 决定；即使首选 MP4，也可能下载 WebM；`RecordingResult.mimeType`、`fileName` 描述实际格式。

下载句柄只保存在当前浏览器会话内存中。重新开始录制或离开/销毁房间会释放旧资源，**下载请在离开房间前进行**。SDK 不会将录制发送给业务后端，也不会在浏览器或设备之外存储录制内容。

## 云端录制

`room.describeCloudRecording()` 仅用于生成不执行的云端请求描述；**LiveKit** 已另行接入真实后端执行器：`room.startRecording(RecordingOptions.cloud())` 调用 Demo Server 的云端录制接口，真实返回 Egress ID。停止后可查询完成状态；若部署了自托管 Egress 并启用共享目录，可由 Demo 使用一次性下载 URL 导出 MP4，**不需要 S3**。其他供应商仍只有 API 描述而没有实际执行器。详见 [云端录制 V1](CLOUD_RECORDING.md)。

## 后续验收

- 平台录制能力矩阵必须按浏览器/Provider/平台真实能力填充。
- Android / macOS 已接入原生录屏 Driver 但尚缺真机回放；仍需要可选的 Provider 原轨道采集、会议多路音视频混流。
- Android 的音频支持为否（`hasAudio=false`），macOS 实际录得音频样本才返回 true。不得将此路径称为完整会议录制。
- iOS / Windows 仍需要各自的录制 Driver 与真机验证。
- Web 需要至少一次真实浏览器的双人会议/屏幕分享、视频回放、音频可用性测试。
- Android 停止后用 `MediaMetadataRetriever` 检查视频轨、尺寸、时长；macOS 检查 `AVAssetWriter` 完成状态、视频轨与文件大小。仍必须通过真实播放器确认音画和持续录制行为。

### 文件与真实设备验收命令

导出实际 MP4/WebM 文件后，在安装 FFmpeg/ffprobe 的开发机运行：

```sh
python3 scripts/verify_recording.py ./recording.mp4 --min-seconds 3
python3 scripts/verify_recording.py ./meeting-with-audio.mp4 --require-audio --min-seconds 3
```

脚本使用 ffprobe 检查真实容器中的视频轨、宽高、编码、文件大小和录制时长，`--require-audio` 会额外要求存在音频轨。没有安装 ffprobe 时返回明确错误；文本伪 MP4、空文件、没有视频轨的文件均不能验收通过。音频轨存在也不能证明声音可听，仍需使用真实播放器确认会议画面与声音。脚本自身单测：`python3 -m unittest discover -s scripts -p test_verify_recording.py`。
