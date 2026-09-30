# SDK Capability Matrix

**English** | [简体中文](SDK_CAPABILITY_MATRIX.zh-CN.md)

The application should branch on `MediaCapabilities` / `MediaFeature`, not
on `providerId`. A provider may expose a smaller capability set on a specific
platform or role.

## Built-in platform drivers

`RealtimeSdk.standard()` owns this routing table. Application code uses the
same API on every target; the SDK resolves the provider implementation for the
current runtime platform. A dash means the provider is known but the built-in
SDK deliberately returns `unsupportedPlatform` on that target.

| Public Media provider | Android | iOS | macOS | Windows | Web |
| --- | --- | --- | --- | --- | --- |
| LiveKit | Yes | Yes | Yes | Yes | Yes |
| Agora RTC | Yes | Yes | Yes | Yes | Yes |
| Tencent TRTC | Yes | Yes | Yes | Yes | Yes |
| Alibaba ARTC | Yes | Yes | Conditional* | — | Yes |
| AWS | Yes | Yes | Yes** | — | Yes |

| Product Chat provider | Android | iOS | macOS | Windows | Web |
| --- | --- | --- | --- | --- | --- |
| Agora Chat | Yes | Yes | Yes | — | Yes |
| Tencent Cloud Chat | Yes | Yes | Yes | Yes | Yes |
| Amazon IVS Chat | Yes | Yes | Yes | — | Yes |

Linux is not registered in the default catalog yet. Advanced applications can
add or override drivers with `RealtimeProviderPlugin` without modifying Core.

## Host application requirements

The all-provider SDK Demo currently targets Android API 28+ (compile SDK 37),
iOS 15+, macOS 12+, Windows 10+, and standard Flutter Web in a secure browser
context. Use Flutter 3.47+, Dart 3.12+, and Java 17 for the Android build.
Individual low-level adapter packages may support lower Android versions when
used without the full SDK bundle.

Android plugin manifests contribute the required runtime permissions. Host
iOS/macOS apps must include camera and microphone usage descriptions; macOS
apps also need camera/microphone entitlements. The example contains these
settings. Browsers request device access from the user, and Web deployments
must use HTTPS or localhost. Pre-Join and connection failures report denied
permissions through the SDK's typed diagnostics.

ARTC's iOS binary supports device builds but does not link into the iOS
Simulator. CI therefore targets an iOS device build without codesigning.
`Conditional*` means the ARTC macOS bridge is implemented and build-verified,
but the repository does not redistribute Alibaba's official Mac framework.
Without that framework the adapter fails explicitly with `unsupportedPlatform`.

The Web entries currently refer to the standard JavaScript Flutter Web target.
`flutter build web` is verified, but the current Tencent Cloud Chat dependency
still uses `dart:html`, `dart:js`, and FFI-backed code paths, so Flutter's
Wasm dry-run reports incompatibilities. Do not advertise the bundled Web stack
as Wasm-ready until those upstream dependencies migrate.

The macOS build is verified with CocoaPods. `Yes**` for AWS means the
batteries-included SDK uses one internal WebKit runtime: Meeting loads the
pinned Chime JS SDK and Live loads the pinned IVS Web Broadcast SDK. The same
public `aws` provider and the same Dart session APIs are used; applications do
not create a WebView or add JavaScript assets. Flutter currently warns that
several plugins do not yet provide macOS Swift Package Manager support; this is
a packaging limitation rather than a driver-routing failure.

Amazon IVS Chat is also available on macOS through the same hidden WebKit
runtime, using the locally bundled Chat JavaScript bridge. The chat bridge is
loaded only when an IVS Chat session is first opened.

The current verification host is macOS: Android debug APK, iOS device Release
without codesigning, macOS Release, and JavaScript Web builds are verified.
Windows entries above are registered by the default catalog and covered by
platform-selection tests. CI is configured to build the Windows example on a
Windows runner; a macOS development host cannot produce a native Windows build
result locally.

The SDK package owns its Web bridge and pinned vendor JavaScript assets. The
facade loads them on the first media or Product Chat connection; applications
do not add script tags, CDN links, or a separate npm build step. Missing or
unreachable bundled assets produce `webSdkUnavailable`.

AWS is presented as one public vendor. Its concrete engine is mode-dependent:
`Meeting -> Chime`, `Live -> IVS Real-Time`. The Chime/IVS columns below describe
the internal engine capabilities used by that AWS routing.

