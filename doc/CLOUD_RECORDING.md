# 供应商云端录制 · Flutter SDK + Demo

本项目是 **Flutter 前端 SDK**。录制、混流、转码（若厂商提供）由 RTC 供应商的云端服务执行；`demo-server` 只负责调用厂商 REST/OpenAPI、持有服务器凭证、查询任务以及流式转发云存储里的 MP4 文件。**不需要部署 Linux 录制程序、Java Recording SDK、FFmpeg 或我们自己的媒体录制服务。**

## 供应商能力现状

| 媒体供应商 | Demo 录制执行器 | 厂商托管录制 | 存储要求 | MP4 下载 | 实际验收状态 |
|---|---|---|---|---|---|
| Agora | `agora-cloud-recording.ts` | Agora Cloud Recording：Acquire/Start/Query/Stop | S3（第一版下载适配；Agora 也支持其他厂商存储，但需对应下载适配） | 通过 S3 读取后由 Demo 下载 | ❌ 真实调用 `acquire` 返回 HTTP 401；未验收 |
| LiveKit | `livekit-cloud-recording.ts` | LiveKit Egress API，配 LiveKit Cloud 服务 | S3 | 通过 S3 读取后由 Demo 下载 | ✅ **用户确认已可用（2026-10-12）** |
| Tencent TRTC | `trtc-cloud-recording.ts` | 腾讯云 Create/Describe/DeleteCloudRecording | 默认腾讯 VOD；可选直接写入 AWS S3 | VOD HTTPS 转发，或从 S3 私有读取后由 Demo 下载 | ⏳ 真实环境待验收 |
| Alibaba ARTC | `artc-vod-recording.ts`（默认）/ `artc-cloud-recording.ts`（旧 OSS） | 阿里云 Live RTC Start/Stop/DescribeRtcCloudRecordingFiles | 默认阿里云 VOD；旧 OSS 可显式启用；**不新增 AWS S3** | VOD GetPlayInfo MP4 HTTPS 转发；旧 OSS 流式下载 | ⏳ 真实环境待验收 |
| AWS Chime SDK | `chime-cloud-recording.ts` | AWS Media Capture Pipeline + Media Concatenation Pipeline | S3 | 完成云端合成后从 S3 读取 MP4 | ⏳ 真实环境待验收 |
| AWS IVS Real-Time | `ivs-cloud-recording.ts` | AWS IVS Composition（HLS）+ AWS MediaConvert（云端 MP4 转码） | S3 + IVS Encoder/Storage ARN + MediaConvert IAM Role | 等录制完成事件 → MediaConvert Job 完成 → S3 MP4 下载 | ⏳ 真实环境待验收 |

接口已实现并通过模拟厂商 API 单测。**LiveKit Cloud 录制由项目使用者于 2026-10-12 确认可用**；该状态是使用者反馈，未在本次文档更新中独立重新执行真实云端 E2E，也不代表已逐平台验证全部布局、音轨或长时间录制。**其余供应商真实 E2E 仍待验收**；Agora 当前受 REST API `acquire` HTTP 401 阻断（与 RTC 入会、S3 文件下载属于不同环节）。

## 填写方式：存储桶可以先留空

新建房间、正常入会、聊天与其他 SDK 能力与录制配置解耦。如果录制存储没有配置，Demo 录制前查询 `recording/status` 的 `recordingAvailable: false`，并展示 `recordingUnavailableReason`；点击开始时返回明确的配置错误，**不会创建假任务，也不会消耗录制配额**。

### Agora（官方 Cloud Recording REST）

```dotenv
# 现有 Agora 入会使用的 App ID 与 App Certificate，录制复用
AGORA_APP_ID=
AGORA_APP_CERTIFICATE=

# Agora RESTful API 的 Customer ID / Customer Secret（与 App ID 不同）
AGORA_CUSTOMER_ID=
AGORA_CUSTOMER_SECRET=

# 示例第一版选择 AWS S3（Agora vendor=1）
AGORA_RECORDING_S3_BUCKET=
AGORA_RECORDING_S3_REGION=              # 如 us-east-1
AGORA_RECORDING_S3_REGION_CODE=         # Agora 的数值地域编码；us-east-1 是 0
AGORA_RECORDING_S3_ACCESS_KEY=
AGORA_RECORDING_S3_SECRET_KEY=
```

