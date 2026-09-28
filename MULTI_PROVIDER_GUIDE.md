# Multi-provider Flutter media guide

Existing apps may continue using `flutter_aws_chime` directly. Apps that want
backend-controlled provider selection register the adapters they support and
use Core without choosing a provider per room.

Backend-controlled routing is one supported strategy, not a requirement.
Frontend-first applications may construct `RealtimeSdk` without
`backendUrl`, obtain `MediaJoinInfo` / `ChatJoinInfo` from their own
credential service, and use `joinDirect` / `ChatClient.connect`.

## Package layout

```text
flutter_realtime_media_core
  ├─ flutter_realtime_media_ui      -> ready-to-use provider-neutral UI
  ├─ flutter_realtime_media_livekit -> livekit_client
  ├─ flutter_realtime_media_agora   -> agora_rtc_engine
  ├─ flutter_realtime_media_trtc    -> tencent_rtc_sdk
  ├─ flutter_realtime_media_artc    -> native AliVCSDK_ARTC (Android/iOS)
  ├─ flutter_realtime_media_ivs     -> Amazon IVS Broadcast Stages (Android/iOS)
  └─ flutter_realtime_media_chime   -> flutter_aws_chime

flutter_realtime_chat_core
  ├─ flutter_realtime_chat_ivs      -> Amazon IVS Chat Messaging (Android/iOS)
  ├─ flutter_realtime_chat_tencent  -> Tencent Cloud Chat (Android/iOS in reference demo)
  ├─ flutter_realtime_chat_agora    -> Agora Chat (Android/iOS)
  └─ flutter_realtime_chat_rtc      -> bidirectional RTC data -> ChatSession fallback
```

Provider SDKs never become dependencies of Core.

The recommended application entry point is the separate
`flutter_realtime_sdk` orchestration package. `RealtimeProviderPlugin`
co-locates provider metadata, media factory/renderer, and optional Product Chat
factory. `RealtimeSdk` then combines those plugins with backend-authoritative
provider selection, Product Chat resolution, RTC Chat fallback, aggregated
room events/state, unified high-level errors, and room lifecycle. Core clients
remain available as lower-level APIs.

Core does not maintain a platform whitelist for registered adapters. If an app
registers an adapter, Core will attempt to use it on the current Flutter target
instead of rejecting the room up front. Provider/native SDKs remain responsible
for reporting genuinely unsupported targets, while feature-level differences
continue to be exposed through `MediaCapabilities`.

For optional functionality, application code should also stay provider-neutral:
query `MediaCapabilities` / `MediaFeature`, then use the shared device,
network-stat, advanced-data, recovery, or room-management APIs. The current
cross-provider matrix is documented in
[`SDK_CAPABILITY_MATRIX.md`](SDK_CAPABILITY_MATRIX.md). Unsupported optional behavior
returns a typed error rather than requiring `providerId` conditionals in the
business layer.

The reference backend also owns role assignment. New clients create either a
`meeting` or `broadcast` room and do not choose a role when joining:
`meeting` grants `participant` to everyone, while `broadcast` grants
`host` to the creator device and `viewer` to other devices.

## One Flutter API, multiple providers

```dart
final sdk = RealtimeSdk(
  backendUrl: 'https://api.example.com',
  plugins: [
    RealtimeProviderPlugin(
      id: 'agora',
      metadata: const RealtimeProviderMetadata(displayName: 'Agora'),
      mediaFactory: const AgoraSessionFactory(),
      renderer: const AgoraTrackRenderer(),
    ),
    RealtimeProviderPlugin(
      id: 'livekit',
      metadata: const RealtimeProviderMetadata(displayName: 'LiveKit'),
      mediaFactory: const LiveKitSessionFactory(),
      renderer: const LiveKitTrackRenderer(),
    ),
  ],
  tokenProvider: () async => applicationToken,
);

final room = await sdk.createRoom(
  user: const MediaIdentity(
    userId: 'account-123',
    displayName: 'Leo',
    deviceId: 'install-abc',
  ),
);

try {
  final page = RealtimeRoomView(room: room);
  room.events.listen((event) {
    // RealtimeMediaEvent / RealtimeChatEvent / RealtimeStateChanged /
    // RealtimeBackendFailure
  });
} finally {
  await room.dispose();
}
```

For normal applications, use `RealtimeSdk.preJoin` before create/join and
`RealtimeRoomView(room: room)` after it. Direct `MediaClient`,
`ChatClient`, and `MediaRoomView` usage is intentionally retained for
advanced diagnostics, custom orchestration, or fully custom UI.

Pre-Join is also backend-optional. With an explicit provider id it can run
local permission checks and adapter-native probes without any control plane.
Backend health and room-discovery checks are appended only when a Backend
Contract implementation is configured.

The backend can optionally attach `requiredCapabilities` to a join response.
These are product requirements, not provider selection hints. The SDK compares
them with the capabilities of the actually resolved media/chat sessions and
rejects unsupported combinations explicitly.

