# SDK Capability Matrix

The application should branch on `MediaCapabilities` / `MediaFeature`, not
on `providerId`. A provider may expose a smaller capability set on a specific
platform or role.

| Capability | LiveKit | Chime | Agora | TRTC | ARTC |
| --- | --- | --- | --- | --- | --- |
| Meeting audio/video | Yes | Yes | Yes | Yes | Yes |
| Broadcast host/viewer | Yes | No (participant only) | Yes | Yes | Yes |
| Data message | Yes | Yes | Host/participant | Host/participant | Host/participant |
| SDK message-size limit | 15 KiB | 2 KiB | 1 KiB | 1 KiB | 1 KiB |
| Targeted data | Yes | No | No | No | No |
| Unreliable data | Yes | No | No | No | No |
| Device enumeration/selection | Yes, platform dependent | Audio output | Not exposed by adapter | Not exposed by adapter | Not exposed by adapter |
| Pre-Join native device probe | Mic/camera | No native probe | No native probe | No native probe | No native probe |
| Pre-Join provider network probe | Unsupported without issued credentials | No native probe | No native probe | No native probe | No native probe |
| Network stats | Yes | Not exposed by adapter | Yes | Yes | Not exposed by adapter |
| Screen share | Yes for publishers | Not exposed by adapter | Deferred | Not exposed by adapter | Not exposed by adapter |
| Host participant list | Backend + host role | Not available (no host role) | Backend + host role | Backend + host role | Backend + host role |
| Host remove participant | LiveKit host | No | No | No | No |
| Host close room | Host via backend | Not available (no host role) | Host via backend | Host via backend | Host via backend |

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