Demo Server 使用 **Basic Customer ID/Secret** 调用 `https://api.agora.io/v1/apps/{appid}/cloud_recording`，由后端生成不与客户端重复的录制 UID 和录制专用 RTC Token，执行 `acquire → mode/composite/start → query → stop`。请求中携带服务端 `recordingConfig`、`transcodingConfig`、`recordingFileConfig`（MP4）和 S3 `storageConfig`。只有厂商返回录制标识并且停止后的 MP4 真正出现在存储桶里，才向 Demo 提供下载。**不需要 `AGORA_RECORDING_SDK_JAR` / `AGORA_RECORDING_NATIVE_LIB_DIR` 或 Linux。**

Agora Cloud Recording 可以配置其他云存储厂商，但本次真正写好的 Agora MP4 **读取/下载**适配器是 S3；不要仅把 `storageConfig.vendor` 改成 COS/OSS 却继续使用 S3 下载器。

### LiveKit Cloud Egress

**验收记录（2026-10-12）：用户已确认 LiveKit 云录制可用。** 当前项目采用 LiveKit Cloud Egress → AWS S3 → Demo 下载 MP4 的执行路径，统一 Flutter SDK 录制 API 不变。后续如果调整 S3 Bucket、Egress 模式、视频布局或目标平台，应重新验证实际录制与下载；本条不等同于全部平台和音画质量的逐项验收。

```dotenv
LIVEKIT_URL=wss://your-project.livekit.cloud
LIVEKIT_API_KEY=
LIVEKIT_API_SECRET=

LIVEKIT_RECORDING_MODE=cloud
LIVEKIT_RECORDING_S3_BUCKET=
LIVEKIT_RECORDING_S3_REGION=
LIVEKIT_RECORDING_S3_ACCESS_KEY=
LIVEKIT_RECORDING_S3_SECRET_KEY=
```

默认在未填写本地 Egress 路径时使用**云端 S3**，无需 Egress Worker。服务端使用 `StartEgress → StopEgress → ListEgress`，存储字段由后端注入；上传完成后通过受控 S3 Key 验证文件再提供下载。为了不破坏之前的自部署示例，仍可通过 `LIVEKIT_RECORDING_MODE=local` + `LIVEKIT_EGRESS_OUTPUT_DIR`、`LIVEKIT_RECORDING_EXPORT_DIR` 使用旧的共享本地挂载目录模式。**推荐 Demo 使用 cloud。**

### Tencent TRTC 云录制 / VOD 或 AWS S3

```dotenv
TRTC_SDK_APP_ID=
TRTC_SDK_SECRET_KEY=
TENCENTCLOUD_SECRET_ID=
TENCENTCLOUD_SECRET_KEY=
TRTC_RECORDING_CALLBACK_KEY=
TRTC_RECORDING_VOD_HOSTS=
TRTC_RECORDING_REGION=ap-guangzhou
TRTC_RECORDING_STORAGE=vod

# 可选：将 TRTC_RECORDING_STORAGE 改为 s3，直接写入 AWS S3
# 此模式不需要 TRTC_RECORDING_VOD_HOSTS，但仍需要回调签名密钥
TRTC_RECORDING_S3_BUCKET=
TRTC_RECORDING_S3_REGION=              # 例如 ap-southeast-1
TRTC_RECORDING_S3_ACCESS_KEY=
TRTC_RECORDING_S3_SECRET_KEY=
```

默认 VOD 模式不需要 AWS S3 Bucket，但必须开通腾讯云 VOD。可切换 S3 模式：官方 `CreateCloudRecording` 的 `StorageParams.CloudStorage.Vendor=1` 直接写入 AWS S3（不是后端二次转存）。回调地址统一配置为 `https://<your-backend>/webhooks/recording/trtc`，且服务端可由公网访问；后端验签后仅接受当前房间 TaskId 的 **311（VOD）**或 **310（S3）** 完成事件。S3 模式必须验证受控前缀 `flutter_realtime_demo/trtc/<TaskId>/<filename>.mp4` 下的对象实际存在，才能开放下载。录制生成的多段 MP4 当前 V1 只导出首个回调文件，不提供自动合并。

配置 S3 Bucket 最小写入权限及后端私有读取权限，设置生命周期自动清理录像；S3 密钥只存储于服务端。注意录制本身与 S3 存储/请求/下行流量可能另外计费。

### Alibaba ARTC → VOD（默认，不依赖 AWS S3）