Media and product chat are separate provider axes. User-facing chat should
always be represented by `ChatSession`. `RealtimeSdk` resolves it with
this priority:

1. if `room.chatProvider` is non-null, attach that independent product Chat;
2. otherwise, if the media session has both `canSendData` and
   `canReceiveData`, create `RtcDataChatSession` as a session-local fallback;
3. otherwise, expose no Chat UI.

A backend-selected product Chat failure must not silently downgrade to RTC
fallback because that would change server-authoritative product semantics.
Advanced applications that intentionally use the lower-level clients can still
attach independent chat using the media participant identity:

```dart
final chatClient = ChatClient(
  backendUrl: 'https://api.example.com',
  registry: ChatRegistry([
    const IvsChatSessionFactory(),
    const TencentChatSessionFactory(),
    const AgoraChatSessionFactory(), // Android/iOS
  ]),
  tokenProvider: () async => applicationToken,
);

final chatRoom = await chatClient.connectRoom(
  roomCode: room.roomCode,
  participantId: room.participantId,
);
```

When `room.chatProvider == null`, the fallback is local composition only:

```dart
final rtcChat = RtcDataChatSession.tryAttach(room: room);
final ChatSession? chatSession = rtcChat;
```

The RTC adapter uses a dedicated versioned topic/envelope and maps incoming
media messages into provider-neutral `ChatMessage` objects containing sender
identity, display name, message, topic/type, timestamp, provider metadata, and
message ids for echo deduplication. Its in-memory history lasts only for the
current session. It does not add server-side history or moderation.

The chat-token request never sends a client-selected chat role. The backend
resolves the existing media participant and grants chat capabilities from the
stored role.

The reference adapters currently support `ivs-chat`, `tencent-chat`, and
`agora-chat`. Tencent maps an application room to a Tencent Chat Meeting group;
Agora maps it to an Agora ChatRoom. Both adapters keep long-lived signing
secrets on the backend and refresh short-lived client credentials through the
same `ChatCredentialProvider` path. Their first version exposes reliable text
send/receive but deliberately leaves moderator delete/kick unsupported until a
provider-neutral server-side moderation contract is added.

RTC Data Debug is intentionally separate from both product Chat and fallback
Chat. `MediaRoomViewConfig(showRtcDataMessages: true)` exposes the raw
`MediaDataMessenger` debug/control path without feeding those payloads into
`ChatSession`. Chat permissions never alter `canPublishAudio` or
`canPublishVideo`.

## Pre-Join before create/join

Applications that want an SDK-level readiness screen can call
`MediaClient.runPreJoinCheck()` before the normal create/join API:

```dart
final preJoin = await client.runPreJoinCheck(
  role: MediaRole.participant,
  providerId: knownProviderId, // optional
  roomCode: existingRoomCode,  // optional
  requirements: const MediaPreJoinRequirements(
    microphone: MediaPreJoinRequirement.required,
    camera: MediaPreJoinRequirement.recommended,
  ),
);

if (!preJoin.isReady) {
  // Show preJoin.blockingIssues and do not continue.
}
```

When joining a discovered room, supplying its `providerId` avoids an extra
provider-resolution lookup. If only `roomCode` is known, Core may use room
discovery to resolve the backend-assigned provider. The Flutter business layer
still does not select a vendor.

The result deliberately distinguishes `passed`, `failed`, `unsupported`,
and `unknown`. Required checks preserve blocking severity for all non-passing
states; recommended checks remain warnings. Provider adapters may implement the
optional `MediaPreJoinProbe`, but they must not create rooms or spend normal
join credentials just to simulate a connectivity test.

The backend `/health` route is only diagnostic. Backends that implement the
normal room contract but omit `GET /health` remain compatible. HTTP 404 means
the optional diagnostic is unavailable; transport/timeout failures mean the
backend cannot currently be reached; an implemented endpoint returning a real
error such as 5xx is a backend-health failure.

The default microphone/camera permission probe uses `permission_handler`.
See
[`packages/flutter_realtime_media_core/PRE_JOIN_SETUP.md`](packages/flutter_realtime_media_core/PRE_JOIN_SETUP.md)
for the required Android/iOS host settings.

The backend returns the actual provider with the join credentials. Core resolves
the matching adapter automatically. Business UI only needs room/user intent;
provider choice does not appear in create/join calls.

TRTC and ARTC are optional adapter packages. Applications that do not use them
do not add their packages or SDK dependencies; Core has no Tencent or Alibaba
dependency and no default provider. The reference demo registers both alongside
its other adapters, while each application's backend remains the source of
provider selection for every room. ARTC requires Alibaba Maven repositories in
Android dependency resolution and uses CocoaPods on iOS; its 7.11.0 iOS pod is
device-only and does not support simulator linking.

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

`example` exposes no provider selector. It registers the optional adapters once,
sends only the backend URL, room/user information and role, and
uses the provider returned by the backend to resolve the renderer/session.

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
