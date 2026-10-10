# Composable Realtime UI (incremental P0 API)

The SDK **owns the room session and actions**; the host app **owns every
Scaffold, route, breakpoint, panel and overlay**. Components use one
`RealtimeRoomUiController` through `RealtimeRoomUiScope` and never import
a provider implementation.

```dart
RealtimeRoomUiScope(
  room: room,
  child: Scaffold(
    body: Column(
      children: [
        Row(children: [
          const RealtimeRoomInfo(),
          const Spacer(),
          RealtimeLeaveButton(onConfirm: confirmLeave, onLeft: navigateHome),
        ]),
        const Expanded(child: RealtimeVideoGrid()),
        const Row(children: [
          RealtimeMicrophoneButton(),
          RealtimeCameraButton(),
          RealtimeScreenShareButton(),
        ]),
      ],
    ),
  ),
)
```

The standalone building blocks currently include `RealtimeVideoTile`,
`RealtimeVideoGrid`, `RealtimeScreenShareStage`, `RealtimeRoomInfo`,
`RealtimeConnectionIndicator`, media action buttons, `RealtimeParticipantList`,
`RealtimeChatMessageList`, `RealtimeChatComposer`, `RealtimeChatPanel`,
`RealtimeClassroomButton`, `RealtimeSharedContentButton`, and
`RealtimeSharedContentStage`. List and composer may live in different regions.
Classroom widgets are independently positionable within `RealtimeRoomUiScope`:
`RealtimeRaiseHandButton`, `RealtimeClassroomHandQueue`,
`RealtimeClassroomRoster`, `RealtimeClassroomQuestions`,
`RealtimeClassroomQuestionComposer`, `RealtimeClassroomFeedbackButton`,
`RealtimeClassroomActivityList` (quizzes and polls),
`RealtimeClassroomEngagement` and `RealtimeClassroomToolsButton`.
All classroom operations use `RealtimeRoomUiController` and one shared
ClassroomSession state subscription; the Demo chooses the toolbar, tab, drawer
or overlay where each control appears. Permissions and authoritative classroom
state remain in the SDK/control plane.
Media actions also include `RealtimeSwitchCameraButton` and
`RealtimeAudioOutputButton`. Camera selection alternates front/back from the
controller's initial front-facing setting; a host app with a rear-facing
initial camera can construct `RealtimeRoomUiController(room,
initialCameraPosition: MediaCameraPosition.back)` and supply it to the scope.
Audio output enumeration is separate from selection: devices remain visible,
but read-only, if `canSelectAudioOutput` is false.
Live uses `RealtimeLiveVideoStage` (only the broadcaster), `RealtimeLiveLikeButton`,
`RealtimeLiveGiftButton`, `RealtimeLiveGiftBanner`, `RealtimeLiveChatFeed`,
`RealtimeLiveHeartsOverlay` and `RealtimeLiveStatus`. Compose them in a
host-owned `Stack` or toolbar rather than relying on a fixed overlay layout.

The controller updates with session snapshots and chat messages. Multiple
buttons share pending-operation state and cannot issue duplicate commands of
the same kind. The UI scope disposes **only its subscriptions**; it does not
disconnect the room. `RealtimeLeaveButton` explicitly closes/leaves the room;
the host owns confirmation and navigation. For a classroom, prefer
`RealtimeSharedContentButton` over direct screen-share toggles so the
authoritative classroom content mode stays synchronized.

`RealtimeRoomView` remains the **legacy full-page template**, while
`RealtimeComposableRoomTemplate` is a small quick-start template implemented
entirely with the public independent components. The Demo
implements its own responsive page compositions in:

- `example/lib/demo_composable_chat_page.dart` (standalone chat)
- `example/lib/demo_composable_meeting_page.dart`
- `example/lib/demo_composable_live_page.dart`
- `example/lib/demo_composable_pre_join_page.dart`

