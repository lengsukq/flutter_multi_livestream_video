# SDK Capability Matrix

**English** | [简体中文](SDK_CAPABILITY_MATRIX.zh-CN.md)

The application should branch on `MediaCapabilities` / `MediaFeature`, not
on `providerId`. A provider may expose a smaller capability set on a specific
platform or role.

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
| Device enumeration/selection | Yes, platform dependent | Audio output | Not exposed by adapter | Not exposed by adapter | Not exposed by adapter | Mic/camera probe; camera switch |
| Pre-Join native device probe | Mic/camera | No native probe | No native probe | No native probe | No native probe | Mic/camera |
| Pre-Join provider network probe | Unsupported without issued credentials | No native probe | No native probe | No native probe | No native probe | Unsupported without participant token |
| Network stats | Yes | Not exposed by adapter | Yes | Yes | Not exposed by adapter | Basic RTC stats |
| Screen share | Yes for publishers | Not exposed by adapter | Deferred | Not exposed by adapter | Not exposed by adapter | Not exposed by adapter |
| Host participant list | Backend + logical owner | Meeting creator via logical owner credential | Backend + logical owner | Backend + logical owner | Backend + logical owner | Backend + logical owner |
| Host remove participant | LiveKit host | No | No | No | No | IVS DisconnectParticipant |
| Host close room | Host via backend | Meeting creator via control plane | Host via backend | Host via backend | Host via backend | Host via backend |

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