| Capability | LiveKit | Chime | Agora | TRTC | ARTC | IVS Real-Time |
| --- | --- | --- | --- | --- | --- | --- |
| Meeting audio/video | Yes | Yes | Yes | Yes | Yes | Yes |
| Broadcast host/viewer | Yes | No (participant only) | Yes | Yes | Yes | Yes |
| RTC data send | Yes | Yes | Host/participant | Host/participant | Host/participant | No |
| RTC data receive | Yes | Yes | Yes | Yes | Yes | No |
| RTC Chat fallback | Yes when role can send | Yes | Host/participant | Host/participant | Host/participant | No |
| SDK message-size limit | 15 KiB | 2 KiB | 1 KiB | 1 KiB | 1 KiB | — |
| Targeted data | Yes | No | No | No | No | No |
| Unreliable data | Yes | No | No | No | No | No |
| Device enumeration/selection | Yes, platform dependent | Audio output | Not exposed by adapter | Not exposed by adapter | Not exposed by adapter | Mic/camera probe; camera switch on Android/iOS |
| Pre-Join native device probe | Mic/camera | No native probe | No native probe | No native probe | No native probe | Mic/camera |
| Pre-Join provider network probe | Unsupported without issued credentials | No native probe | No native probe | No native probe | No native probe | Unsupported without participant token |
| Network stats | Yes | Not exposed by adapter | Yes | Yes | Not exposed by adapter | Basic RTC stats |
| Screen share | Yes for publishers | Not exposed by adapter | Deferred | Not exposed by adapter | Not exposed by adapter | Not exposed by adapter |
| Processed-video sink for blur | Not exposed by adapter | Not exposed by adapter | Web host + participant | Not exposed by adapter | Not exposed by adapter | Not exposed by adapter |
| Host participant list | Backend + logical owner | Meeting creator via logical owner credential | Backend + logical owner | Backend + logical owner | Backend + logical owner | Backend + logical owner |
| Host remove participant | LiveKit host | No | No | No | No | IVS DisconnectParticipant |
| Host close room | Host via backend | Meeting creator via control plane | Host via backend | Host via backend | Host via backend | Host via backend |

Virtual background has two separate capability layers:

| Effects platform bridge | Android | macOS | Web | iOS | Windows |
| --- | --- | --- | --- | --- | --- |
| Capture + None/Blur processing | Yes | Yes | Yes | Planned | Planned |
| Realtime local preview | Flutter Texture | Flutter Texture | HTML video | Planned | Planned |
| Processed source type | Native RGBA Frame Hub | Native `CVPixelBuffer` Frame Hub | `MediaStreamTrack` | Planned | Planned |

`flutter_realtime_video_effects` owns the first layer. Provider adapters own
only the second layer, `ProcessedVideoSink`. Agora Web currently implements
that sink. Native provider sinks remain explicitly unsupported until they can
consume the native Frame Hub directly; frames are never routed through
Dart/MethodChannel simply to claim compatibility.

The Demo's Pre-Join flow uses the platform effects bridge for live blur preview
without entering a provider room. Before initial camera publication,
`RealtimeRoomView` prepares a new processed source and attaches it to the
active provider sink. If no compatible sink exists, camera publication stays
off.

## Product chat

Product chat is not inferred from the media provider or `MediaCapabilities`.
It uses `ChatSession` / `ChatCapabilities` from
`flutter_realtime_chat_core`.

| Capability | Amazon IVS Chat | Tencent Cloud Chat | Agora Chat | RTC Data fallback |
| --- | --- | --- | --- | --- |
| Send message | Yes | Yes | Yes | When media has bidirectional data |
| Receive live message | Yes | Yes | Yes | Yes |
| Delete message | Host/moderator token: client | Demo member credentials do not expose it; custom owner/admin credentials may | Demo member credentials do not expose it; custom owner/admin credentials may | No |
| Disconnect user | Host/moderator token: client | Demo uses reference control-plane REST; owner/admin credentials may declare client | Demo uses reference control-plane REST; owner/admin credentials may declare client | No |
| Member list | Demo logical directory | Demo logical directory | Demo logical directory | No management directory |
| Management execution | Client-first, backend when required | Demo: backend; owner/admin credentials may be client | Demo: backend; owner/admin credentials may be client | Unsupported |
| Automatic credential refresh | Yes | UserSig refresh | Token refresh | Follows MediaSession |
| Server history | Service capability; no Core v1 pagination API | Service capability; no Core v1 pagination API | Service capability; no Core v1 pagination API | Current-session memory only |
| Provider-independent from media | Yes | Yes | Yes | No |

