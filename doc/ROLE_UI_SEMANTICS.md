# Role-aware UI semantics (Meeting / Live / Chat)

The Flutter Realtime SDK uses **different role contracts** for media publication,
room moderation, classroom administration and product Chat. An application's
create/join button is not a privilege grant.

| Connected experience | Server-issued role / authority | UI wording (zh-CN) | Controls |
| --- | --- | --- | --- |
| Meeting creator with room owner credential | `MediaRole.participant` + `MediaRoomSession.isLogicalOwner` | 会议主持人 | Can manage only actions enabled by the trusted backend |
| Meeting guest | `MediaRole.participant`, no room owner authority | 会议参会者 | Ordinary media/raise-hand/chat; no owner-only actions |
| Live creator | `MediaRole.host` | 主播 | Publisher and host tools where provider capabilities allow |
| Live guest | `MediaRole.viewer` | 观众 | Watching, chat/likes/gifts if enabled; no camera/mic publishing |
| Unexpected `participant` in a Live page | `MediaRole.participant` | 直播参与者 | **Never** classified as broadcaster merely for being a non-viewer |
| Standalone Chat creator | Authenticated `ChatRole.host` | 聊天室房主 | Chat management only where supported |
| Standalone Chat joiner | Authenticated `ChatRole.participant` | 聊天室成员 | Chat, no host-only management |
| Chat viewer | Authenticated `ChatRole.viewer` | 聊天室观众 | Provider-permitted reading/actions |

## Authority and ownership

- For the **post-join room UI**, use the backend's `roomMode` metadata as the
  source of truth. If it is unavailable, use the SDK's connected role as a
  conservative fallback. A stale pre-join choice of Live must not turn a
  Meeting participant into a Live broadcaster.
- In Meeting, RTC `participant` means *symmetric media participation*, not
  *no meeting administration*. The creator may also hold a separate
  `roomOwnerCredential`. Check `media.isLogicalOwner` **and** the specific
  management capability, rather than assuming only `MediaRole.host` can
  manage meetings or that any `participant` can.
- Live's `MediaRole.host` is not the same as Chat's `ChatRole.host`. UI
  must require the actual corresponding session role; `role != viewer` is
  insufficient. Legacy host panels should also block standalone mounting by
  guests; simply hiding the top-level entry is not enough.
- For independent Chat, use `ChatSession.role` returned by the connected
  provider (based on trusted provisioned credentials), not the user-provided
  `join` request. The Demo Server never allows a public Chat join to
  self-promote to host. The Chat UI controller owns all management gating.
  If the remote join response omits a valid role, `HttpStandaloneChatProvisioner`
  treats the caller as a `participant`, **not** as its caller-requested `host`.
- The HTTP Media join contract behaves similarly: a public join that asks for
  `MediaRole.host` but receives no assigned role from the server is treated as
  an unprivileged `participant`. Create and credential-refresh flows retain
  their separate existing role contracts. Backend capabilities and provider
  tokens remain the real authorization boundary.
- Display roles for **remote** video users only when a trusted source supplies
  their authoritative role. `MediaParticipant` alone has display name,
  camera/microphone status and local identity, **not** a guaranteed remote
  host role. Do not label the first user with a video track as a verified host.
- A status tooltip/semantic label can replace long badges in tight 320px
  Meeting headers. The text roles in the independent Chat header remain
  visible and localized. UI semantics are an accessibility and usability
  feature, **not an authorization boundary**.

## Validation

Offline tests cover Meeting logical-owner/guest labels, 320px text scaling,
desktop Meeting sidebars, Live host/viewer/non-host participant gating, Chat
creator/guest management affordances, and backend mode winning over a stale
pre-join hint. These tests cannot prove all vendor adapters issue and refresh
the intended roles on physical devices. Before pub.dev release, test both
devices concurrently (create, join, reconnect, rejoin as owner/guest, leave)
on the selected vendors and confirm server authorization independently.

See [SDK integration](SDK_RUNTIME_INTEGRATION.zh-CN.md),
[provider capabilities](SDK_CAPABILITY_MATRIX.zh-CN.md) and
[UI composition](UI_COMPOSABILITY_ACCEPTANCE.zh-CN.md).