Pre-Join uses a separate `RealtimePreJoinController` exported by
`flutter_realtime_media_ui` and provided to atomic controls via
`RealtimePreJoinScope`. The app creates/disposes that controller, chooses its
route and passes its entry callback to `RealtimePreJoinJoinButton`.
Its provider-neutral controls include `RealtimePreJoinPreview`,
`RealtimePreJoinCheckList`, `RealtimePreJoinPermissions`,
`RealtimePreJoinMediaControls`, `RealtimePreJoinDevicePicker` and
`RealtimePreJoinBackgroundSelector`. Preview releases **before** entry, and
an entry failure stays on the same page with recoverable settings.

### Choose the smallest dependency

| App requirement | Import | Notes |
| --- | --- | --- |
| Chat-only UI | `package:flutter_realtime_chat_ui/flutter_realtime_chat_ui.dart` | Depends on `flutter_realtime_chat_core` + Flutter only. No media, native RTC drivers, or room UI. |
| Session orchestration without the default UI | `package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart` | Depends on runtime/core modules, but not the all-provider umbrella. |
| Media, live, classroom + UI components | `package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart` | Rich aggregate that pulls in several UI modules. |
| All providers pre-registered + convenience facade | `package:flutter_realtime_sdk/flutter_realtime_sdk.dart` | Full umbrella intentionally depends on all supported provider drivers. |

The **same** chat-specific state/controller and widgets work in both standalone
chat and an attached meeting chat. The Room UI scope creates one
`ChatUiController` and nests a `ChatUiScope` only when chat is available;
chat list, search, composer, host governance and floating chat widgets share
that source of truth. Unmounting either scope never disconnects the room.

The legacy `RealtimeChatView` in `flutter_realtime_media_ui` now reuses
the very same `ChatUiController` for its message/connection subscriptions,
search, send and host moderation. Its original message bubbles, emoji drawer
and glass-themed panels remain available. The old composer's UI and
moderation presentation have been separated into
`legacy_chat_actions.dart`, with no change to the public constructor.
`flutter_realtime_media_ui` consequently depends on the small
`flutter_realtime_chat_ui` package, **not** the other way around; an app using
chat-only UI still does not depend on media UI or RTC drivers.

The legacy `MediaRoomView` already owns its attached-chat snapshot/unread
subscription in `RoomChatEventsController`; permission and content-stage
invalidation subscriptions now live in `RoomAuxiliarySubscriptions`, which
guards against stale events when inputs change. The provider session is
never disposed by these presentation controllers.
Legacy media grid, focused-speaker selection, and contained screen-share
composition now live in `legacy_room_media_stage.dart`. These are still
optional presentation implementations, not vendor-specific RTC code; modern
custom room layouts use the public `RealtimeVideoGrid` and
`RealtimeScreenShareStage` instead.

For chat alone, use the following independent package:

```dart
import 'package:flutter_realtime_chat_ui/flutter_realtime_chat_ui.dart';

ChatUiScope(
  session: session,
  moderation: moderation,
  child: Scaffold(
    body: Column(children: const [
      ChatSearchField(),
      Expanded(child: ChatMessageList()),
      ChatComposer(),
    ]),
  ),
);
```

The alternative `ChatDefaultPage` is an optional quick-start template built
from these same public components. The Demo chooses its own layout.

**Still pending:** the original large `MediaRoomView`/`RealtimeRoomView` and
`RealtimeChatView` are kept as legacy templates until remaining behavior
parity is proven; their internal UI subscriptions/state and advanced emoji
affordances have not yet been fully removed. Further cleanup should **not**
silently remove host management, chat reply/search, media effects, or Pre-Join
race protection. Do not infer smaller APK/IPA/web bundles from source size
without comparing actual release builds. Track the remaining work in the
Coding Tools P0 UI Plan.

The legacy `RealtimeRoomView` and composable `RealtimeSharedContentStage`
now share the same provider-neutral contained screen/whiteboard stage renderer,
and the legacy floating-content menu has been separated into
`legacy_room_content_controls.dart` without changing its behavior. This is
file-responsibility cleanup, **not** a removal of the optional legacy template
or proof of reduced binary dependencies.