The built-in UI always consumes `ChatSession` for user-facing chat. If the
backend binds a product-chat provider, that session is authoritative. If no
product Chat Provider is bound, `flutter_realtime_chat_rtc` can create a
session-local fallback only when the media session supports both RTC data send
and receive. Product-chat connection failures do not auto-fallback.

Raw RTC data remains a media transport feature and a separate Debug/control
surface. `showRtcDataMessages` does not inject raw payloads into Chat. The RTC
fallback keeps only current-session history and provides no server-side history
or moderation. Chat capability is independent from audio/video publish rights.

Privileged operations use typed `ChatManagementExecution` values:
`client`, `backend`, `hybrid`, or `unsupported`. The high-level
`RealtimeChatModeration` prefers enforceable provider-client operations and
only falls back to an optional control plane when the vendor security model
requires a server-side admin API. Applications therefore do not branch on
provider ids and never need long-lived provider secrets in the Flutter app.

## Provider-neutral APIs

### Pre-Join

`MediaClient.runPreJoinCheck()` provides a provider-neutral readiness result
before room creation/join. Core checks backend reachability, target provider
registration, permission state, device availability when available, and basic
network reachability. Adapters may add checks through `MediaPreJoinProbe`.

Pre-Join result semantics are intentionally stricter than feature discovery:

- `required` + `failed` / `unsupported` / `unknown` is blocking.
- `recommended` non-passing results are warnings.
- `skipped` produces no check.
- An adapter must never report `passed` for a diagnostic it did not actually
  perform.
- Provider-native network checks that require issued join credentials should
  return `unsupported`; Pre-Join must not create a room just for diagnosis.

Backend `GET /health` is optional diagnostics and is not required for Backend
Contract compatibility. A missing endpoint can produce a warning while the
basic HTTP path remains reachable. Transport/timeout errors are network
failures; explicit errors from an implemented health endpoint remain backend
failures.

Room discovery is available through `MediaClient.listRooms()`. It returns
`MediaRoomSummary` only; discovery never exposes user/device identity,
participant ids, or provider credentials.

Sessions can use `listMediaDevices()` / `selectMediaDevice()` when the
corresponding capability is declared. Convenience helpers
`listMicrophones()`, `listCameras()`, `listAudioOutputs()`,
`selectMicrophone()`, `selectCamera()`, and `selectAudioOutput()` keep common
application code provider-neutral. Unsupported operations fail with
`MediaErrorCode.unsupportedFeature`.

Providers that expose RTC metrics implement `MediaStatsProvider`. Consumers
read `session.connectionStats` for the latest sample or listen to
`session.stats`. Metrics are optional by design: adapters do not fabricate
values that the provider does not expose.

`session.sendData(...)` is the advanced message entry point. The legacy
`sendMessage(...)` remains compatible. `MediaSendOptions` describes topic,
target participants, reliability, and ordering; Core validates requested
semantics and message-size limits against `MediaCapabilities` before dispatch.
Incoming provider data is exposed uniformly through `session.dataMessages`;
`canReceiveData` is declared separately from `canSendData` so callers can
distinguish send-only roles from full bidirectional transports.

`MediaRoomSession.recoveries` normalizes reconnecting, recovered, and failed
transitions without changing the logical participant identity. Provider
credential refresh remains responsible for preserving provider, room, role,
and participant identity.

Host management is backend-authoritative. `MediaRoomSession.listParticipants`,
`removeParticipant`, and `closeRoom` send the current participant id to the
backend, which verifies the stored host role. A local `MediaRole.host` value
alone never grants moderation permission.

## Adding another provider

Declare only capabilities that the adapter actually implements. New provider
features should be mapped to the provider-neutral models first; provider-only
escape hatches may still be exposed by the adapter package for advanced use.
Unsupported operations must return typed errors rather than silently succeed.

For Pre-Join, implement `MediaPreJoinProbe` only when the adapter can perform a
real diagnostic without joining a room. Return explicit `unsupported` or
`unknown` checks for unavailable diagnostics and preserve the requirement
severity supplied by Core.
