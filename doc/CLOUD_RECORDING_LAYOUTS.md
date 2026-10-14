# 云录制布局能力与跨供应商适配

> 更新：2026-10-14。本文描述 **实际服务端执行器** 而不是 Flutter 客户端 UI 的排列方式。云录制 API 是否配置成功、真实输出的音画是否正确，仍需单独验收。录制与下载配置见 [CLOUD_RECORDING.md](CLOUD_RECORDING.md)。

## 统一语义

Flutter 应用只使用 `RecordingOptions.cloud(layout: ...)`，无需知道供应商的混流 API。

| `RecordingLayout` | 含义 | 注意 |
|---|---|---|
| `grid` | 等大的参与者画面组成宫格 | 全部六个执行器提供；人数、最大画面数依供应商限制。 |
| `featuredParticipant` | 固定突出一个参与者，其他视频可能缩小、悬浮或不显示 | **不随语音自动切换**。目前 Demo 由服务端/供应商决定主画面，未提供用户任意点名指定能力。 |
| `activeSpeaker` | 根据发言状态自动聚焦主画面 | 目前仅 LiveKit Cloud RoomComposite 的 `speaker` 模板被标记支持。其他供应商不可传此模式。 |
| `speaker` | 历史兼容值 | 服务端按当前供应商转为 `featuredParticipant` 或 `activeSpeaker`，不能保证跨厂商语义一致；新接入不要使用。 |
| `screenShare` / `custom` | 预留能力 | Demo Server V1 不接受；不能仅看 Dart 枚举就认定供应商支持。 |

## 供应商实际执行映射

| 供应商/执行器 | `grid` | `featuredParticipant` | `activeSpeaker` | 录制真实验收 |
|---|---|---|---|---|
| LiveKit RoomComposite Egress | `template.layout=grid` | — | `template.layout=speaker`（录制模板跟随主要发言视频） | ✅ 已确认云录制可用；需实测多人切换 |
| Agora Cloud Recording | `mixedVideoLayout=1` 自适应网格 | `mixedVideoLayout=0` 悬浮画面；主画面由 Agora 排列规则决定 | — | ❌ Agora `acquire` 401，未验收 |
| Tencent TRTC | `MixLayoutMode=3` 九宫格 | `MixLayoutMode=1` 悬浮画面，通常突出最先进入的发布者 | — | ⏳ 待真实验收 |
| Alibaba ARTC VOD | 静态参与者宫格 | 录制开始时优先选择房主为固定大画面 | — | ⏳ 待真实验收 |
| Alibaba ARTC OSS（旧模式） | 由 `ARTC_RECORDING_TEMPLATE_ID_GRID` 或旧的 `ARTC_RECORDING_TEMPLATE_ID` 预配置 | **仅**配置 `ARTC_RECORDING_TEMPLATE_ID_SPEAKER` 才开放，实际画面取决于模板 | — | ⏳ 待真实验收 |
| AWS Chime Media Pipelines | `GridView` | — | — | ✅ 已确认录制/下载可用；布局仍待实测 |
| AWS IVS Real-Time | `{grid:{}}` | `{grid:{featuredParticipantAttribute:'isFeatured'}}`，固定突出 Token 中标记的主持人 | — | ✅ 已确认录制/下载可用；布局仍待实测 |

**为什么 Chime 只有宫格？** AWS Chime `CompositedVideo` 当前只支持 `GridView` 作为摄像头布局。`ActiveSpeakerOnly` / `PresenterOnly` 是 **有屏幕共享时的内容共享覆盖层**，不能实现普通摄像头会议的全屏自动主讲人。Demo 拒绝伪装支持，不再将两种选择录成相同画面。未来若需要此能力，必须引入独立的云端合成方案并评估额外成本，而不是仅修改配置参数。

**为什么 IVS 不能自动切人？** IVS 的 `isFeatured` 是参与者令牌属性。可以借助 token exchange 更换此属性，但目前没有经过鉴权、节流与真实语音活动事件驱动的切人流程，故只提供固定主画面。

## 能力查询、权限与出错行为

通过现有仅房主可调用的接口查询支持模式：

`POST /rooms/:code/recording/status`，请求正文带当前房间管理凭据，返回示例：

```json
{
  "state": "idle",
  "provider": "chime",
  "recordingAvailable": true,
  "supportedLayouts": ["grid"],
  "canDownload": false
}
```

