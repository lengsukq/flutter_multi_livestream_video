# Multi-provider Flutter media guide

Use the provider-neutral `Realtime` API from `flutter_realtime_sdk`, with
explicitly registered provider bundles. The lightweight facade depends on
Runtime; provider and UI packages are selected by the application. For the
combined single-package preview, read the release guide.

```dart
final realtime = Realtime(
  providers: myProviders,
  backendUrl: backendUrl,
);
final connection = await realtime.open(
  RealtimeRequest.join(
    type: RealtimeExperience.meeting,
    roomCode: roomCode,
    user: const RealtimeUser(id: 'account-123', name: 'Leo'),
  ),
);
final room = connection.mediaRoom!;
// Render RealtimeRoomView(room: room); dispose connection when the route ends.
```

Providers receive short-lived credentials from a trusted control plane.
`RealtimeSource.credentials(...)` also accepts application-provisioned
credentials; the reference Demo Server is optional. The backend selects the
provider for reference-server rooms; Flutter business UI sends room intent.

## UI and room mode

`RealtimeRoomView` is the standard complete-room entry and uses the same pages
shown in the Demo. `RealtimeRoomViewConfig` configures initial media settings,
chat/provider visibility, confirmation, backgrounds and a fallback mode.
Connected backend mode takes precedence over that hint. A logical meeting
owner is not automatically a livestream broadcaster.

Standalone product chat uses `RealtimeChatPage`. Preparation uses
`RealtimePreJoinPage` with `runCheck`, `openPreview`, `onEnter`, `roomLabel`
and `displayName`. Preview releases before connection; a failed connection
remains on the preparation page. Default camera/microphone are off.

Independent widgets are available from `flutter_realtime_room_ui`,
`flutter_realtime_media_ui` and `flutter_realtime_chat_ui`. Core/Runtime do not
import provider implementations or require UI. Historical alternative room,
chat and Pre-Join page templates and compatibility aliases have been removed.

## Independent media and product chat

Media and Product Chat are separate provider axes. `ChatSession` supplies the
same text/search/reply/governance components in standalone and attached chat.
RTC Data remains a transient media-channel capability; it is not product IM,
a durable command channel or an identity authority.
`RealtimeRoomViewConfig(showRtcDataMessages: true)` enables the meeting data
console without feeding those payloads into product chat.

Management depends on provider, mode, authenticated role and capability.
Client, backend, hybrid and unsupported execution modes remain distinct.
A hidden button does not authorize an operation; trusted backend/provider
checks are required. Advisory remote mute must not be presented as enforced
publication control. Register optional Classroom/Live presets explicitly.

## Pre-Join checks

`realtime.preJoin` reports passed, failed, unsupported or unknown checks.
Required failures block entry; recommended checks remain warnings. Adapter
probes must not create rooms or consume join credentials just for testing.
The reference `/health` endpoint is optional diagnostics: 404 means that
probe is unavailable, while transport failures/timeouts or real server errors
must remain visible.

Read [SDK integration](SDK_RUNTIME_INTEGRATION.zh-CN.md),
[UI acceptance](UI_COMPOSABILITY_ACCEPTANCE.zh-CN.md), and
[platform permission setup](../packages/flutter_realtime_media_core/PRE_JOIN_SETUP.md)
for current entry points and host requirements.

## Backend requirements

The backend language is not prescribed. Java Spring Boot, Python FastAPI,
Node.js, Go, .NET, Lambda, or another server only needs to implement:

```text
POST   /rooms
POST   /rooms/{roomCode}/join
POST   /rooms/{roomCode}/heartbeat
POST   /rooms/{roomCode}/leave
DELETE /rooms/{roomCode}
POST   /rooms/{roomCode}/credentials/refresh  (optional)
POST   /rooms/{roomCode}/chat/token            (when chat is enabled)
```

Long-lived provider credentials remain on that server. Flutter receives only
short-lived join credentials.

## Local backend modes

For Chime-only testing, the normal backend command is enough:

```bash
cd demo-server
npm start
```

For local LiveKit + Chime testing:

```bash
bash scripts/livekit-dev.sh start
eval "$(bash scripts/livekit-dev.sh env)"
cd demo-server
npm start
```

To enable Agora in the same server, also set `AGORA_APP_ID` and
`AGORA_APP_CERTIFICATE` (normally in the ignored `demo-server/.env`).

