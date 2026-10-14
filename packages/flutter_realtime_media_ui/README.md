# flutter_realtime_media_ui

Provider-neutral meeting/live Flutter widgets built on Media and Chat Core
contracts. The repository Demo uses this same UI; applications can either use
the composed `RealtimeRoomView` from `flutter_realtime_sdk_ui` or integrate
`MediaRoomView` directly.

## Room UI and mode selection

```dart
MediaRoomView(
  room: mediaRoomSession,
  renderer: mediaTrackRenderer,
  chatSession: productChatSession, // optional; null hides product Chat
  config: const MediaRoomViewConfig(
    roomMode: MediaRoomMode.meeting,
    confirmBeforeLeave: true,
  ),
);
```

`room` is a `MediaRoomSession` and `renderer` is its matching
`MediaTrackRenderer`. When using the full SDK, prefer
`RealtimeRoomView(room: connection.mediaRoom!)` to get the composed
Media/Classroom/Live UI and background preparation without manually wiring
these low-level dependencies.

**Always pass explicit room mode when known.** A meeting creator may be a
logical room owner and still have the provider media role `participant`;
`MediaRole.host` does not by itself mean livestream. With no configured
`roomMode`, the UI recognizes viewer as a broadcast attendee and otherwise
defaults to meeting. Broadcast hosts should therefore set
`MediaRoomMode.broadcast`. Backend-supplied mode and role must remain
separate, and owner-management authorization belongs to the server/provider.

The Meeting and Live layouts are independent widgets behind the typed
`MediaRoomLayoutHost` interface. One media stage owns the video tracks;
chat/unread/room members/live reactions update their respective presentation
regions instead of rebuilding those tracks. Meeting management controls depend
on `managementCapabilities`, and product Chat controls require a real
`ChatSession`. RTC Data is not a substitute for a full IM implementation.
Likes and other live interactions must have a real SDK-backed controller;
unsupported actions should not be presented as functional.

## Pre-Join (before calling Realtime.open)

`MediaPreJoinPage.show` is the public entry point. Supply `runCheck` and
`openPreview` from the provider-neutral SDK facade, then use optional
`onEnter` to open the room. Checks distinguish blocking failures from warnings
and unsupported/unknown probes; the UI never invents native network-probe
support. A failed connection must leave the page available for retry.

```dart
await MediaPreJoinPage.show(
  context,
  runCheck: () => realtime.preJoin(
    role: MediaRole.participant,
    roomCode: roomCode,
  ),
  openPreview: (providerId, role) =>
      realtime.createLocalPreview(providerId: providerId, role: role),
  onEnter: (preJoinContext, settings) async {
    // Open via RealtimeRequest.join/create, navigate with preJoinContext,
    // and pass settings as MediaRoomViewConfig.initialMediaSettings.
    // Dispose a connection if route handoff fails.
  },
);
```

The page owns local preview resources until release. Internal
`PreJoinPreviewOwner` prevents duplicate release; the permission coordinator
maps checked OS permissions; the media setup controller tracks devices,
background selection and stale async device results. The application owns the
connected `RealtimeConnection` after successful entry and must dispose it
when its room route closes. Avoid double ownership and late async navigation.
Selected video effects must be applied before publish; protected effects must
not silently downgrade to sending raw camera frames.

## Validation and limitations

The 2026-10-09 P1 scoped regression recorded 50 passing media UI room,
Pre-Join and live-interaction tests and a clean `flutter analyze`. That is
offline Widget/Controller evidence, not a claim of successful multi-device
provider E2E, every native platform or remote processed-video pixels.

See [the P1 architecture and integration guide](../../doc/P1_ARCHITECTURE_AND_INTEGRATION.zh-CN.md),
[Core Pre-Join setup](../flutter_realtime_media_core/PRE_JOIN_SETUP.md),
and [capability matrix](../../doc/SDK_CAPABILITY_MATRIX.zh-CN.md).