`recordingAvailable` 代表凭据、云存储等配置预检；即使为 `false` 也返回受支持的布局，供 UI 显示。它不承诺真实录制一定成功。Flutter `room.queryCloudRecording()` 在 `RecordingResult.metadata['supportedLayouts']` 获得名单。Demo 的两个入口统一调用 `demo_recording_layout_picker.dart`，按此名单生成选择器；旧服务端没返回名单时仅展示最保守的宫格。

`POST /rooms/:code/recording/start` 支持以下布局值：

```json
{"layout":"grid","containerFormat":"mp4","streamType":"both","rawProviderParams":{"preset":"H264_720P_30"}}
```

把 `layout` 换成 `featuredParticipant` / `activeSpeaker` 会先检查对应供应商是否支持，**不支持返回 HTTP 422 `unsupported-recording-layout`**，不会自动退化为宫格，不会触发云录制扣费。旧值 `speaker` 仅作兼容性映射。未认证房主返回 403，非法值返回 400。录制存储凭据和任务 ID 仍由服务器持有，前端不得传入密钥或任意存储配置。

```dart
final status = await room.queryCloudRecording();
final names = (status.metadata['supportedLayouts'] as List?)
        ?.whereType<String>().toSet() ?? {'grid'};
if (names.contains(RecordingLayout.featuredParticipant.name)) {
  await room.startRecording(RecordingOptions.cloud(
    layout: RecordingLayout.featuredParticipant,
  ));
} else {
  await room.startRecording(RecordingOptions.cloud(
    layout: RecordingLayout.grid,
  ));
}
```

## 质量、入会变化与已知限制

* 主流执行器接收 `H264_720P_30` / `H264_1080P_30` 两种预设；TRTC 与 ARTC VOD 的请求已按所选预设映射宽高、帧率和编码码率。实际帧率与图像质量仍取决于上行轨道、供应商限制与模板。ARTC 旧 OSS 模式由模板控制画质，并非动态响应本参数。
* **ARTC VOD** 录制开始时订阅在线发布者；服务端在房主发起的 `recording/status` 轮询或 `recording/stop` 前，会比较最新房间成员并调用厂商 `UpdateRtcCloudRecording` 重算订阅与画面。**这是轮询驱动的尽力同步**，不保证无人轮询时及时加入新成员；正式教学课堂仍建议由入会/离会事件主动触发，且验证录制服务端与 SDK 用户 ID 的一致性。固定主画面保持初始主讲人，离开后选择下一位在线发布者，不会自动跟随发言人。
* **ARTC OSS 旧模式** 的默认录制模板必须由部署者保证为宫格。若要固定主画面，请分别配置、验证两个模板 ID；传入额外 ID 不会使模板自动拥有对应效果。
* **Agora / TRTC** 固定主画面目前使用供应商默认的悬浮布局选择规则，不支持由 Demo 任意指定某个人，也不检测谁在发言。
* **AWS IVS** 的主画面在主持人发布视频且 `isFeatured` 标记可用时有效；主持人不在场时不会伪装存在主画面。
* **LiveKit** 的 `activeSpeaker` 属于录制视图模板提供的布局行为；应当用至少三名发布者交替发言、屏幕共享、静音、退出再加入进行真实 MP4 回放验收。
* 新布局模式属于**录制内容**，并不修改 Demo 会议实时视图。停止、MP4 转码、下载票据及云存储清理流程保持现有实现。

## 回归验证

在项目根目录分别运行：

```sh
cd demo-server && npm run check
cd ../example && flutter analyze lib/widgets/demo_recording_layout_picker.dart lib/widgets/demo_recording_widgets.dart lib/demo_composable_meeting_page.dart
```

当前仍应在真实厂商账号验收以下场景：Grid 3 人、固定主画面（含房主断线）、LiveKit 交替发言、录制过程中新增发布者、屏幕共享、MP4 声道和多人成员音视频同步。测试替身通过不能替代计费服务 E2E；Agora 401 需先解决账户认证问题。

## 官方依据

* [AWS Chime Compositing](https://docs.aws.amazon.com/chime-sdk/latest/dg/compositing-layouts.html)
* [LiveKit Egress Composite Layout](https://docs.livekit.io/transport/media/ingress-egress/egress/composite-recording/)
* [Tencent TRTC MixLayoutParams](https://cloud.tencent.com/document/api/647/44055)
* [Alibaba UpdateRtcCloudRecording](https://help.aliyun.com/zh/live/developer-reference/api-live-2016-11-01-updatertccloudrecording/)
* [AWS IVS Server-side Composition](https://docs.aws.amazon.com/ivs/latest/RealTimeUserGuide/ssc-overview.html)