```dotenv
ARTC_APP_ID=
ALIBABA_CLOUD_ACCESS_KEY_ID=
ALIBABA_CLOUD_ACCESS_KEY_SECRET=

# 默认 ARTC_RECORDING_STORAGE=vod，使用阿里 Live 新版 RTC 云录制 API
ARTC_RECORDING_STORAGE=vod
ARTC_RECORDING_VOD_REGION=cn-shanghai   # 或 ap-southeast-1；us-east-1 暂不支持 VOD
ARTC_RECORDING_VOD_STORAGE_LOCATION=    # 阿里云 VOD 媒资管理 > 存储管理里的存储地址
ARTC_RECORDING_VOD_TRANSCODE_GROUP_ID=  # VOD 转码模板组（必须产生未加密的 MP4）
ARTC_RECORDING_VOD_HOSTS=               # 下载 HTTPS 域名白名单，逗号分隔，须精确匹配
```

新适配器调用官方 `@alicloud/live20161101` 的 `StartRtcCloudRecording → StopRtcCloudRecording → DescribeRtcCloudRecordingFiles`，取得混流录像的 `VodMediaList[].MediaIds/MergedIds` 后，通过 `@alicloud/vod20170321` 的 `GetPlayInfo` 获取未加密 MP4 播放地址，由 Demo Server 代理 HTTP 下载，**不需要 AWS S3**。VOD 本身需要开通并配置存储，可能产生录制/存储/转码/下载费用。

V1 录制开始时订阅当前房间内在线发布者；Grid 使用静态宫格，Speaker 固定突出第一个发布者，当前版本**尚不支持录制开始后自动同步新加入成员，也不支持自动切换当前发言人**。默认导出一个已完成、未加密且位于配置域名白名单内的 MP4；如果厂商返回多个媒体分段，则报明确错误，不误把单片段当作完整录像。必须在 VOD 模板中生成 MP4。

### Alibaba ARTC 旧 OSS 模式（保留兼容，不新增 S3）

```dotenv
ARTC_RECORDING_STORAGE=oss
ARTC_RECORDING_TEMPLATE_ID=
ARTC_RECORDING_OSS_BUCKET=
ARTC_RECORDING_OSS_REGION=             # 例如 oss-cn-shanghai
ARTC_RECORDING_OSS_REGION_CODE=        # 阿里云 RTC 所需的数值地域编码
ARTC_RECORDING_OSS_ACCESS_KEY=
ARTC_RECORDING_OSS_SECRET_KEY=
```

旧模式继续使用 `@alicloud/rtc20180111` 的 `StartCloudRecord` 和 OSS；录制布局/编码由旧模板决定。该旧接口本身不支持 VOD，不能通过修改 `StorageConfig.Vendor` 实现 VOD。

### AWS Chime SDK 云录制 / MP4 云端合成

```dotenv
AWS_REGION=
CHIME_RECORDING_S3_REGION=
CHIME_RECORDING_S3_BUCKET=
# AWS 的服务端角色/环境变量凭证由标准 AWS SDK Provider Chain 提供
```

使用 `CreateMediaCapturePipeline` 开始捕获；停止时创建 `CreateMediaConcatenationPipeline` 并结束 Capture；再通过 `GetMediaPipeline` 等待合成完成。预期 S3 Key 仅使用服务端生成的前缀和该 Concatenation Pipeline ID，防止下载其他会议录像。音视频合成由 AWS 执行，不在 Demo Server 转码。需要为 Chime Media Pipelines 配置正确的 S3 Bucket Policy 与 IAM 权限。此第一版采用 Chime GridView 合流；布局/预设的完全映射及真实 AWS 云端回放仍需验证。

### AWS IVS Cloud Composition + AWS MediaConvert（完全云端 MP4）

```dotenv
IVS_REALTIME_REGION=us-east-1
IVS_RECORDING_AWS_REGION=us-east-1
IVS_RECORDING_S3_BUCKET=
IVS_RECORDING_STORAGE_CONFIGURATION_ARN=
IVS_RECORDING_ENCODER_CONFIGURATION_ARN=
IVS_RECORDING_MEDIACONVERT_ROLE_ARN=
# IAM 权限由 AWS SDK 默认凭据链提供，密钥不放客户端
```

直播 Stage、录制所用 IVS Encoder/Storage Configuration 以及 S3 Bucket 必须位于同一区域。设置 `IVS_REALTIME_REGION=us-east-1` 时，也应将 `IVS_RECORDING_AWS_REGION` 设置为 `us-east-1` 并使用该区域的 S3 Bucket。修改区域只影响后续创建的 Stage，不会迁移已存在的直播房间。

