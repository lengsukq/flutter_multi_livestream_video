# Multi-provider Flutter media guide

Applications should normally depend on the full `flutter_realtime_sdk` package
and use `RealtimeSdk.standard()`. They call one API on every supported target;
the SDK owns driver registration, platform selection and lifecycle. Existing
apps may continue using `flutter_aws_chime` or the lower-level Core packages.

Backend-controlled routing is one supported strategy, not a requirement.
Frontend-first applications may construct `RealtimeSdk.standard()` without
`backendUrl`, obtain short-lived credentials from their own service, and call
`joinWithCredentials` / `connectChatWithCredentials` without importing a
provider adapter registry.

### Chat: attached or standalone

Chat Provider selection is independent from Media Provider selection. The same
`ChatSession` can be used as **Attached Chat** inside Meeting / Live or as a
**Standalone Chat** room with no Media session. Standalone flows support direct
`ChatJoinInfo`, custom `StandaloneChatProvisioner`, and the demo HTTP
provisioner. RTC Data remains a media data-channel/debug capability and is not
treated as Product Chat.

### Management capability model

Management is resolved as `Provider × Mode × Role × Capability`. Media and
Chat moderation remain separate contracts even when the high-level Realtime
SDK exposes both on one room. Each management capability carries an execution
mode: `client`, `backend`, `hybrid`, or `unsupported`, plus an optional
reason for UI help text. The demo server is only the reference control plane
for operations that require server authority.

Current enforced baseline:

- Meeting: logical owner member list and room close; provider-enforced kick
  where the media provider exposes it.
- Live: host member list, provider-enforced kick where available, and room
  close without treating broadcast viewers as meeting participants.
- Attached Chat: provider-native moderation such as IVS Chat delete/disconnect
  when the issued host token contains those capabilities.
- Standalone Chat: the same ChatSession UI/functions, plus authenticated member
  list and provider room close. Public join requests cannot self-promote to
  host.

`kick/remove` is not `ban`, and remote mute is not reported as supported
when a provider can only send an advisory message.

## Package layout

```text
flutter_realtime_media_core
  ├─ flutter_realtime_media_ui      -> ready-to-use provider-neutral UI
  ├─ flutter_realtime_media_livekit -> livekit_client
  ├─ flutter_realtime_media_agora   -> agora_rtc_engine
  ├─ flutter_realtime_media_trtc    -> tencent_rtc_sdk
  ├─ flutter_realtime_media_artc    -> AliVCSDK_ARTC (Android/iOS + conditional macOS)
  ├─ flutter_realtime_media_ivs     -> Amazon IVS Broadcast Stages
  └─ flutter_realtime_media_chime   -> flutter_aws_chime

flutter_realtime_media_aws_desktop
  └─ SDK-internal macOS WebKit transport -> Chime JS / IVS Web Broadcast

flutter_realtime_chat_core
  ├─ flutter_realtime_chat_ivs      -> Amazon IVS Chat Messaging (Android/iOS)
  ├─ flutter_realtime_chat_tencent  -> Tencent Cloud Chat (Android/iOS in reference demo)
  ├─ flutter_realtime_chat_agora    -> Agora Chat (Android/iOS)
  └─ flutter_realtime_chat_rtc      -> bidirectional RTC data -> ChatSession fallback
```

The same code runs on every supported Flutter target. The backend response (or
a direct `MediaJoinInfo` / `ChatJoinInfo`) still names the provider and
contains that provider's short-lived credential payload. Only the platform
implementation is hidden.

If your credential service returns raw JSON, application code does not need to
import provider-specific JoinInfo classes either:

```dart
final room = await sdk.joinWithCredentials(
  mediaProviderId: response.mediaProvider,
  mediaJoinPayload: response.mediaCredentials,
  chatProviderId: response.chatProvider,
  chatJoinPayload: response.chatCredentials,
);
```

`parseMediaCredentials` and `parseChatCredentials` are also available when
the application wants to inspect or stage credentials before connecting. The
provider-specific payload shape remains unchanged: Agora still receives its
app/channel/token fields, LiveKit its URL/token, TRTC its UserSig data, Chime
its meeting/attendee response, and so on. The SDK centralizes driver selection
and parsing rather than pretending all provider credentials have the same
schema.

Advanced applications can still override or extend the catalog:

```dart
final sdk = RealtimeSdk.standard(
  backendUrl: backendUrl,
  additionalPlugins: [myPrivateProviderPlugin],
);
```

Provider SDKs never become dependencies of Core.

On macOS, AWS is still consumed through the normal Chime/IVS adapters. The
`flutter_realtime_media_aws_desktop` plugin is a transport implementation
bundled by `flutter_realtime_sdk`; application code never imports it or
chooses it. ARTC takes a different path: its macOS bridge targets Alibaba's
official native Mac framework. This repository does not redistribute that
binary, so an SDK distribution must bundle the official framework for ARTC
macOS runtime support.

The recommended application entry point is
`flutter_realtime_sdk`. Use `RealtimeSdk.standard()` for the built-in
providers. The SDK owns the default provider/platform driver catalog, detects
the runtime target, and registers only the correct implementation. Business
code may still select a provider or receive one from the backend, but it never
chooses Web, Android, iOS, macOS, or Windows drivers.

`RealtimeProviderPlugin` remains the advanced extension point. It co-locates
provider metadata, media factory/renderer, and optional Product Chat factory,
so applications can override a built-in provider or add a private provider
without changing Core. `RealtimeClient`, `MediaClient`, and `ChatClient`
remain available as lower-level APIs.

The high-level SDK keeps an explicit platform matrix. If a provider is known
but has no driver for the current target, direct join fails with
`unsupportedPlatform`, backend-selected join resolves to the same typed
failure, and Pre-Join reports a blocking `unsupported` provider check.
Feature-level differences inside a supported driver continue to be exposed
through `MediaCapabilities` / `ChatCapabilities`.

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
final sdk = RealtimeSdk.standard(
  backendUrl: 'https://api.example.com',
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

The backend returns the actual provider with the join credentials. The
high-level SDK resolves the matching provider and current-platform driver
automatically. Business UI only needs room/user intent and never branches on
the runtime platform.

Applications that consume Core directly can still add only the adapter packages
they need. Core itself has no Tencent, Alibaba, AWS, Agora, or LiveKit
dependency. `flutter_realtime_sdk` intentionally acts as the batteries-included
bundle for applications that prefer one frontend SDK package. The reference
demo now uses that bundled path instead of maintaining its own native/Web
adapter registration.
Each application's backend remains the source of provider selection for every
room when backend-controlled routing is used. ARTC requires Alibaba Maven
repositories in Android dependency resolution and uses CocoaPods on iOS; its
7.11.0 iOS pod is device-only and does not support simulator linking.

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