The public URL is `http://127.0.0.1:3000`. Open the existing dashboard and
switch the **Media Provider** for new rooms between LiveKit, Agora, AWS,
Tencent TRTC, and Alibaba ARTC. AWS is vendor-level routing: **Meeting uses
Amazon Chime SDK**, while **Live uses Amazon IVS Real-Time**. The **Chat Provider** is
selected independently; the reference backend supports Amazon IVS Chat or no
product chat. Existing rooms keep both provider bindings assigned at creation.

The public backend response uses `provider: "aws"` for AWS rooms and includes
`engine: "chime" | "ivs"` for adapter resolution and diagnostics. Legacy
`provider=chime` / `provider=ivs` selections remain accepted and normalize to
AWS. Concrete Chime and IVS packages stay independent internally.
For the local persisted dashboard state, an explicit Chat selection of
`none` is a real value and takes precedence over `CHAT_DEFAULT_PROVIDER`
after restart; the environment default is used only when no persisted Chat
selection exists. On Vercel, the dashboard can change Chat at runtime, but
serverless instances do not share or persist that selection; cold starts fall
back to `CHAT_DEFAULT_PROVIDER` (or `none` when unset).
TRTC signing requires `TRTC_SDK_APP_ID` and
`TRTC_SDK_SECRET_KEY` on the server; enable Advanced Permission Control in the
Tencent RTC project. The Flutter package receives short-lived UserSig and room
PrivateMapKey values only.

Amazon IVS Real-Time uses the server IAM credential chain and
`IVS_REALTIME_REGION` (or the configured AWS region). Amazon IVS Chat resolves
its region from the optional `IVS_CHAT_REGION` override, `AWS_REGION`,
`AWS_DEFAULT_REGION`, or the active AWS profile configuration. It uses the same
server-side IAM model. Flutter receives only short-lived Stage/Chat tokens.

The LiveKit server itself is managed by `bash scripts/livekit-dev.sh` and can remain
running between tests.

## Unified demo

`example` exposes no provider selector or adapter registry. It calls the public
`flutter_realtime_sdk` facade with the backend URL, room/user information and
role; the SDK uses the provider returned by the backend to resolve the driver,
renderer and session.

Agora uses numeric UIDs so `participantId` is the decimal UID string. The
Agora adapter supports participant/host RTC media, viewer subscribe-only
media, RTC data messages for participant/host, and provider-neutral video
rendering on Android, iOS, and macOS. Front/back camera switching is available
on Android/iOS; macOS uses the current desktop camera. Screen sharing stays
deferred. Viewer data sending is currently
disabled rather than implicitly promoting an Agora audience client to host.

The TRTC adapter maps `participant` to the video-call scene and `host`/`viewer`
to the live-streaming scene. The backend locks each room to the scene selected
when it is created. Viewers use the Core subscribe-only interface and receive a
PrivateMapKey without media-publish privileges. Participant/host custom messages
are supported; viewer messaging, screen share, and audio-device enumeration are
not part of this adapter's first release.

The ARTC adapter maps `participant` to communication mode and `host`/`viewer`
to interactive live mode. The backend locks each room to its creation mode.
ARTC's viewer role is selected by the client SDK; its token authenticates the
application, channel, user, and expiry but does not enforce viewer publishing
rights server-side. The Core viewer surface exposes no publish methods, but
applications must not treat this as protection against a modified client.
Viewer custom messages are receive-only; screen share and audio-device
enumeration are not advertised by the first release.

```bash
cd example
flutter run --dart-define=MEDIA_BACKEND_URL=http://192.168.31.8:3000
```

For local application auth, `MEDIA_APP_TOKEN` may also be supplied as a Dart
define. Production applications should normally obtain app auth at runtime.

## Adding another provider

1. Create a separate adapter package depending on Core and the provider SDK.
2. Implement `MediaSessionFactory` and parse your provider response block.
3. Implement the narrowest session interface matching real capabilities.
4. Translate provider state/events/errors into Core models.
5. Add a `MediaTrackRenderer` when video is supported.
6. Add offline contract tests and an optional E2E path.
7. Add the provider to backend routing/admin configuration without changing
   business UI.

Do not claim a role or capability until both the client surface and backend
credential grants enforce it.

## Explicit lightweight composition

Applications may keep `Realtime.standard()` or choose `Realtime` from
`flutter_realtime_sdk_runtime` with optional provider bundles. Driver registration
and platform selection stay inside each bundle; Web resources are local to the
selected package. Custom adapters can expose `RealtimeProviderBundle` without
depending on the all-provider SDK. See the lightweight integration guide and
unified acceptance checklist in `doc/` (or the current documentation directory).

轻量接入保留统一请求、事件和房间类型；平台路由在注册包内部完成。
产品聊天缓存可配置，跨供应商服务端历史分页与真实连麦另行推进。
