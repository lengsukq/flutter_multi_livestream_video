# Flutter Realtime Media

**English** | [简体中文](#简体中文)

Flutter Realtime Media is a provider-neutral Flutter media SDK architecture
for real-time audio/video communication and one-to-many live sessions.

The Flutter application works against one Core API while the application backend
decides which media provider a room uses. Provider-specific SDKs live in optional
adapter packages, so applications can add or remove providers without coupling
business UI to a specific vendor.

The repository currently supports **AWS**, **LiveKit**, **Agora**,
**Tencent TRTC**, and **Alibaba Cloud ARTC**. AWS is exposed as one vendor:
**Meeting routes to Amazon Chime SDK and Live routes to Amazon IVS Real-Time**. The original
`packages/flutter_aws_chime` v3 package remains available for
existing Chime-only applications and is kept backward compatible.

## Packages

| Package | Purpose | Status |
| --- | --- | --- |
| `flutter_realtime_sdk` | Recommended high-level Media + Chat + renderer + lifecycle orchestration | Implemented |
| `flutter_realtime_media_core` | Provider-neutral session, capability, event, backend and rendering contracts | Implemented |
| `flutter_realtime_media_ui` | Provider-neutral ready-to-use meeting UI driven by Core capabilities | Implemented |
| `flutter_realtime_media_livekit` | LiveKit RTC + host/viewer adapter | Implemented |
| `flutter_realtime_media_agora` | Agora RTC + host/viewer adapter | Implemented; real-service E2E optional |
| `flutter_realtime_media_chime` | AWS Chime adapter for Core | Implemented |
| `flutter_realtime_media_trtc` | Optional Tencent TRTC RTC + host/viewer adapter | Implemented; real-device E2E optional |
| `flutter_realtime_media_artc` | Optional Alibaba Cloud ARTC RTC + host/viewer adapter | Implemented; real-device E2E optional |
| `flutter_realtime_media_ivs` | Amazon IVS Real-Time Stage + host/viewer adapter | Android/iOS implemented |
| `flutter_realtime_chat_core` | Provider-neutral product chat client/session contract | Implemented |
| `flutter_realtime_chat_ivs` | Amazon IVS Chat adapter | Android/iOS implemented |
| `flutter_realtime_chat_tencent` | Tencent Cloud Chat adapter | Implemented; SDK-backed multi-platform adapter |
| `flutter_realtime_chat_agora` | Agora Chat adapter | Android/iOS implemented |
| `flutter_realtime_chat_rtc` | Adapts bidirectional RTC data to `ChatSession` when no product Chat Provider is bound | Implemented |
| `flutter_aws_chime` | Existing standalone Chime v3 Flutter plugin | Maintained for compatibility |

Provider SDKs are dependencies of their own adapters, never of Core. Applications
add and register only the adapters they need. Optional SDKs are downloaded only
when their adapter is added. ARTC 7.11.0 supports Android and iOS device builds;
its iOS CocoaPod does not link into simulator builds. Provider choice remains
with the backend. The Agora adapter supports Android, iOS, and macOS; desktop
camera rendering and media control use Agora's native macOS bridge, while
front/back camera switching remains Android/iOS-only.

## Recommended SDK entry point

Applications should normally use `flutter_realtime_sdk`. Register each
available implementation as a self-describing `RealtimeProviderPlugin`, then
create one `RealtimeSdk`. Backend room responses still select the actual
provider; plugins only declare what the application binary can execute.
`RealtimeRoom` resolves the media renderer, backend-selected Product Chat,
RTC-data Chat fallback (only when no Product Chat is configured), joint
lifecycle cleanup, and aggregated room state/events.

```dart
final sdk = RealtimeSdk(
  backendUrl: backendUrl,
  plugins: [
    RealtimeProviderPlugin(
      id: 'my-provider',
      metadata: const RealtimeProviderMetadata(
        displayName: 'My Provider',
      ),
      mediaFactory: myProviderFactory,
      renderer: myProviderRenderer,
      chatFactory: myOptionalChatFactory,
    ),
  ],
  tokenProvider: () async => applicationToken,
);

final room = await sdk.joinRoom(
  roomCode: roomCode,
  user: const MediaIdentity(
    userId: 'user-123',
    displayName: 'Alice',
  ),
);

try {
  // The built-in UI consumes the resolved room directly.
  final page = RealtimeRoomView(room: room);
  room.events.listen((event) {
    // One provider-neutral stream for media, chat, state and backend failures.
  });
} finally {
  await room.dispose();
}
```

Pre-Join is also available on the facade and owns its temporary low-level
client automatically:

```dart
final report = await sdk.preJoin(
  roomCode: roomCode,
  role: MediaRole.participant,
);
```

See `example/lib/minimal_sdk_example.dart` for the shortest complete
navigation example. The main example remains a full showcase for room
discovery, Pre-Join, Meeting/Live and the server dashboard.

`RealtimeSdk` maps high-level failures to `RealtimeException` with a stable
`RealtimeErrorCode`, while retaining `providerId`, the original `cause`,
`recoverable`, and a small `suggestedAction` hint. `RealtimeClient`,
`MediaClient`, and `ChatClient` remain supported escape hatches and retain
their existing lower-level error contracts.

Provider plugins are configuration, not routing. Adding a provider should
normally require implementing its adapter package and registering one plugin;
application room code must not branch on provider ids.

Backend Contract v1 remains authoritative and is validated by Core. A backend
may additionally return a provider-neutral `requiredCapabilities` array in a
join response. The high-level SDK verifies those requirements against the
resolved media/product-chat session and fails with a typed unsupported-feature
error instead of silently degrading. See `MEDIA_BACKEND_CONTRACT.md`.

## Provider status

| Provider | Meeting | Live / broadcast | Status |
| --- | --- | --- | --- |
| AWS Chime | Yes | No (participant only) | Implemented |
| LiveKit | Yes | Yes, host/viewer | Implemented |
| Agora | Yes | Yes, host/viewer | Adapter implemented |
| Tencent TRTC | Yes | Yes, host/viewer | Optional adapter implemented |
| Alibaba Cloud ARTC | Yes | Yes, host/viewer | Optional adapter implemented |
| Amazon IVS Real-Time | Yes | Yes, host/viewer | Android/iOS implemented |

See [`MULTI_PROVIDER_GUIDE.md`](MULTI_PROVIDER_GUIDE.md) for the unified API and
backend-selected provider flow. The detailed runtime capability matrix is
available in [English](SDK_CAPABILITY_MATRIX.md) and
[简体中文](SDK_CAPABILITY_MATRIX.zh-CN.md).

## Backend-selected provider flow

The app sends room/user intent only. The backend returns the selected provider
plus short-lived join credentials, and Core resolves the matching adapter.
Long-lived provider credentials stay on the backend.

```text
Flutter app
   │ room / user / role
   ▼
Application backend
   │ selects provider
   ├── LiveKit
   ├── Agora
   ├── AWS Chime
   ├── Tencent TRTC (optional)
   ├── Alibaba Cloud ARTC (optional)
   └── Amazon IVS Real-Time (optional)
   │
   ▼
Core → matching provider adapter
```

The included `demo-server` exposes provider selection in its server UI. The
Flutter demo itself does not need a provider selector.

### Product Chat, RTC fallback Chat, and RTC Data Debug

The ready-to-use UI consumes only `ChatSession` for user-facing chat. Resolution
is explicit: when `room.chatProvider` is present, the app uses that product-chat
provider only. When it is absent, `flutter_realtime_chat_rtc` may adapt the
already-connected media session into a `ChatSession`, but only when both
`canSendData` and `canReceiveData` are true. A configured product-chat failure
does not silently fall back to RTC data.

`showRtcDataMessages` remains a separate debug/control surface backed by
`MediaDataMessenger`; its payloads are not injected into the Chat message list.
Amazon IVS Real-Time has no RTC data transport and therefore has no RTC Chat
fallback. Chat capability never grants microphone/camera publish permission.

## Pre-Join checks

Before creating or joining a room, applications can run the provider-neutral
`MediaClient.runPreJoinCheck()` API. It can check backend reachability,
registered provider availability, microphone/camera permission state, device
availability, and basic network readiness without creating a media room.

```dart
final result = await client.runPreJoinCheck(
  role: MediaRole.participant,
  requirements: const MediaPreJoinRequirements(
    microphone: MediaPreJoinRequirement.required,
    camera: MediaPreJoinRequirement.recommended,
  ),
);

if (!result.isReady) {
  for (final issue in result.blockingIssues) {
    debugPrint(issue.message);
  }
}
```

- `required`: failed, unsupported, or unknown checks block continuation.
- `recommended`: problems are warnings and may continue.
- `skipped`: the check is omitted.
- Provider-specific diagnostics are optional through `MediaPreJoinProbe`.
  LiveKit currently pre-enumerates microphone/camera devices; provider network
  probes that would require issued room credentials report `unsupported`
  instead of creating a room just to test connectivity.
- `GET /health` is an optional diagnostic endpoint, not a mandatory backend
  contract requirement. A missing endpoint such as HTTP 404 does not block
  joining. Connection/timeout failures block; an implemented health endpoint
  that explicitly returns an error such as 5xx is treated as a backend-health
  failure.

The default permission probe uses `permission_handler` only to inspect current
permission state and never displays an OS permission prompt. Host application
setup is documented in
[`packages/flutter_realtime_media_core/PRE_JOIN_SETUP.md`](packages/flutter_realtime_media_core/PRE_JOIN_SETUP.md).

---

## Chime v3 compatibility package

`flutter_aws_chime` is the original Flutter client package for joining Amazon
Chime SDK meetings from iOS and Android apps. It provides a Dart session API,
typed meeting state and events, media controls, data messages, remote video and
screen-share rendering, and an optional ready-to-use meeting view.

The application backend creates the Chime meeting and attendee and returns
short-lived join information. The package connects the client to the meeting
media session; it does not create AWS meetings or handle AWS long-term
credentials.

## Chime v3 platform support

| Platform | Meeting support | Minimum / build requirement |
| --- | --- | --- |
| iOS | Supported | iOS 15+ |
| Android | Supported | Android API 23+; Java 17; compile SDK 37 |
| macOS | Not supported | No meeting implementation in v3 |
| Windows | Not supported | No meeting implementation in v3 |
| Linux | Not supported | No meeting implementation in v3 |
| Web | Not supported | No meeting implementation in v3 |

Requires Flutter 3.47.0+ and Dart 3.12.0+. Android uses AGP 9 built-in Kotlin with a JVM 17 target. The iOS plugin uses Swift 5.0 and supports both CocoaPods and Swift Package Manager. For the Flutter 3.47 local-path SwiftPM checkout-name limitation, see [`DEVELOPMENT.md`](DEVELOPMENT.md). Desktop and Web are not declared as plugin platforms; meeting API calls there throw `ChimeException` with `ChimeErrorCode.unsupportedPlatform`.

## Chime v3 features

- Join and leave an existing Chime SDK meeting.
- Microphone mute/unmute, local camera start/stop, and front/back camera switching.
- Enumerate and choose the active audio output device.
- Receive attendee changes, remote video tiles, and screen-share tiles.
- Send and receive Chime real-time data messages.
- Observe connection and reconnect, camera availability, attendee volume/signal, and video-tile events.
- Use `ChimeMeetingSession` independently with a custom UI, or pass it to optional `ChimeMeetingView`.

Only one active Chime session is allowed at a time by the native implementation. Removing `ChimeMeetingView` does not release the meeting; the code that created the session owns its lifecycle and must call `leave()` or `dispose()`.

## Chime-only installation

After v3 is published, add it to your app:

```yaml
dependencies:
  flutter_aws_chime: ^3.0.0
```

For local development, use a path dependency to this repository. The host app must meet the Flutter, Dart, Java, Android compile SDK, and iOS deployment requirements above.

## App permissions

### iOS

Add purpose strings to the host app's `ios/Runner/Info.plist`. iOS requests microphone and camera access when `join()` is called.

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Allow microphone access for Chime meetings.</string>
<key>NSCameraUsageDescription</key>
<string>Allow camera access for Chime meetings.</string>
```

### Android

The plugin manifest contributes Internet, camera, microphone, and audio-settings permissions. The package requests camera and microphone access when `join()` is called. Check the merged manifest and provide any application-specific permission rationale in your own UI.

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

If either runtime permission is denied, `join()` fails with a typed `ChimeException` whose code is `permissionDenied`.

## Backend responsibility and credentials

Your backend must create the meeting and attendee for the authenticated app user, then return the meeting, media placement, attendee ID, external user ID, and short-lived `JoinToken` to the app over an authenticated connection. Keep AWS access keys and secret keys on the server. Never embed them in the Flutter app or send them to this package.

See the [AWS Chime SDK guide to creating meetings](https://docs.aws.amazon.com/chime-sdk/latest/dg/create-mtgs.html) and the [demo-server README](https://github.com/lengsukq/flutter_multi_livestream_video/blob/main/demo-server/README.md) for the response shape. This package does not call `CreateMeeting` or `CreateAttendee` and does not store AWS credentials.

```json
{
  "meeting": {
    "MeetingId": "...",
    "ExternalMeetingId": "...",
    "MediaRegion": "us-east-1",
    "MediaPlacement": {
      "AudioHostUrl": "...",
      "AudioFallbackUrl": "...",
      "SignalingUrl": "...",
      "TurnControlUrl": "..."
    }
  },
  "attendee": {
    "AttendeeId": "...",
    "ExternalUserId": "...",
    "JoinToken": "..."
  }
}
```

## Quick start

If your application backend implements [`BACKEND_CONTRACT.md`](BACKEND_CONTRACT.md),
the high-level client handles HTTP, `JoinInfo`, heartbeat, and best-effort leave
notification for you. The backend may be implemented in Java, Python, Node.js,
Go, or any other stack.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_aws_chime/flutter_aws_chime.dart';

Future<void> openRoom(BuildContext context) async {
  final client = ChimeClient(
    backendUrl: 'https://api.example.com',
    // Optional application auth. This is not an AWS credential.
    tokenProvider: () async => 'your-app-token',
  );

  final room = await client.joinRoom(
    roomCode: '482913',
    nickname: 'Leo',
  );
  try {
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: ChimeMeetingView(
            session: room.session,
            title: 'Room ${room.roomCode}',
            onLeave: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  } finally {
    await room.dispose();
    client.dispose();
  }
}
```

Use `ChimeClient.createRoomAndJoin(...)` for the matching create-and-join flow.
`ChimeRoomSession` owns backend presence lifecycle while the media session is
active. Backend heartbeat failures are exposed through `room.backendErrors`
and do not automatically stop healthy Chime media.

### Direct `JoinInfo` integration

Applications with an existing backend contract can skip `ChimeClient` and
continue to pass meeting and attendee responses directly. `response` below is
the JSON object returned by that backend after creating a meeting and attendee.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_aws_chime/flutter_aws_chime.dart';

Future<void> openMeeting(
  BuildContext context,
  Map<String, dynamic> response,
) async {
  final session = ChimeMeetingSession();
  try {
    await session.join(JoinInfo.fromJson(response));
    if (!context.mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: ChimeMeetingView(
            session: session,
            title: 'Team meeting',
            onLeave: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  } finally {
    // The code that created the session owns cleanup, including after errors.
    await session.dispose();
  }
}
```

`join()` requests microphone and camera access, then connects using the short-lived meeting and attendee data. The view calls `session.leave()` when the user taps Leave. Removing the view does not call `dispose()`.

## Session API

The package entry point exports the high-level `ChimeClient` / `ChimeRoomSession`
API as well as `ChimeMeetingSession`, `JoinInfo`, meeting models, state and event
types, typed backend/media errors, audio device types, `MeetingVideoTileView`,
and `ChimeMeetingView`.

```dart
final session = ChimeMeetingSession();
final stateSubscription = session.states.listen((state) {
  debugPrint('Meeting state: $state');
});
final eventSubscription = session.events.listen((event) {
  debugPrint('Chime event: $event');
});

await session.join(joinInfo);
debugPrint('Current state: ${session.state}');
await session.setMuted(true);
await session.setVideoEnabled(true);
await session.switchCamera(CameraPosition.back);

final devices = await session.listAudioDevices();
if (devices.isNotEmpty) await session.selectAudioDevice(devices.first);
await session.sendMessage('Hello', topic: 'chat');

await session.leave();
await stateSubscription.cancel();
await eventSubscription.cancel();
await session.dispose();
```

`session.snapshot` exposes the latest attendees, local media state, received screen-share tile, messages, and audio-device selection. `states` and `events` are broadcast streams; read `session.state` or `session.snapshot` for the current value when subscribing later. A session may be joined again after it has ended, but only one session may be active at a time.

`ChimeAudioDevice` provides the native `label` used for selection and a best-effort `ChimeAudioDeviceType` classification (`bluetooth`, `wiredHeadset`, `speaker`, `earpiece`, or `other`). Use the label for display and selection; native labels can vary by device and OS.

## Errors and troubleshooting

Asynchronous failures are reported as `ChimeException`, with a stable `code`, readable `message`, and optional native `details`.

| Code | Meaning |
| --- | --- |
| `invalidJoinInfo` | Join response is malformed or missing required AWS fields. |
| `invalidArgument` | A method argument is invalid. |
| `invalidState` | The operation is invalid for the current session state. |
| `meetingAlreadyActive` | Another Chime session is already active in the native implementation. |
| `permissionDenied` | Microphone or camera permission was denied or restricted. |
| `unsupportedPlatform` | Meeting APIs were called outside iOS or Android. |
| `sessionNotFound` | The native session has already ended or is unavailable. |
| `methodNotImplemented` | The host plugin does not implement the requested method. |
| `nativeError`, `unknown` | The native SDK or platform returned an unclassified failure. |

Common checks:

- **Permission error:** verify the iOS purpose strings or Android merged manifest, then enable access in system settings.
- **Invalid join information:** ensure the backend returns complete `Meeting` and `Attendee` objects, including `MediaPlacement` URLs and `JoinToken`.
- **No audio/video:** confirm the user granted microphone/camera access and that another session has been left.
- **Unsupported platform:** v3 meeting media runs only on iOS 15+ and Android API 23+.
- **Native build failure:** use Flutter 3.47+, Dart 3.12+, Java 17, Android compile SDK 37, and iOS deployment target 15.0+.

## Migrating from v2 to v3

Version 3.0.0 is a breaking API redesign. The old `MeetingModel`, `MeetingView`, and platform-interface APIs are removed; there is no v2 compatibility layer.

| v2 | v3 |
| --- | --- |
| `MeetingModel()` | `ChimeMeetingSession()` |
| `meeting.joinMeeting(joinInfo)` | `session.join(joinInfo)` |
| `MeetingView(joinInfo)` | `ChimeMeetingView(session: session)` |
| Boolean media-control results | `Future<void>` methods that throw `ChimeException` on failure |
| String audio-device list | `List<ChimeAudioDevice>` with `label` and `type` |
| Widget managed setup and teardown | Caller owns `join`, `leave`, and `dispose`; the view requests leave on user action |

Create the session in the screen or controller that owns the call. Subscribe to its streams, call `join()`, pass it to your UI, and call `dispose()` when that owner is finished.

## Roadmap

The repository now includes an optional provider-neutral Core plus LiveKit,
Agora, AWS Chime, Tencent TRTC, and Alibaba Cloud ARTC adapters. The original `flutter_aws_chime` v3 API remains
available unchanged for Chime-only applications.

| # | Item | Status |
|---:|---|---|
| 1 | Upgrade Flutter and AWS Chime SDK to the latest versions | Complete in 2.0.0 |
| 2 | Support more APIs from the latest Chime SDK | Complete in 2.0.0 |
| 3 | Add video/audio communication backends besides Chime | LiveKit, Agora, TRTC, ARTC, and IVS Real-Time implemented via optional adapters |
| 4 | Add one-to-many livestreaming | LiveKit, Agora, TRTC, ARTC, and IVS Real-Time host/viewer implemented |

See [`MULTI_PROVIDER_GUIDE.md`](MULTI_PROVIDER_GUIDE.md) for the current
multi-provider architecture and [`ROADMAP_IMPLEMENTATION_PLAN.md`](ROADMAP_IMPLEMENTATION_PLAN.md)
for the broader roadmap.

---

# 简体中文

Flutter Realtime Media 是一个面向 Flutter 的多 Provider 实时音视频 SDK
架构，用于多人实时音视频通信和一对多直播。

Flutter App 统一依赖 Core 接口，房间实际使用哪一家媒体服务由业务后端决定。
各供应商 SDK 通过独立 Adapter 接入，因此业务 UI 不需要绑定 LiveKit、Chime
或未来其他供应商的具体实现。

当前仓库已经支持 **AWS**、**LiveKit**、**Agora**、**腾讯云 TRTC** 和
**阿里云 ARTC**。AWS 对外作为一个 Vendor：**Meeting 自动使用 Amazon Chime SDK，
Live 自动使用 Amazon IVS Real-Time**。产品聊天是独立 Provider 轴，
当前已通过 Chat Core 接入 **Amazon IVS Chat**、**Tencent Cloud Chat** 和
**Agora Chat**。原有
`flutter_aws_chime` v3 包继续保留，供已有 Chime-only 项目兼容使用。

## 包结构

| 包 | 用途 | 状态 |
| --- | --- | --- |
| `flutter_realtime_media_core` | Provider 无关的会话、能力、事件、后端与渲染契约 | 已实现 |
| `flutter_realtime_media_livekit` | LiveKit RTC + Host/Viewer Adapter | 已实现 |
| `flutter_realtime_media_agora` | Agora RTC + Host/Viewer Adapter | 已实现；真实服务 E2E 可选 |
| `flutter_realtime_media_chime` | AWS Chime Core Adapter | 已实现 |
| `flutter_realtime_media_trtc` | 可选的腾讯云 TRTC RTC + Host/Viewer Adapter | 已实现；真实设备 E2E 可选 |
| `flutter_realtime_media_artc` | 可选的阿里云 ARTC RTC + Host/Viewer Adapter | 已实现；真实设备 E2E 可选 |
| `flutter_realtime_media_ivs` | Amazon IVS Real-Time Stage + Host/Viewer Adapter | Android/iOS 已实现 |
| `flutter_realtime_chat_core` | Provider 无关的产品聊天 Client/Session 契约 | 已实现 |
| `flutter_realtime_chat_ivs` | Amazon IVS Chat Adapter | Android/iOS 已实现 |
| `flutter_realtime_chat_tencent` | Tencent Cloud Chat Adapter | 已实现；跟随腾讯 Chat SDK 多平台能力 |
| `flutter_realtime_chat_agora` | Agora Chat Adapter | Android/iOS 已实现 |
| `flutter_realtime_chat_rtc` | 无独立产品 Chat Provider 时，将完整双向 RTC Data 适配为 `ChatSession` | 已实现 |
| `flutter_aws_chime` | 原有独立 Chime v3 Flutter 插件 | 兼容维护 |

Core 不直接依赖任何供应商 SDK，供应商依赖仅存在于各自 Adapter 中。应用只添加并注册
自己要用的适配包。ARTC 7.11.0 支持 Android 和 iOS 真机；当前 iOS CocoaPod 不支持模拟器链接。
Agora Adapter 支持 Android、iOS 和 macOS；macOS 通过 Agora 原生桌面桥接完成音视频与渲染，
前后摄像头切换仍仅在 Android/iOS 开放。

## Provider 状态

| Provider | 实时音视频 | 一对多直播 | 状态 |
| --- | --- | --- | --- |
| AWS Chime | Meeting 支持 | 不支持（仅 participant） | 已实现 |
| LiveKit | 支持 | 支持 Host/Viewer | 已实现 |
| Agora 声网 | 支持 | 支持 Host/Viewer | Adapter 已实现 |
| 腾讯云 TRTC | 支持 | 支持 Host/Viewer | 可选 Adapter 已实现 |
| 阿里云 ARTC | 支持 | 支持 Host/Viewer | 可选 Adapter 已实现 |
| Amazon IVS Real-Time | 支持 | 支持 Host/Viewer | Android/iOS 已实现 |

## 音视频与直播能力

Meeting 是多人双向音视频；Live / Broadcast 是一对多直播，房主发布音视频，观众订阅观看。
所有列出的 Provider 均支持 Meeting；除 Chime 外，其余 Provider 支持房主/观众直播模式。

| 音视频供应商 | Meeting | Live / Broadcast | RTC 数据消息 | 屏幕共享 | 房主管理 |
| --- | --- | --- | --- | --- | --- |
| LiveKit | 支持 | 支持房主/观众 | 支持，含定向和不可靠发送 | 发布者支持 | 可列出、移除参与者并关闭房间 |
| AWS Chime | 支持 | 不支持，仅 participant | 支持，单条上限 2 KiB | Adapter 未提供 | 无房主角色 |
| Agora | 支持 | 支持房主/观众 | 房主/participant 可发送，单条上限 1 KiB | 暂未实现 | 可列出参与者、关闭房间；不能服务端强制移除 |
| 腾讯云 TRTC | 支持 | 支持房主/观众 | 房主/participant 可发送，单条上限 1 KiB | Adapter 未提供 | 可列出参与者、关闭房间；不能服务端强制移除 |
| 阿里云 ARTC | 支持 | 支持房主/观众 | 房主/participant 可发送，单条上限 1 KiB | Adapter 未提供 | 可列出参与者、关闭房间；不能服务端强制移除 |
| Amazon IVS Real-Time | 支持 | 支持房主/观众 | 不支持 RTC 数据消息 | Adapter 未提供 | 可列出参与者、通过 IVS 断开参与者并关闭房间 |

产品聊天是独立于音视频 Provider 的能力。当前支持 Amazon IVS Chat、Tencent Cloud Chat 和 Agora Chat，
也可以关闭产品聊天；启用时可与上表任意音视频 Provider 配合。三者都通过统一 `ChatSession` 收发实时消息。
IVS Chat 的房主令牌支持删除消息和断开用户；Tencent/Agora 首版 Adapter 为避免把厂商后台管理权限错误地下放到
客户端，只暴露安全可验证的消息收发能力，删除/踢人明确返回 unsupported。若房间没有
绑定独立 `chatProvider`，SDK 可在当前 Media Provider 同时具备 `canSendData` 和 `canReceiveData` 时，
通过 `flutter_realtime_chat_rtc` 将 RTC Data 适配成统一 `ChatSession`。若服务端明确绑定了产品 Chat，
则始终优先使用独立 Chat，连接失败时也不会偷偷改走 RTC fallback。RTC Data Debug 继续使用
`MediaDataMessenger` 独立工作，不会进入 Chat 消息列表。IVS Real-Time 不支持 RTC Data，因此没有
RTC fallback。聊天能力也不会提升 viewer 的音视频发布权限。完整设备、预加入检查、网络统计和恢复能力见
[`SDK_CAPABILITY_MATRIX.zh-CN.md`](SDK_CAPABILITY_MATRIX.zh-CN.md)。

统一 API 与后端选择 Provider 的完整说明见
[`MULTI_PROVIDER_GUIDE.md`](MULTI_PROVIDER_GUIDE.md)。

## 后端选择 Provider

App 只提交房间、用户和角色等业务意图。后端决定实际 Provider，并返回短期
加入凭证；Core 自动解析对应 Adapter。供应商长期密钥始终只保存在服务端。

```text
Flutter App
   │ 房间 / 用户 / 角色
   ▼
业务后端
   │ 选择 Provider
   ├── LiveKit
   ├── Agora
   ├── AWS Chime
   ├── 腾讯云 TRTC（可选）
   ├── 阿里云 ARTC（可选）
   └── Amazon IVS Real-Time（可选）
   │
   ▼
Core → 对应 Provider Adapter
```

## Pre-Join 加入前检查

创建或加入房间前，可以调用 Provider 无关的
`MediaClient.runPreJoinCheck()`。它不会为了检查而创建媒体房间，可统一检查
后端可达性、目标 Provider 是否已注册、麦克风/摄像头权限、设备可用性以及基础
网络状态。

- `required`：检查失败、无法确认或 Provider 不支持时阻止继续。
- `recommended`：作为警告展示，但允许继续。
- `skipped`：完全跳过该检查。
- Provider 可通过可选的 `MediaPreJoinProbe` 增强检查。LiveKit 当前可在入会前
  枚举麦克风和摄像头；需要正式房间凭证才能执行的 Provider 网络探测会返回
  `unsupported`，不会为了测试而消耗正常加入凭证。
- `GET /health` 只是可选诊断接口，不是 Backend Contract 的强制要求。
  后端没有实现该接口（例如返回 404）不会阻止入会；连接失败或超时会阻止，
  已实现的 health 接口明确返回 5xx 等错误时则视为后端健康检查失败。

默认权限探针只读取当前权限状态，不主动弹出系统授权框。Android/iOS 宿主配置
见
[`packages/flutter_realtime_media_core/PRE_JOIN_SETUP.md`](packages/flutter_realtime_media_core/PRE_JOIN_SETUP.md)。

---

## Chime v3 兼容包

`flutter_aws_chime` 是原有的 Amazon Chime SDK Flutter 客户端包，支持在
iOS 和 Android 应用中加入 Chime 会议。它继续保留原有 Dart 会话 API、
类型化状态与事件、音视频控制、数据消息、远端视频与屏幕共享画面渲染。

应用后端负责创建 Chime meeting/attendee 并返回短期加入信息；
`flutter_aws_chime` 不创建 AWS meeting，也不持有 AWS 长期凭证。

## Chime v3 平台支持

| 平台 | 会议支持 | 最低版本 / 构建要求 |
| --- | --- | --- |
| iOS | 已支持 | iOS 15+ |
| Android | 已支持 | Android API 23+；Java 17；compile SDK 37 |
| macOS | 不支持 | v3 暂无会议实现 |
| Windows | 不支持 | v3 暂无会议实现 |
| Linux | 不支持 | v3 暂无会议实现 |
| Web | 不支持 | v3 暂无会议实现 |

本包要求 Flutter 3.47.0+、Dart 3.12.0+；Android 使用 AGP 9 Built-in Kotlin，JVM target 为 17；iOS 插件使用 Swift 5.0，同时支持 CocoaPods 与 Swift Package Manager。Flutter 3.47 本地 path 插件的 SwiftPM checkout 目录名限制见 [`DEVELOPMENT.md`](DEVELOPMENT.md)。桌面和 Web 未声明为插件支持平台；在这些平台调用会议 API 会抛出 `ChimeException`，错误码为 `ChimeErrorCode.unsupportedPlatform`。

## Chime v3 功能

- 加入和离开已由后端创建的 Chime SDK 会议。
- 麦克风静音/取消静音、本地摄像头开关、前后摄像头切换。
- 获取和选择音频输出设备。
- 接收 attendee 变化、远端视频画面和屏幕共享画面。
- 发送和接收 Chime 实时数据消息。
- 监听连接与重连、摄像头可用性、参会者音量/信号强度及视频 tile 事件。
- 独立使用 `ChimeMeetingSession`，或将会话传给可选的 `ChimeMeetingView`。

原生实现同一时间只允许一个活动 Chime 会话。移除 `ChimeMeetingView` 不会释放会议；创建会话的业务代码负责生命周期，必须调用 `leave()` 或 `dispose()`。

## Chime-only 安装

v3 发布后，在应用的 `pubspec.yaml` 添加：

```yaml
dependencies:
  flutter_aws_chime: ^3.0.0
```

本地开发时可使用指向本仓库的 path dependency。宿主应用需要满足上表中的 Flutter、Dart、Java、Android compile SDK 和 iOS 部署版本要求。

## 应用权限

### iOS

在宿主应用的 `ios/Runner/Info.plist` 添加用途说明。调用 `join()` 时，iOS 会请求麦克风和摄像头权限。

```xml
<key>NSMicrophoneUsageDescription</key>
<string>允许在 Chime 会议中使用麦克风。</string>
<key>NSCameraUsageDescription</key>
<string>允许在 Chime 会议中使用摄像头。</string>
```

### Android

插件 manifest 会声明互联网、摄像头、麦克风和音频设置权限。调用 `join()` 时会请求摄像头和麦克风运行时权限。请检查应用合并后的 manifest；如需说明权限用途，可在应用自己的界面中补充提示。

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

用户拒绝任一运行时权限时，`join()` 会以 `ChimeException` 失败，错误码为 `permissionDenied`。

## 后端职责与凭证

应用后端需要为已认证的用户创建会议和 attendee，然后通过经过身份验证的连接向应用返回 meeting、media placement、attendee ID、external user ID 和短期 `JoinToken`。AWS access key 和 secret key 必须保存在服务端；不要将它们写入 Flutter 应用或传给本包。

参见 [AWS Chime SDK 创建会议指南](https://docs.aws.amazon.com/chime-sdk/latest/dg/create-mtgs.html) 和 [demo-server README](https://github.com/lengsukq/flutter_multi_livestream_video/blob/main/demo-server/README.md) 中的响应格式。本包不会调用 `CreateMeeting` 或 `CreateAttendee`，也不会保存 AWS 凭证。

```json
{
  "meeting": {
    "MeetingId": "...",
    "ExternalMeetingId": "...",
    "MediaRegion": "us-east-1",
    "MediaPlacement": {
      "AudioHostUrl": "...",
      "AudioFallbackUrl": "...",
      "SignalingUrl": "...",
      "TurnControlUrl": "..."
    }
  },
  "attendee": {
    "AttendeeId": "...",
    "ExternalUserId": "...",
    "JoinToken": "..."
  }
}
```

## 快速接入

如果你的业务后端实现了 [`BACKEND_CONTRACT.md`](BACKEND_CONTRACT.md)，可以直接
使用高层 `ChimeClient`。SDK 会负责 HTTP 请求、`JoinInfo` 转换、心跳和 best-effort
离会通知。后端可以使用 Java、Python、Node.js、Go 或其他任意技术栈。

```dart
import 'package:flutter/material.dart';
import 'package:flutter_aws_chime/flutter_aws_chime.dart';

Future<void> openRoom(BuildContext context) async {
  final client = ChimeClient(
    backendUrl: 'https://api.example.com',
    // 可选业务鉴权 Token；这不是 AWS 凭证。
    tokenProvider: () async => 'your-app-token',
  );

  final room = await client.joinRoom(
    roomCode: '482913',
    nickname: 'Leo',
  );
  try {
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: ChimeMeetingView(
            session: room.session,
            title: '房间 ${room.roomCode}',
            onLeave: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  } finally {
    await room.dispose();
    client.dispose();
  }
}
```

创建并立即加入可使用 `ChimeClient.createRoomAndJoin(...)`。`ChimeRoomSession`
负责媒体会话期间的后端 presence 生命周期；heartbeat 失败会通过
`room.backendErrors` 暴露，但不会自动中断仍然健康的 Chime 音视频连接。

### 直接使用 `JoinInfo`

已经有自定义后端的项目可以完全跳过 `ChimeClient`，继续直接使用底层 API。
下面的 `response` 是后端创建 meeting 和 attendee 后返回的 JSON 对象。

```dart
import 'package:flutter/material.dart';
import 'package:flutter_aws_chime/flutter_aws_chime.dart';

Future<void> openMeeting(
  BuildContext context,
  Map<String, dynamic> response,
) async {
  final session = ChimeMeetingSession();
  try {
    await session.join(JoinInfo.fromJson(response));
    if (!context.mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: ChimeMeetingView(
            session: session,
            title: '团队会议',
            onLeave: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  } finally {
    // 创建会话的代码负责释放资源，包括发生错误时。
    await session.dispose();
  }
}
```

`join()` 会请求麦克风和摄像头权限，然后使用短期 meeting 和 attendee 信息连接。用户点击离开按钮时，view 会调用 `session.leave()`；组件从 widget tree 移除时不会调用 `dispose()`。

## 会话 API

包入口同时导出高层 `ChimeClient` / `ChimeRoomSession`，以及底层
`ChimeMeetingSession`、`JoinInfo`、会议模型、状态和事件类型、类型化后端/媒体错误、
音频设备类型、`MeetingVideoTileView` 和 `ChimeMeetingView`。

```dart
final session = ChimeMeetingSession();
final stateSubscription = session.states.listen((state) {
  debugPrint('会议状态：$state');
});
final eventSubscription = session.events.listen((event) {
  debugPrint('Chime 事件：$event');
});

await session.join(joinInfo);
debugPrint('当前状态：${session.state}');
await session.setMuted(true);
await session.setVideoEnabled(true);
await session.switchCamera(CameraPosition.back);

final devices = await session.listAudioDevices();
if (devices.isNotEmpty) await session.selectAudioDevice(devices.first);
await session.sendMessage('你好', topic: 'chat');

await session.leave();
await stateSubscription.cancel();
await eventSubscription.cancel();
await session.dispose();
```

`session.snapshot` 包含最新参会者、本地媒体状态、收到的屏幕共享 tile、消息和音频设备选择。`states` 和 `events` 是广播流；晚订阅时可通过 `session.state` 或 `session.snapshot` 读取当前值。会议结束后可以再次加入，但同一时间只能有一个活动会话。

`ChimeAudioDevice` 包含原生 Chime SDK 返回的 `label` 和基于标签推断的 `ChimeAudioDeviceType`（`bluetooth`、`wiredHeadset`、`speaker`、`earpiece` 或 `other`）。展示和选择时使用 `label`；不同设备和系统返回的标签可能不同。

## 错误与排查

所有异步操作失败都会以 `ChimeException` 暴露，包含稳定的 `code`、可读的 `message` 和可选原生 `details`。

| 错误码 | 含义 |
| --- | --- |
| `invalidJoinInfo` | 加入信息格式错误或缺少 AWS 必需字段。 |
| `invalidArgument` | 方法参数无效。 |
| `invalidState` | 当前会话状态不允许执行该操作。 |
| `meetingAlreadyActive` | 原生实现中已有另一个活动 Chime 会话。 |
| `permissionDenied` | 麦克风或摄像头权限被拒绝或受限。 |
| `unsupportedPlatform` | 在 iOS 和 Android 以外的平台调用会议 API。 |
| `sessionNotFound` | 原生会话已结束或不可用。 |
| `methodNotImplemented` | 宿主平台插件没有实现该方法。 |
| `nativeError`、`unknown` | 原生 SDK 或平台返回未分类错误。 |

常见检查：

- **权限错误：**检查 iOS 用途说明或 Android 合并后的 manifest，并在系统设置中允许应用使用权限。
- **加入信息无效：**检查后端返回完整的 `Meeting` 和 `Attendee` 对象，包括 `MediaPlacement` URL 和 attendee `JoinToken`。
- **没有音视频：**确认用户已允许麦克风/摄像头，并在加入前离开其他会议会话。
- **平台不支持：**v3 会议媒体仅支持 iOS 15+ 和 Android API 23+。
- **原生构建失败：**使用 Flutter 3.47+、Dart 3.12+、Java 17、Android compile SDK 37 和 iOS deployment target 15.0+。

## 从 v2 迁移到 v3

3.0.0 是破坏性 API 重设计。旧版 `MeetingModel`、`MeetingView` 和 platform-interface API 已移除；不提供 v2 兼容层。

| v2 | v3 |
| --- | --- |
| `MeetingModel()` | `ChimeMeetingSession()` |
| `meeting.joinMeeting(joinInfo)` | `session.join(joinInfo)` |
| `MeetingView(joinInfo)` | `ChimeMeetingView(session: session)` |
| 媒体控制返回布尔值 | `Future<void>`；失败时抛出 `ChimeException` |
| 音频设备字符串列表 | 包含 `label` 和 `type` 的 `List<ChimeAudioDevice>` |
| Widget 管理会议创建和清理 | 调用方管理 `join`、`leave`、`dispose`；用户点击离开时 view 请求离会 |

在负责通话的页面或 controller 中创建会话，订阅状态与事件，调用 `join()`，然后把 session 传给自定义 UI 或 `ChimeMeetingView`。所有者结束使用后调用 `dispose()`。

## 路线图

当前仓库已经包含可选的 Provider-neutral Core，以及 LiveKit / Agora / AWS Chime / 腾讯云 TRTC / 阿里云 ARTC
适配包。原有 `flutter_aws_chime` v3 API 保持不变，纯 Chime 应用无需迁移。

| # | 项目 | 状态 |
|---:|---|---|
| 1 | 升级 Flutter 和 AWS Chime SDK | Complete in 2.0.0 |
| 2 | 支持更多新版 Chime SDK API | Complete in 2.0.0 |
| 3 | 增加 Chime 以外的音视频通信后端 | LiveKit、Agora、TRTC、ARTC、IVS Real-Time 已通过可选 Adapter 实现 |
| 4 | 增加一对多直播 | LiveKit、Agora、TRTC、ARTC、IVS Real-Time host/viewer 已实现 |

当前多 Provider 使用方式见 [`MULTI_PROVIDER_GUIDE.md`](MULTI_PROVIDER_GUIDE.md)，
更完整的后续路线见 [`ROADMAP_IMPLEMENTATION_PLAN.md`](ROADMAP_IMPLEMENTATION_PLAN.md)。
