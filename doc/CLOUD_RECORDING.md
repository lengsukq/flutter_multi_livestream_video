# 云端录制 V1 · LiveKit Egress

首版优先支持 LiveKit 的真实云端录制。Flutter SDK 在 Web/Android/iOS/macOS/Windows 使用同一 `RealtimeRoom` API 传递录制模式与参数；Demo 提供常用布局、进度与下载。**不使用 S3、不集成任何云端对象存储。** 自部署 LiveKit Egress 将 MP4 写入共享目录，Demo Server 验证文件生成后按需提供受保护的文件下载。Agora、TRTC、AWS、ARTC 等仍只有请求描述，尚未实现真实云录制。

## 需要配置的服务端环境

```dotenv
LIVEKIT_URL=ws://your-self-hosted-livekit:7880
LIVEKIT_API_KEY=livekit-key
LIVEKIT_API_SECRET=livekit-secret

# 自部署 Egress 容器内部录制目录，例如 docker -v /srv/realtime-recordings:/out
LIVEKIT_EGRESS_OUTPUT_DIR=/out
# Demo Server 能访问的同一磁盘目录（可以是宿主机路径，或相同卷在其容器中的挂载路径）
LIVEKIT_RECORDING_EXPORT_DIR=/srv/realtime-recordings
```

**必须自部署 LiveKit Egress**，并将 Egress 容器的 `/out` 挂载到 Demo Server 可读取的同一目录。保证 Egress 非 root 用户有目录写入权限，Demo Server 有读取权限。请参阅 [LiveKit 官方 Egress 仓库 FAQ](https://github.com/livekit/egress#faq) 的本地磁盘输出示例。LiveKit Cloud 托管 Egress **不支持无存储配置的文件输出**，所以单独购买 LiveKit Cloud 服务、但不部署自己的 Egress 不能使用此无 S3 方案。LiveKit 服务端密钥只放在后端，未配置会明确返回 503，不会假装录制成功。

**自部署还包括 LiveKit Server 和 Redis**：Egress Worker 必须与 LiveKit Server 使用同一个 Redis。仅在自己服务器上启动一个 Egress 容器，并不能直接让 LiveKit Cloud 托管项目输出到本地。

## SDK 统一调用

```dart
// 房主已经加入 LiveKit 房间
final started = await room.startRecording(
  RecordingOptions.cloud(layout: RecordingLayout.grid),
);
print(started.recordingId); // LiveKit 返回的真实 Egress ID

// 可选：演讲者模式 + 1080P（服务端白名单校验）
// RecordingOptions.cloud(
//   layout: RecordingLayout.speaker,
//   rawProviderParams: {'preset': 'H264_1080P_30'},
// );

// 停止时文件未必生成完毕
final stopped = await room.stopRecording();
// 应继续查询直到 state == 'completed' 或 'failed'
final progress = await room.queryCloudRecording();
if (progress.metadata['canDownload'] == true) {
  final exportUrl = await room.cloudRecordingDownloadUrl();
  // Demo 点击下载按钮打开 60 秒内有效、仅可使用一次的文件导出 URL。
}
```

SDK/后台公共参数包括 `layout`、`streamType`、`containerFormat`、`rawProviderParams`。V1 支持 `grid`、`speaker`、合成视频+音频、MP4，以及白名单中的 `H264_720P_30` / `H264_1080P_30` 预设。任何存储密钥、服务地址等服务端特权参数均禁止从前端覆盖。

## 后端接口与状态

四个 API 使用 `POST`，都要求当前房间参与者凭证及房主管理权限：

| 路径 | 返回 |
| --- | --- |
| `/rooms/:code/recording/start` | 实际 Egress ID 和开始状态 |
| `/rooms/:code/recording/stop` | 停止请求结果，通常为 `processing` |
| `/rooms/:code/recording/status` | `starting` / `recording` / `processing` / `completed` / `failed` |
| `/rooms/:code/recording/download` | 检查共享目录中 MP4 已完成后，返回服务器相对下载路径（一次性令牌、60 秒有效） |
| `GET /rooms/:code/recording/export/:ticket` | Demo 浏览器下载 MP4；令牌必须有效且匹配录制房间，使用后作废 |

Egress 采用 `StartEgress`（模板布局）+ `StopEgress` / `ListEgress`。结束后，服务端检查自己生成的 UUID 文件名、MP4 容器标记、文件大小稳定性；不会根据用户提供的路径或未完成文件开放下载。浏览器不需要持有房主凭证，只使用授权后产生的一次性下载 URL。SDK 只负责调用公共 API，后端负责 Egress 和文件权限；无需在 SDK 中写死 Demo Server。

## 当前限制

- 云录制**并非停止后立即生成文件**。Demo 会轮询状态并在确认完成后提供“下载 MP4”。
- V1 Demo Server 内存保存正在录制的任务 ID；服务重启可能失去下载入口，已生成的文件仍存在挂载目录。部署者需要清理临时 MP4 文件；生产环境还应加入保留时间和磁盘空间上限。
- Demo SDK 只接受来自已配置 Demo Server **同源**的下载地址；局域网联调可使用 HTTP，正式部署必须使用 HTTPS。下载令牌只可使用一次，60 秒过期。
- 必须部署自有 LiveKit Egress worker、配置共享目录，完成双人会议的真实回放验收；当前已覆盖自动化模拟测试和参数鉴权测试。
- 录制开始已获得 Egress ID 不代表视频帧一定正常。必须检查最终视频布局及远端声音。
- 旧版 Android/macOS 本地录屏仍未通过真实设备验收，云录制设计用于先绕过这些平台差异。

## 测试

```sh
cd demo-server
npm run typecheck
npm test
cd ../packages/flutter_realtime_sdk_runtime
flutter test --no-pub test/http_cloud_recording_session_test.dart
```