IVS Real-Time Stage Composition 的**原生录像是 HLS**。为保持统一 MP4 下载，Demo 实现了两项 AWS 供应商托管服务的编排：`StartComposition → StopComposition`，再等待录制 S3 前缀里的 `events/recording-ended.json`，检查 `media/hls/multivariant.m3u8`，调用 **AWS MediaConvert CreateJob/GetJob** 转码为 MP4，最后验证云存储里的 MP4 并开放一次性下载。**所有媒体转码均在 AWS 云端执行；Demo Server 不跑 FFmpeg 或其他录制引擎**。

需要先在 IVS 控制台创建 EncoderConfiguration / StorageConfiguration，并为 MediaConvert 服务角色授予读取 IVS HLS 对象和写入 MP4 的 S3 权限。默认使用 IVS Grid 合流；`speaker` 布局尚未映射到 IVS 特定布局。存储配置留空时会显示明确的 `recordingAvailable: false`；这一组合服务的真实 HLS 文件路径、权限与媒体质量 **尚未在 AWS 云服务上 E2E 验收**。IVS 产生的原始 HLS 文件不会在 MP4 下载后自动清理，建议设置 S3 生命周期过期规则。

## SDK 与 Demo 使用方式

```dart
final started = await room.startRecording(
  RecordingOptions.cloud(layout: RecordingLayout.grid),
);
// 默认按厂商执行器发起录制；失败时为明确的供应商/配置错误。

await room.stopRecording(); // 可能暂时是 processing
final status = await room.queryCloudRecording();
if (status.metadata['canDownload'] == true) {
  final url = await room.cloudRecordingDownloadUrl();
  // Web、Android、iOS、macOS 和 Windows 的 Demo 都可使用 URL 下载 MP4。
}
```

`RealtimeRoom` API、权限认证和参数模型全部是 **provider-neutral**：App 不要传存储桶、Key、Secret、厂商录制任务 ID，也不允许从 Flutter 客户端覆盖服务器存储配置。

## Demo Server API、权限、导出及清理

| 方法与路径 | 说明 |
|---|---|
| `POST /rooms/:code/recording/start` | 仅房主，真实调用对应供应商 API，参数只允许 grid/speaker + 720p/1080p |
| `POST /rooms/:code/recording/stop` | 仅房主，提交云端停止与文件封装 |
| `POST /rooms/:code/recording/status` | 仅房主，`state` + `recordingAvailable` + `recordingUnavailableReason` |
| `POST /rooms/:code/recording/download` | 仅房主，确认 MP4 可用后发放 **60 秒、一次有效、房间绑定**的票据 |
| `GET /rooms/:code/recording/export/:ticket` | 服务器从 S3/OSS/腾讯 VOD 流式转发真实 MP4，浏览器直接下载 |
| `POST /webhooks/recording/trtc` | TRTC 经过签名校验的 VOD 录制完成回调 |

Demo 云存储执行器在 MP4 传输**完整成功后**，尽力删除本次产生的 S3/OSS MP4 对象，避免长期占用示例 Bucket；删除失败会在服务器记录告警，不影响已经完成的下载。IVS 云端转码仍会留存原始 HLS，TRTC VOD 文件暂不由这个通用删除流程自动删除，建议配置供应商存储的自动过期规则。**正式项目需要决定更完整的留存策略和一段时间内允许重复下载的规则**。

后端录像任务和一次性票据都在内存里，重启后无法恢复；这符合最小 Demo，但不适合生产长期管理文件。Bucket 或存储服务可先留空，实际测试录制之前必须开通、授予最低权限；供应商的 RTC、云录制、S3/OSS/VOD 费用另计。

## 验证

```sh
cd demo-server
npm run typecheck
npm test

cd ../packages/flutter_realtime_sdk_runtime
flutter test --no-pub test/http_cloud_recording_session_test.dart test/recording_controller_test.dart
```

单元测试使用可注入的云厂商响应和对象存储模拟，不涉及真实账号扣费。LiveKit 已有上述用户可用性确认；其他厂商以及 LiveKit 尚未单独确认的场景仍需分别验收 **真实用户入会 → 双人音视频 → 云端录制 → MP4 布局/声音回放 → 授权下载 → 清理**。

官方参考：[Agora Cloud Recording REST](https://docs.agora.io/en/cloud-recording/get-started/getstarted)、[LiveKit Egress](https://docs.livekit.io/home/egress/overview/)、[Amazon Chime Media Pipelines](https://docs.aws.amazon.com/chime-sdk/latest/dg/create-concat-pipe-steps.html)、[Amazon IVS Stage Composition](https://docs.aws.amazon.com/ivs/latest/RealTimeUserGuide/rt-composite-recording.html)、[阿里云 RTC Cloud Record](https://help.aliyun.com/zh/document_detail/2703647.html)。
